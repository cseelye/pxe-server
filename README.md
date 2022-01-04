# pxe-server
All in one DHCP/TFTP/HTTP server container for installing linux over the network via PXE booting. This is written to automate installing Ubuntu 20.04 server, but can install other distros with some tweaks.

Note that the container will run on macOS/Windows, but will not serve DHCP correctly (due to the way docker networking works on those platforms). These instructions are written to be used on linux.

Get the container image:
```shell
docker pull ghcr.io/cseelye/pxe-server    # Pull from Github Container Registry  
docker pull cseelye/pxe-server            # Pull from Docker Hub  
```
Pre-built containers are tagged by the day they were built, with :latest always pointing the the most recent build. Click the Packages link to see the list of tags.

## Usage
For convenience, there is a startup script that will interpret a series of envrionment variables and create the config/boot files for you. This automated method is quick and easy but makes some assumptions and may need modification for your environment. You can also create everything manually if you wish, or create it with the startup script and then tweak it to your needs.

### Automated Setup
Create a directory to hold the config files and install files, write an env file to describe your network and target server, and then pass the environment into the container. To change a value, stop the container, edit the env file, and launch the container again. The startup scripts in the container read the env variables and write out the appropriate config files for the various services each time the container starts.

```shell
cat > pxe-env <<EOF
ISO_FILE=ubuntu-20.04.3-live-server-amd64.iso
ISO_URL=https://releases.ubuntu.com/20.04.3/${ISO_FILE}
PXE_SERVER_IP=198.51.100.100
NETWORK=198.51.100.0
CIDR=24
ROUTER_IP=198.51.100.1
DNS_IP=198.51.100.200
TARGET_SERVER_NAME=new-server
TARGET_SERVER_IP=198.51.100.8
TARGET_SERVER_NIC=eth0
TARGET_SERVER_MAC=01:02:03:aa:bb:cc
# Create password hash with mkpasswd --method=SHA-512
# Don't forget to escape the $ in the hash
# This password is 'password'
TARGET_PW_HASH='\$6\$lkLartS6w73V9oIY\$Jj4UouHhPh8EyERJH8tB5WQ4cjbGjbmFQ6kHnxxnhQN4L0DMrJ3WrFHA8LSXAzd016J175BRwIUgwWQLbucFm.'
TARGET_USERNAME=user
EOF
docker container run --rm -it --net=host --privileged --name=pxe-server -v $(pwd)/pxe-data:/data --env-file pxe-env cseelye/pxe-server
```

You can run the container a second time with different values for the TARGET_SERVER_* variables and it will add the new configuration to the existing data directory without breaking the config for any other servers.  

### Manual Setup
Your goal is to create the configuration and data files for dnsmasq, grub, and tftp/http/samba server in a format like this:
```shell
$ tree pxe-data
pxe-data
├── dhcp
│   ├── hosts
│   │   ├── test-install-2.conf
│   │   └── test-install.conf
│   └── subnet.conf
└── share
    ├── 00-0c-29-e8-5f-67
    │   ├── initrd -> ../initrd-ubuntu-20.04.3-live-server-amd64
    │   ├── install.iso -> ../ubuntu-20.04.3-live-server-amd64.iso
    │   ├── meta-data
    │   ├── user-data
    │   ├── vendor-data
    │   └── vmlinuz -> ../vmlinuz-ubuntu-20.04.3-live-server-amd64
    ├── 00-50-56-38-23-fe
    │   ├── initrd -> ../initrd-ubuntu-20.04.3-live-server-amd64
    │   ├── install.iso -> ../ubuntu-20.04.3-live-server-amd64.iso
    │   ├── meta-data
    │   ├── user-data
    │   ├── vendor-data
    │   └── vmlinuz -> ../vmlinuz-ubuntu-20.04.3-live-server-amd64
    ├── bootx64.efi
    ├── grub
    │   ├── grub.cfg
    │   └── x86_64-efi
    ├── grubx64.efi
    ├── initrd-ubuntu-20.04.3-live-server-amd64
    ├── ubuntu-20.04.3-live-server-amd64.iso
    └── vmlinuz-ubuntu-20.04.3-live-server-amd64
```

The `dhcp` directory is used by the dnsmasq DHCP service and holds the subnet config file. Under this directory is the `hosts` dir which holds the host reservations for each host being imaged. New files created in this directory will be automatically read and dnsmasq config updated while the container is running. Any other config file changes need a container restart, or SIGHUP to dnsmasq.  

The `share` directory holds everything else and it will be shared out by the container using tftp, http, and SMB protocols. The container will put the grub boot files into place in this directory and expects you to supply a grub.cfg in one of the standard grub locations.  

The other contents of the `share` directory will vary with your bootloader and distro. In the example above, I have put the Ubuntu 20.04 server iso in `share` and extracted the vmlinuz and initrd from that ISO and stored them in `share` as well. My grub.cfg (and the one created by the automated setup) expects a subdirectory for each client MAC address you will be booting. That directory contains whatever is needed to boot that client. In this example you can see I have symlinked the initrd, kernel, and ISO from the `share` directory, and added cloud-init files to automate the Ubuntu install. In this manner you can boot multiple clients with different configurations but reuse the same ISO. You could also add other ISO/install scripts for different clients.

Files/dirs created in the share directory are immediately available and served by the container witout needing a restart.

See the template files for more details. When the files are prepared, run the container:
```
docker container run --rm -it --net=host --privileged --name=pxe-server -v $(pwd)/pxe-data:/data cseelye/pxe-server
```

# References
Ubuntu installer - https://ubuntu.com/server/docs/install/autoinstall-reference  
dnsmasq config - http://manpages.ubuntu.com/manpages/focal/man8/dnsmasq.8.html  
Grub network booting - https://www.gnu.org/software/grub/manual/grub/html_node/Network.html
