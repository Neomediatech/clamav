FROM neomediatech/ubuntu-base

ENV VERSION=0.102.1 \
    SERVICE=clamav-docker-ubuntu \
    OS=ubuntu \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Rome

LABEL maintainer="docker-dario@neomediatech.it" \
      org.label-schema.version=$VERSION \
      org.label-schema.vcs-type=Git \
      org.label-schema.vcs-url=https://github.com/Neomediatech/$SERVICE \
      org.label-schema.maintainer=Neomediatech

RUN apt-get update && \
    apt-get install -y ca-certificates curl build-essential libxml2 netcat \ 
                       openssl libssl-dev libcurl4-openssl-dev zlib1g-dev libpng-dev \ 
                       libxml2-dev libjson-c-dev libbz2-dev libpcre3-dev ncurses-dev && \
    curl --fail --show-error --location --output clamav-${VERSION}.tar.gz -- "http://www.clamav.net/downloads/production/clamav-${VERSION}.tar.gz" && \
    curl --fail --show-error --location --output clamav-${VERSION}.tar.gz.sig -- "http://www.clamav.net/downloads/production/clamav-${VERSION}.tar.gz.sig" && \
    tar --extract --gzip --file=clamav-${VERSION}.tar.gz && \
    cd clamav-${VERSION} && \
    ./configure && \
    make -j2 && make install && \
    ldconfig && \
    cd .. && rm -rf clamav-${VERSION}* && \
    apt-get purge -y --auto-remove \
      build-essential \
      libpcre3-dev libcurl4-openssl-dev zlib1g-dev libpng-dev\
      libssl-dev libxml2-dev libbz2-dev libpcre3-dev ncurses-dev && \
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
    sed -i 's/#LocalSocket.*$/LocalSocket \/run\/clamav\/clamd.ctl/' ${CLAM_ETC}/clamd.conf && \
    echo "TCPAddr 0.0.0.0" >> ${CLAM_ETC}/clamd.conf && \
    echo "TCPSocket 3310" >> ${CLAM_ETC}/clamd.conf && \
    echo "LogFile /var/log/clamav/clamd.log" >> ${CLAM_ETC}/clamd.conf && \
    echo "LogTime yes" >> ${CLAM_ETC}/clamd.conf && \
    echo "DatabaseDirectory ${CLAM_DB}" >> ${CLAM_ETC}/clamd.conf && \
    mkdir ${CLAM_DB} && \
    chown ${CLAM_USER}: ${CLAM_DB} 

# volume for virus definitions
VOLUME ["/var/lib/clamav"]

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 3310

HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=30 CMD echo PING | nc 127.0.0.1 3310 || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/local/sbin/clamd"]
