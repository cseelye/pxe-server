FROM ubuntu:20.04 as base

FROM base as builder
ARG DEBIAN_FRONTEND=noninteractive

# Install/build python packages
RUN apt-get update && apt-get install --yes \
        python3 \
        python3-pip
COPY requirements.txt /tmp/requirements.txt
RUN pip3 --no-cache-dir --disable-pip-version-check install --upgrade pip && \
    pip3 --no-cache-dir --disable-pip-version-check install --no-compile --force-reinstall --prefix /install \
    --requirement /tmp/requirements*.txt

# Get the files we need for grub to use as a bootloader when PXE booting
RUN apt-get update && \
    apt-get install --yes --no-install-recommends grub-efi-amd64-signed grub-efi shim-signed && \
    mkdir /grubfiles && \
    cp /usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed /grubfiles/grubx64.efi && \
    cp -r usr/lib/grub/x86_64-efi /grubfiles/ && \
    cp /usr/lib/shim/shimx64.efi.signed /grubfiles/bootx64.efi

FROM base as final
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install --yes \
        curl \
        dnsmasq \
        gettext-base \
        net-tools \
        nginx \
        python3 \
        rsync \
        rsyslog \
        samba \
    && \
    apt-get autoremove --yes && apt-get clean && rm -rf /var/lib/apt/lists/*

# Optional troubleshooting tools/scripts
#RUN apt-get update && \
#    apt-get install --yes \
#        dhcpdump \
#        dhcping \
#        monitoring-plugins-basic \
#        nmap \
#        tftp \
#        vim \
#    && \
#    apt-get autoremove --yes && apt-get clean && rm -rf /var/lib/apt/lists/*
#COPY scripts /scripts

# Copy the bootloader files from the builder image
COPY --from=builder /grubfiles /grubfiles

# Copy in the python packages from the builder image
COPY --from=builder /install /usr/local/
# Fix debian silliness of dist-packages vs site-packages
RUN cd /usr/local/lib/python* && rm -r dist-packages && ln -fs site-packages dist-packages

# rsyslog service
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/rsyslog-service.conf /etc/supervisor/conf.d/rsyslog-service.conf

# rsync service
COPY rsync/rsyncd.conf /etc/rsyncd.conf
COPY rsync/rsync-service.conf /etc/supervisor/conf.d/rsync-service.conf

# Other services
COPY services/*.conf /etc/supervisor/conf.d/

# supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY run-supervisor /usr/local/bin/run-supervisor

# Startup control service
COPY startup-service/startup /usr/local/bin/startup
COPY startup-service/startup-service.conf /etc/supervisor/conf.d/startup-service.conf
COPY templates /templates

# Installer progress webhook
COPY status-service/status-service.conf /etc/supervisor/conf.d/status-service.conf
COPY status-service/status.py /status/status.py

# Samba service
COPY samba/samba-service.conf /etc/supervisor/conf.d/samba-service.conf
COPY samba/smb.conf /etc/samba/smb.conf
COPY samba/run-samba /usr/local/bin/run-samba

# dnsmasq service (DHCP/TFTP)
COPY dnsmasq/dhcp-service.conf /etc/supervisor/conf.d/dhcp-service.conf
COPY dnsmasq/dnsmasq.conf /etc/dnsmasq.conf
COPY dnsmasq/run-dnsmasq /usr/local/bin/run-dnsmasq

# dhcp config, tftp and http content are expected to be in this volume mount
VOLUME /data

ENTRYPOINT ["/usr/local/bin/run-supervisor"]
