# pxe-server
All in one DHCP/TFTP/HTTP server container for installing linux over the network via PXE booting. This is written to automate installing Ubuntu 20.04 server, but can install other distros with some tweaks.

Note that the container will run on macOS/Windows, but will not serve DHCP correctly (due to the way docker works on those platforms plus some assumptions in dhcpd). These instructions are written to be used on linux.

Docker Hub - https://hub.docker.com/r/cseelye/pxe-server  
Github - https://github.com/cseelye/pxe-server

## Usage
There are two ways to use this container - automated or manual setup. The automated method is quick and easy but makes some assumptions and may need modification for your environment. The manual setup requires additional setup and per-server configuration but allows more flexibility.

### Automated Setup
Create a directory to hold the config files and install files, write an env file to describe your network and target server, and then pass the environment into the container. To change a value, stop the container, edit the env file, and launch the container again. The startup scripts in the container read the env variables and write out the appropriate config files for the various services each time the container starts.

```shell
mkdir pxe-data
cat > pxe-env <<EOF
export ISO_FILE=ubuntu-20.04.2-live-server-amd64.iso
export ISO_URL=https://releases.ubuntu.com/20.04.2/${ISO_FILE}
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
docker container run --rm -it --net=host --privileged --name=pxe-server -v $(pwd)/pxe-data:/data --env-file pxe-env cseelye/pxe-server
```

### Manual Setup
Your goal is to create the configuration and data files for dhcpd, tftpd and the http server in a format like this:
```shell
$ tree pxe-server
pxe-data
├── dhcp
│   ├── dhcpd.conf
└── share
    ├── 00-0c-29-e8-5f-67
    │   ├── initrd -> ../initrd-ubuntu-20.04.2-live-server-amd64.iso
    │   ├── install.iso -> ../ubuntu-20.04.2-live-server-amd64.iso
    │   ├── meta-data
    │   ├── user-data
    │   ├── vendor-data
    │   └── vmlinuz -> ../vmlinuz-ubuntu-20.04.2-live-server-amd64.iso
    ├── grub
    │   └── grub.cfg
    ├── initrd-ubuntu-20.04.2-live-server-amd64.iso
    ├── ubuntu-20.04.2-live-server-amd64.iso
    └── vmlinuz-ubuntu-20.04.2-live-server-amd64.iso
```
The `dhcp` directory is used by the dhcp service and holds the dhcp config file. This is also where the leases file will be written.

The `share` directory holds everything else and it will be shared out by the container using tftp, http, and SMB protocols. The container will put the grub boot files into place in this directory and expects you to supply a grub.cfg in one of the standard grub locations.  
The other contents of the `share` directory will vary with your bootloader and distro. In the example above, I have put the Ubuntu 20.04 server iso in `share` and extracted the vmlinuz and initrd from that ISO and stored them in `share` as well. My grub.cfg (and the one created by the automated setup) expects a subdirectory for each client MAC address you will be booting. That directory contains whatever is needed to boot that client. In this example you can see I have symlinked the initrd, kernel, and ISO from the `share` directory, and added cloud-init files to automate the Ubuntu install. In this manner you can boot multiple clients with different configurations but reuse the same ISO. You could also add other ISO/install scripts for different clients.

See the startup script for more details. When the files are prepared, run the container:
```
docker container run --rm -it --net=host --name=pxe-server -v $(pwd)/pxe-data:/data pxe-server
```

# References
Ubuntu installer - https://ubuntu.com/server/docs/install/autoinstall-reference  
Grub network booting - https://www.gnu.org/software/grub/manual/grub/html_node/Network.html
