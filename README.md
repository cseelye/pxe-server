# pxe-server
All in one DHCP/TFTP/HTTP server container for installing linux over the network via PXE booting.

Note that the container will run on macOS/Windows, but will not serve DHCP correctly (due to the way docker works on those platforms plus some assumptions in dhcpd). These instructions are written to be used on linux.

## Usage
There are two ways to use this container - automated or manual setup. The automated method is quick and easy but makes some assumptions and may need modification for your environment. The manual setup requires additional setup and per-server configuration but allows more flexibility.

First get the ISO file you want to install from -
```shell
export BASE_DIR=pxe-data
export ISO_FILE=ubuntu-20.04.2-live-server-amd64.iso

mkdir -p "${BASE_DIR}"/{dhcp,tftp,http}

# Get the ISO to boot
curl -L https://releases.ubuntu.com/20.04.2/ubuntu-20.04.2-live-server-amd64.iso -o "${BASE_DIR}"/http/${ISO_FILE}
```

### Automated Setup
After completing the one-time setup above, write an env file to describe your network and target server and then pass them in to the container. To change a value, stop the container, edit the file, and launch the container again. The startup scripts in the container read the env variables and write out the appropriate config files for the various services each time the container starts.

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

docker container run --rm -it --net=host --privileged --name=pxe-server -v $(pwd)/"${BASE_DIR}":/data --env-file pxe-env pxe-server
```

### Manual Setup
Your goal is to create the configuration and data files for dhcpd, tftpd and the http server in a format like this:
```shell
$ tree pxe-server
pxe-server
├── dhcp
│   ├── dhcpd.conf
├── http
│   ├── 00-0c-29-e8-5f-67
│   │   ├── install.iso -> ../ubuntu-20.04.2-live-server-amd64.iso
│   │   ├── meta-data
│   │   ├── user-data
│   │   └── vendor-data
│   └── ubuntu-20.04.2-live-server-amd64.iso
└── tftp
    ├── 00-0c-29-e8-5f-67
    │   ├── initrd -> ../initrd-ubuntu-20.04.2-live-server-amd64.iso
    │   └── vmlinuz -> ../vmlinuz-ubuntu-20.04.2-live-server-amd64.iso
    ├── grub
    │   ├── grub.cfg
    ├── grubnetx64.efi.signed
    ├── initrd-ubuntu-20.04.2-live-server-amd64.iso
    └── vmlinuz-ubuntu-20.04.2-live-server-amd64.iso
```
See the startup script for how this is created. When the files are prepared, run the container:
```
docker container run --rm -it --net=host --name=pxe-server -v $(pwd)/"${BASE_DIR}":/data pxe-server
```
