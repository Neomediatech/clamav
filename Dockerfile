FROM ubuntu:18.04

LABEL maintainer="docker-dario@neomediatech.it"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Rome

ENV CLAMAV_VERSION="0.101.1"

RUN echo $TZ /etc/timezone && \ 
    apt-get update && \
    apt-get install -y ca-certificates curl build-essential libpcre3-dev libssl-dev libxml2-dev libxml2 netcat tzdata && \
    curl --fail --show-error --location --output clamav-${CLAMAV_VERSION}.tar.gz -- "http://www.clamav.net/downloads/production/clamav-${CLAMAV_VERSION}.tar.gz" && \
    curl --fail --show-error --location --output clamav-${CLAMAV_VERSION}.tar.gz.sig -- "http://www.clamav.net/downloads/production/clamav-${CLAMAV_VERSION}.tar.gz.sig" && \
    tar --extract --gzip --file=clamav-${CLAMAV_VERSION}.tar.gz && \
    cd clamav-${CLAMAV_VERSION} && \
    ./configure && \
    make && make install && \
    ldconfig && \
    cd .. && rm -rf clamav-${CLAMAV_VERSION}* && \
    apt-get purge -y --auto-remove \
      build-essential \
      libpcre3-dev \
      libssl-dev && \
    rm -rf /var/lib/apt/lists*

# configure freshclam
ENV CLAM_USER="clamav" \
    CLAM_UID="1000" \
    CLAM_ETC="/usr/local/etc" \
    CLAM_DB="/var/lib/clamav" \
    CLAM_CHECKS="24" \
    CLAM_DAEMON_FOREGROUND="yes"
RUN useradd -u ${CLAM_UID} ${CLAM_USER} && \
    cp ${CLAM_ETC}/freshclam.conf.sample ${CLAM_ETC}/freshclam.conf && \
    sed -i "s/^Example/# Example/; \
      s/#LogTime yes/LogTime yes/; \
      s/#ScriptedUpdates yes/ScriptedUpdates no/; \
      s/#Checks 24/Checks ${CLAM_CHECKS}/; \
      s/#Foreground yes/Foreground ${CLAM_DAEMON_FOREGROUND}/; \ 
      s/#NotifyClamd.*$/NotifyClamd \/usr\/local\/etc\/clamd\.conf/" ${CLAM_ETC}/freshclam.conf && \
    echo "UpdateLogFile /var/log/clamav/freshclam.log" >> ${CLAM_ETC}/freshclam.conf && \
    echo "DatabaseDirectory ${CLAM_DB}" >> ${CLAM_ETC}/freshclam.conf && \
    cp ${CLAM_ETC}/clamd.conf.sample ${CLAM_ETC}/clamd.conf && \
    sed -i 's/^#Foreground .*$/Foreground yes/g' ${CLAM_ETC}/clamd.conf && \
    sed -i 's/^Example/#Example/' ${CLAM_ETC}/clamd.conf && \
    sed -i 's/#LocalSocket.*$/LocalSocket \/run\/clamav\/clamd.sock/' ${CLAM_ETC}/clamd.conf && \
    echo "TCPAddr 0.0.0.0" >> ${CLAM_ETC}/clamd.conf && \
    echo "TCPSocket 3310" >> ${CLAM_ETC}/clamd.conf && \
    echo "LogFile /var/log/clamav/clamd.log" >> ${CLAM_ETC}/clamd.conf && \
    echo "LogTime yes" >> ${CLAM_ETC}/clamd.conf && \
    echo "DatabaseDirectory ${CLAM_DB}" >> ${CLAM_ETC}/clamd.conf && \
    mkdir ${CLAM_DB} && \
    chown ${CLAM_USER}: ${CLAM_DB} 
#    freshclam --version

# volume for virus definitions
VOLUME ["/var/lib/clamav"]

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 3310

HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=3 CMD echo PING | nc 127.0.0.1 3310 || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/sbin/clamd"]
