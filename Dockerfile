FROM neomediatech/ubuntu-base:22.04

ENV CLAMAV_VERSION=0.105.1 \
    SERVICE=clamav

LABEL maintainer="docker-dario@neomediatech.it" \
      org.label-schema.version=$CLAMAV_VERSION \
      org.label-schema.vcs-type=Git \
      org.label-schema.vcs-url=https://github.com/Neomediatech/$SERVICE \
      org.label-schema.maintainer=Neomediatech

RUN apt-get update && apt-get -y dist-upgrade && \
    apt-get install -y --no-install-recommends \
      libbz2-1.0 libcurl4 libltdl7 zlib1g libevent-pthreads-2.1-7 \
      ca-certificates curl netcat dnsutils && \
    rm -rf /var/lib/apt/lists*

# configure freshclam
ENV CLAM_USER="clamav" \
    CLAM_UID="1000" \
    CLAM_ETC="/etc/clamav" \
    CLAM_DB="/var/lib/clamav" \
    CLAM_CHECKS="24" \
    CLAM_DAEMON_FOREGROUND="yes"
RUN useradd -u ${CLAM_UID} ${CLAM_USER} && \
    mkdir ${CLAM_DB} && \
    chown ${CLAM_USER}: ${CLAM_DB} && \
    groupadd -g 124 Debian-exim && \
    useradd -u 116 -g Debian-exim Debian-exim && \
    usermod -G Debian-exim clamav 

RUN cd /tmp && \
    curl --fail --show-error --location --output clamav-${CLAMAV_VERSION}.linux.x86_64.deb -- "https://www.clamav.net/downloads/production/clamav-${CLAMAV_VERSION}.linux.x86_64.deb" && \
    dpkg -i clamav-${CLAMAV_VERSION}.linux.x86_64.deb && \
    rm -f clamav-${CLAMAV_VERSION}.linux.x86_64.deb

RUN sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /run/lock/clamd.pid|" \
        -e "s|.*\(LocalSocket\) .*|\1 /run/clamav/clamd.ctl|" \
        -e "s|.*\(TCPSocket\) .*|\1 3310|" \
        -e "s|.*\(TCPAddr\) .*|\1 0.0.0.0|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        -e "s|^\#\(Foreground\).*|\1 yes|" \
        "/usr/local/etc/clamd.conf.sample" > "/usr/local/etc/clamd.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /run/lock/freshclam.pid|" \
        -e "s|.*\(DatabaseOwner\) .*|\1 clamav|" \
        -e "s|^\#\(NotifyClamd\).*|\1 /etc/clamav/clamd.conf|" \
        -e "s|^\#\(ScriptedUpdates\).*|\1 no|" \
        -e "s|^\#\(Checks\).*|\1 24|" \
        -e "s|^\#\(Foreground\).*|\1 yes|" \
        "/usr/local/etc/freshclam.conf.sample" > "/usr/local/etc/freshclam.conf" 

# volume for virus definitions
VOLUME ["/var/lib/clamav"]

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

EXPOSE 3310

HEALTHCHECK --interval=60s --timeout=3s --start-period=60s --retries=10 CMD echo PING | nc 127.0.0.1 3310 || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["clamd"]
