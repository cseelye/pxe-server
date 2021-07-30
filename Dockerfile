FROM ubuntu:20.04 as base

FROM base as builder
RUN apt-get update && apt-get install --yes \
        python3 \
        python3-pip
COPY requirements.txt /tmp/requirements.txt
RUN pip3 --no-cache-dir --disable-pip-version-check install --upgrade pip && \
    pip3 --no-cache-dir --disable-pip-version-check install --no-compile --force-reinstall --prefix /install \
    --requirement /tmp/requirements*.txt

FROM base as final
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --yes \
        curl \
        dhcpdump \
        dhcping \
        gettext-base \
        isc-dhcp-server \
        monitoring-plugins-basic \
        net-tools \
        nginx \
        nmap \
        python3 \
        rsyslog \
        tftp \
        tftpd-hpa \
        vim \
        webhook \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local/
# Hack for dist-packages vs site-packages
RUN cd /usr/local/lib/python* && rm -r dist-packages && ln -fs site-packages dist-packages

# rsyslog service
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/rsyslog-service.conf /etc/supervisor/conf.d/rsyslog-service.conf

# Other services
COPY services/*.conf /etc/supervisor/conf.d/

# Add the troubleshooting scripts
COPY scripts /scripts

# supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY run-supervisor /usr/local/bin/run-supervisor

# Startup control service
COPY startup-service/startup /usr/local/bin/startup
COPY startup-service/startup-service.conf /etc/supervisor/conf.d/startup-service.conf
COPY templates /templates

# Installer progress webhook
COPY status-service/status-service.conf /etc/supervisor/conf.d/status-service.conf
COPY status-service/status-event /status-service/status-event
COPY status-service/status-hook.yaml /status-service/status-hook.yaml

# dhcp config, tftp and http content are expected to be in this volume mount
VOLUME /data

ENTRYPOINT ["/usr/local/bin/run-supervisor"]
