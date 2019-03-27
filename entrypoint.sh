#!/bin/bash

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

for file in bytecode.cvd daily.cvd main.cvd; do
  if [ ! -f $CLAMDIR//$file ]; then
    curl -o $CLAMDIR/$file http://database.clamav.net/$file
    chown clamav:clamav $CLAMDIR/$file
  fi
done

exec /usr/local/bin/freshclam -d &

exec tail -f $LOGS &
exec "$@"
