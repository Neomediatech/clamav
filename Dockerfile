FROM alpine:3.9

LABEL maintainer="docker-dario@neomediatech.it"

ENV CLAM_VERSION=0.100.2-r0

RUN apk update && apk upgrade && apk add --no-cache tzdata && cp /usr/share/zoneinfo/Europe/Rome /etc/localtime
RUN apk add --no-cache tini clamav-daemon freshclam clamav-libunrar wget netcat-openbsd bash && \
    sed -i 's/^#Foreground .*$/Foreground yes/g' /etc/clamav/clamd.conf && \
    echo "TCPAddr 0.0.0.0" >> /etc/clamav/clamd.conf && \
    echo "TCPSocket 3310" >> /etc/clamav/clamd.conf && \
    sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf && \ 
    rm -rf /usr/local/share/doc /usr/local/share/man && \
    wget -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd && \
    wget -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd && \
    wget -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd && \
    chown clamav:clamav /var/lib/clamav/*.cvd && \ 
    mkdir /var/run/clamav && \
    chown clamav:clamav /var/run/clamav && \
    chmod 750 /var/run/clamav

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 3310

HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 CMD echo PING | nc -U /run/clamav/clamd.sock || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/sbin/tini", "--", "clamd"]
