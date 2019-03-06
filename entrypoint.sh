#!/bin/bash

DIR="/var/log/clamav"
LOGS="$DIR/clamd.log $DIR/freshclam.log"
mkdir -p $DIR /run/clamav ; chown clamav:clamav $DIR /run/clamav ; touch $LOGS ; chown clamav:clamav $LOGS ; chmod 777 $DIR ; chmod 666 $LOGS

if [ -d /var/lib/clamav ]; then
  chown clamav:clamav /var/lib/clamav
fi

if [ -d /usr/local/share/clamav ]; then
  chown clamav:clamav /usr/local/share/clamav
fi

exec /usr/local/bin/freshclam -d &

exec tail -f $LOGS &
exec "$@"
