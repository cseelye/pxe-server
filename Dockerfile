FROM ubuntu:20.04 as base

FROM base as builder
RUN apt-get update && apt-get install --yes \
        python3 \
        python3-pip
COPY requirements.txt /tmp/requirements.txt
RUN pip --no-cache-dir --disable-pip-version-check install --no-compile --prefix /install \
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
        supervisor \
        tftp \
        tftpd-hpa \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local/

# supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Startup control service
COPY startup-service/startup /usr/local/bin/startup
COPY startup-service/startup-service.conf /etc/supervisor/conf.d/startup-service.conf

# rsyslog configuration
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/rsyslog-service.conf /etc/supervisor/conf.d/rsyslog-service.conf

# nginx configuration
COPY http/http-service.conf /etc/supervisor/conf.d/http-service.conf
COPY http/nginx.conf.template /templates/nginx.conf.template
COPY http/run-nginx /usr/local/bin/run-nginx

# dhcpd configuration
COPY dhcp/dhcp-service.conf /etc/supervisor/conf.d/dhcp-service.conf
COPY dhcp/run-dhcpd /usr/local/bin/run-dhcpd
COPY dhcp/dhcpd.conf.template /templates/dhcpd.conf.template

# tftpd configuration
COPY tftp/tftp-service.conf /etc/supervisor/conf.d/tftp-service.conf
COPY tftp/run-tftpd /usr/local/bin/run-tftpd

# dhcp config, tftp and http content are expected to be in this volume mount
VOLUME /data

ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
