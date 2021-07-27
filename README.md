# pxe-server
All in one DHCP/TFTP/HTTP server container for installing linux over the network via PXE booting.

Note that the container will run on macOS/Windows, but will not serve DHCP correctly (due to the way docker works on those platforms plus some assumptions in dhcpd). These instructions are written to be used on linux.

## Usage
There are two ways to use this container - automated or manual setup. The automated method is quick and easy but makes some assumptions and may need modification for your environment. The manual setup requires additional setup and per-server configuration but allows more flexibility.

Both methods do require you to get the ISO file and bootloader manually before PXE booting for the first time:

```shell
export BASE_DIR=pxe-data
export ISO_FILE=ubuntu-20.04.2-live-server-amd64.iso

mkdir -p "${BASE_DIR}"/{dhcp,tftp,http} 

# Get the ISO to boot
curl https://releases.ubuntu.com/20.04.2/ubuntu-20.04.2-live-server-amd64.iso -o "${BASE_DIR}"/http/${ISO_FILE}

# Get the kernel, initrd and bootloader in place to serve via TFTP
sudo mount "${BASE_DIR}"/http/${ISO_FILE} /mnt
cp /mnt/casper/vmlinuz "${BASE_DIR}"/tftp/
cp /mnt/casper/initrd "${BASE_DIR}"/tftp/
sudo umount /mnt
curl http://archive.ubuntu.com/ubuntu/dists/focal/main/uefi/grub2-amd64/current/grubnetx64.efi.signed -o "${BASE_DIR}"/tftp/pxelinux.0

```
This is obviously set up for UEFI boot which should be the default for everyone these days. Grab the BIOS  version of grub instead if you are booting in legacy mode.

### Automated Setup
After completing the one-time common setup above, write an env file to describe your network and target server and then pass them in to the container. To change a value, stop the container, edit the file, and launch the container again. The startup scripts in the container read the env variables and write out the appropriate config files for the various services each time the container starts.

Of course you can also export each value individually and then reference it on the docker command line instead (export ABC=abc, -e ABC).
```shell
cat > pxe-env <<EOF
export ISO_FILE=ubuntu-20.04.2-live-server-amd64.iso
export PXE_SERVER_IP=198.51.100.25
export NETWORK=198.51.100.0
export NETMASK=255.255.255.0
export CIDR=24
export ROUTER_IP=198.51.100.1
export DNS_IP=198.51.100.200
export TARGET_SERVER_NAME=new-server
export TARGET_SERVER_IP=198.51.100.8
export TARGET_SERVER_NIC=eth0
export TARGET_SERVER_MAC=01:02:03:aa:bb:cc
# Create password hash with mkpasswd --method=SHA-512 --rounds=4096
# Don't forget to escape the $ in the hash
TARGET_PW_HASH='\$6\$lkLartS6w73V9oIY\$Jj4UouHhPh8EyERJH8tB5WQ4cjbGjbmFQ6kHnxxnhQN4L0DMrJ3WrFHA8LSXAzd016J175BRwIUgwWQLbucFm.'
TARGET_USERNAME=user
EOF

docker container run --rm -it --net=host --name=pxe-server -v $(pwd)/"${BASE_DIR}":/data --env-file pxe-env pxe-server
```

### Manual Setup
Your goal is to create the configuration and data files for dhcpd, tftpd and the http server in a format like this:
```shell
$ tree pxe-server
pxe-server
├── dhcp
│   └── dhcpd.conf
├── http
│   ├── meta-data
│   ├── ubuntu-20.04.2.0-desktop-amd64.iso
│   └── user-data
└── tftp
    ├── boot
    ├── grub
    │   └── grub.cfg
    ├── initrd
    ├── pxelinux.0
    └── vmlinuz
```
These steps are an example of how to create the configuration for an automated install for Ubuntu 20.04 server:
```shell
export BASE_DIR=pxe-data
export ISO_FILE=ubuntu-20.04.2-live-server-amd64.iso
export PXE_SERVER_IP=198.51.100.25
export NETWORK=198.51.100.0
export NETMASK=255.255.255.0
export CIDR=24
export ROUTER_IP=198.51.100.1
export DNS_IP=198.51.100.200
export TARGET_SERVER_NAME=new-server
export TARGET_SERVER_IP=198.51.100.8
export TARGET_SERVER_NIC=eth0
export TARGET_SERVER_MAC=01:02:03:aa:bb:cc
export TARGET_USERNAME=user
# mkpasswd --method=SHA-512 --rounds=4096
export TARGET_PW_HASH='$6$lkLartS6w73V9oIY$Jj4UouHhPh8EyERJH8tB5WQ4cjbGjbmFQ6kHnxxnhQN4L0DMrJ3WrFHA8LSXAzd016J175BRwIUgwWQLbucFm.'

mkdir -p "${BASE_DIR}"/tftp/grub
cat > "${BASE_DIR}"/tftp/grub/grub.cfg <<EOF
default=autoinstall
timeout=5
timeout_style=menu
menuentry "Auto install Ubuntu 20.04" --id=autoinstall {
	echo "Loading..."
	linux /vmlinuz ip=dhcp url=http://${PXE_SERVER_IP}/${ISO_FILE} autoinstall ds="nocloud-net;s=http://${PXE_SERVER_IP}/" root=/dev/ram0 cloud-config-url=/dev/null
	initrd /initrd
}
menuentry "Manually install Ubuntu 20.04" --id=manualinstall {
	echo "Loading..."
	linux /vmlinuz ip=dhcp url=http://${PXE_SERVER_IP}/${ISO_FILE} root=/dev/ram0 cloud-config-url=/dev/null
	initrd /initrd
}
EOF

# Create the cloud-init files to automate the install and config
cat > "${BASE_DIR}"/http/meta-data <<EOF
instance-id: focal-autoinstall
EOF
cat > "${BASE_DIR}"/http/user-data <<EOF
#cloud-config
autoinstall:
  apt:
    geoip: false
    preserve_sources_list: false
    primary:
    - arches: [amd64, i386]
      uri: http://archive.ubuntu.com/ubuntu
    - arches: [default]
      uri: http://ports.ubuntu.com/ubuntu-ports
  identity: {hostname: ${TARGET_SERVER_NAME}, password: ${TARGET_PW_HASH}, realname: ${TARGET_USERNAME}, username: ${TARGET_USERNAME}}
  keyboard: {layout: us, toggle: null, variant: ''}
  locale: en_US
  network:
    ethernets:
      ${TARGET_SERVER_NIC}:
        critical: true
        addresses: [ ${TARGET_SERVER_IP}/${CIDR} ]
        gateway4: ${ROUTER_IP}
        nameservers:
          addresses: [ ${DNS_IP}) ]
    version: 2
  ssh:
    allow-pw: true
    authorized-keys: []
    install-server: true
  storage:
    config:
    - {ptable: gpt,
      path: /dev/sda, wipe: superblock-recursive, preserve: false, name: '', grub_device: false,
      type: disk, id: disk-sda}
    - {device: disk-sda, size: 536870912, wipe: superblock, flag: boot, number: 1,
      preserve: false, grub_device: true, type: partition, id: partition-0}
    - {fstype: fat32, volume: partition-0, preserve: false, type: format, id: format-0}
    - {device: disk-sda, size: 19327352832, wipe: superblock, flag: '', number: 2,
      preserve: false, grub_device: false, type: partition, id: partition-1}
    - {fstype: ext4, volume: partition-1, preserve: false, type: format, id: format-1}
    - {device: format-0, path: /boot/efi, type: mount, id: mount-0}
    - {device: format-1, path: /, type: mount, id: mount-1}
  version: 1
EOF

# Create the DHCP config for the target server
cat > "${BASE_DIR}"/dhcp/dhcpd.conf <<EOF
deny unknown-clients;

subnet ${NETWORK} netmask ${NETMASK} {              # Network and netmask for this subnet
    option routers ${ROUTER_IP};                    # Router/default gateway IP
    option domain-name-servers ${DNS_IP};           # DNS server IP
    group {
        host ${TARGET_SERVER_NAME} {                # Name of the target server
            hardware ethernet ${TARGET_SERVER_MAC}; # MAC address of the NIC to boot from on the target server
            fixed-address ${TARGET_SERVER_IP};       # IP address for the target server to use
            next-server ${PXE_SERVER_IP};           # IP address of the PXE server
            filename "/pxelinux.0";
        }
    }
}
EOF

docker container run --rm -it --net=host --name=pxe-server -v $(pwd)/"${BASE_DIR}":/data pxe-server
```
