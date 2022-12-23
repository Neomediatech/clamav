#!/tini /bin/bash

CLAMAV_START=${CLAMAV_START:-yes}
if [ "$CLAMAV_START" = "no" ]; then
  exec tail -f "/dev/null"
  exit 0
fi

LOGDIR="/var/log/clamav"
LOGS="$LOGDIR/clamd.log $LOGDIR/freshclam.log"
CLAMDIR="/var/lib/clamav"
mkdir -p $LOGDIR /run/clamav ; chown clamav:clamav $LOGDIR /run/clamav ; touch $LOGS ; chown clamav:clamav $LOGS ; chmod 777 $LOGDIR ; chmod 666 $LOGS

if [ -d $CLAMDIR ]; then
  chown clamav:clamav $CLAMDIR
fi

if [ -d /usr/local/share/clamav ]; then
  chown clamav:clamav /usr/local/share/clamav
fi

#for file in bytecode.cvd daily.cvd main.cvd; do
#  if [ ! -f $CLAMDIR/$file ]; then
#    echo "$CLAMDIR/$file not found, downloading from database.clamav.net..."
#    curl -o $CLAMDIR/$file http://database.clamav.net/$file
#    chown clamav:clamav $CLAMDIR/$file
#  fi
#done

# download initial database if it doesn't exists
if [ ! -f "$CLAMDIR/main.cvd" ]; then
  echo "Updating initial database"
  freshclam --foreground --stdout
fi

#freshclam 

# start ClamAV in background
echo "Starting ClamAV"
if [ -S "/run/clamav/clamd.sock" ]; then
  unlink "/run/clamav/clamd.sock"
fi
if [ -S "/run/clamav/clamd.ctl" ]; then
  unlink "/run/clamav/clamd.ctl"
fi
clamd --foreground &
while [ ! -S "/run/clamav/clamd.sock" -a ! -S "/run/clamav/clamd.ctl" ]; do
  if [ "${_timeout:=0}" -gt "${CLAMD_STARTUP_TIMEOUT:=1800}" ]; then
    echo
    echo "Failed to start clamd"
    exit 1
  fi
  printf "\r%s" "Socket for clamd not found yet, retrying (${_timeout}/${CLAMD_STARTUP_TIMEOUT}) ..."
  sleep 1
  _timeout="$((_timeout + 1))"
done
echo "socket found, clamd started."
[ ! -L "/run/clamav/clamd.ctl" -a ! -S "/run/clamav/clamd.ctl" ] && ln -s /run/clamav/clamd.sock /run/clamav/clamd.ctl || ok=1
[ ! -L "/run/clamav/clamd.sock" -a ! -S "/run/clamav/clamd.sock" ] && ln -s /run/clamav/clamd.ctl /run/clamav/clamd.sock || ok=1

# set Clamav Unofficial Sigs
UNOFFICIAL_SIGS=${UNOFFICIAL_SIGS:-yes}
if [ $UNOFFICIAL_SIGS = "yes" ]; then
  BASE_URL="https://raw.githubusercontent.com/extremeshok/clamav-unofficial-sigs/master"
  cd /
  curl --fail --show-error --location --output clamav-unofficial-sigs.sh -- ${BASE_URL}/clamav-unofficial-sigs.sh
  # apply patch #386 (https://github.com/extremeshok/clamav-unofficial-sigs/pull/386/files)
  grep -q work_dir_urlhausdt clamav-unofficial-sigs.sh
  [ $? -eq 0 ] && sed -i 's/work_dir_urlhausdt/work_dir_urlhausd/' clamav-unofficial-sigs.sh
  # apply patch #390 (https://github.com/extremeshok/clamav-unofficial-sigs/pull/390/files)
  grep -q '^\( \+\)\?yararulesproject_update_hours' clamav-unofficial-sigs.sh
  if [ $? -eq 0 ]; then
    grep -q "urlhaus_update_hours=" clamav-unofficial-sigs.sh
    [ $? -eq 1 ] && sed -i '/^\( \+\)\?yararulesproject_update_hours=.*/a \ \ urlhaus_update_hours="0"' clamav-unofficial-sigs.sh
  fi
  grep -q '^xshok_mkdir_ownership "$work_dir_yararulesproject"' clamav-unofficial-sigs.sh
  if [ $? -eq 0 ]; then
    grep -q '^xshok_mkdir_ownership "$work_dir_urlhaus"' clamav-unofficial-sigs.sh
    [ $? -eq 1 ] && sed -i '/^xshok_mkdir_ownership "$work_dir_yararulesproject"/a xshok_mkdir_ownership "$work_dir_urlhaus"' clamav-unofficial-sigs.sh
  fi
  # end fix #390
  chmod +x clamav-unofficial-sigs.sh
  [ ! -d /etc/clamav-unofficial-sigs ] && mkdir -p /etc/clamav-unofficial-sigs
  cd /etc/clamav-unofficial-sigs
  curl --fail --show-error --location --output master.conf -- ${BASE_URL}/config/master.conf
  curl --fail --show-error --location --output user.conf   -- ${BASE_URL}/config/user.conf
  if [ ! -f os.conf ]; then
    cat <<EOF > os.conf
clam_user="clamav"
clam_group="clamav"
clam_dbs="/var/lib/clamav"
clamd_socket="/run/clamav/clamd.ctl"
enable_random="no"
# https://eXtremeSHOK.com ######################################################
EOF
  fi
  MISSING=""
  which host 1>/dev/null
  [ $? -ne 0 ] && MISSING="bind9-host"
  which rsync 1>/dev/null
  [ $? -ne 0 ] && MISSING="$MISSING rsync"
  if [ "$MISSING" != "" ]; then
    apt-get update
    apt-get install -y --no-install-recommends $MISSING
  fi
  rm -rf /var/lib/apt/lists*
  /clamav-unofficial-sigs.sh --verbose
  while true; do sleep 3600 ; /clamav-unofficial-sigs.sh --verbose ; done &
fi

exec freshclam -d &

# Wait forever (or until canceled)
exec tail -f "/dev/null"

exit 0

