#!/bin/bash

DIR="/var/log/clamav"
LOGS="$DIR/clamd.log $DIR/freshclam.log"
mkdir -p $DIR ; chown clamav:clamav $DIR ; touch $LOGS ; chown clamav:clamav $LOGS ; chmod 777 $DIR ; chmod 666 $LOGS

if [ -d /var/lib/clamav ]; then
  chown clamav:clamav /var/lib/clamav
fi

exec freshclam -d &

exec tail -f $LOGS &
exec "$@"
