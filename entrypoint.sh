
LOGDIR="/var/log/clamav"
LOGS="$LOGDIR/clamd.log $LOGDIR/freshclam.log"
CLAMDIR="/var/lib/clamav"
mkdir -p $LOGDIR /run/clamav /var/lib/clamav-unofficial-sigs ; chown clamav:clamav $LOGDIR /run/clamav ; touch $LOGS ; chown clamav:clamav $LOGS ; chmod 777 $LOGDIR ; chmod 666 $LOGS

if [ -d $CLAMDIR ]; then
  chown clamav:clamav $CLAMDIR
fi

if [ -d /usr/local/share/clamav ]; then
  chown clamav:clamav /usr/local/share/clamav
fi

for file in bytecode.cvd daily.cvd main.cvd; do
  if [ ! -f $CLAMDIR/$file ]; then
    echo "$CLAMDIR/$file not found, downloading from database.clamav.net..."
    curl -o $CLAMDIR/$file http://database.clamav.net/$file
    chown clamav:clamav $CLAMDIR/$file
  fi
done

freshclam 

# set Clamav Unofficial Sigs
UNOFFICIAL_SIGS=${UNOFFICIAL_SIGS:-yes}
if [ $UNOFFICIAL_SIGS = "yes" ]; then
  BASE_URL="https://raw.githubusercontent.com/extremeshok/clamav-unofficial-sigs/master"
  cd /
  wget -O clamav-unofficial-sigs.sh ${BASE_URL}/clamav-unofficial-sigs.sh
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
  # [ ! -f master.conf ] && 
  wget -O master.conf ${BASE_URL}/config/master.conf
  # [ ! -f user.conf ]   && 
  wget -O user.conf ${BASE_URL}/config/user.conf
  if [ ! -f os.conf ]; then
    cat <<EOF > os.conf
clam_user="clamav"
clam_group="clamav"
clam_dbs="/var/lib/clamav"
clamd_socket="/run/clamav/clamd.sock"
enable_random="no"
# https://eXtremeSHOK.com ######################################################
EOF
  fi
  MISSING=""
  which host 1>/dev/null
  [ $? -ne 0 ] && MISSING="bind-tools"
  which rsync 1>/dev/null
  [ $? -ne 0 ] && MISSING="$MISSING rsync"
  apk update 
  apk add $MISSING
  # prev_file=$(cat /etc/clamav-unofficial-sigs/os.conf)
  # echo 'enable_random="no"' >> /etc/clamav-unofficial-sigs/os.conf
  /clamav-unofficial-sigs.sh --verbose
  # echo "$prev_file" > /etc/clamav-unofficial-sigs/os.conf
  while true; do sleep 3600 ; /clamav-unofficial-sigs.sh --verbose ; done &
fi

ln -s /run/clamav/clamd.ctl /run/clamav/clamd.sock || err=0

#exec freshclam -d &

#exec "$@"
