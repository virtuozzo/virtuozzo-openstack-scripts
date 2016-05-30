#!/bin/bash -xe

source functions.sh

usage(){
    set +x
    echo "Usage:"
    echo "     `pwd`/setup_devstack_for_vz7.sh HOST_IP PASSWORD [MULTI_HOST]"
    echo "Where:"
    echo "     HOST_IP - network interface IP address to be used by OpenStack services"
    echo "     PASSWORD - your password for OpenStack services"
    echo "     MULTI_HOST - true if you want multinode configuration"
    exit 1
}


# start

if [[ $EUID -ne 0 ]]; then
    echo "This script should be run as root"
    exit 1
fi

if [[ -z "$2" ]]; then
    usage
fi

MULTIHOST=${3:false}
export DEST=${DEST:-/vz/stack}
export SCRIPT_HOME=`pwd`
echo "Using destination $DEST"

create_stack_user $DEST
pushd .

sudo su stack -c "~stack/devstack/unstack.sh" || true

NEED_REBOOT=false
onboot_preparations NEED_REBOOT
if [[ $NEED_REBOOT == true ]]; then
    set +x
    echo "============================================================="
    echo "Please reboot the node to update the parameters in modprobe.d"
    echo "After restart run setup script again"
    echo "============================================================="
    exit 1
fi

yum install -y screen || true
yum install -y git patch || true
yum install -y redhat-lsb-core || true
yum install -y https://rdoproject.org/repos/rdo-release.rpm || true
yum install -y http://fedora-mirror01.rbc.ru/pub/epel//epel-release-latest-7.noarch.rpm || true
yum install -y mysql-connector-python || true
yum install -y scsi-target-utils || true

service mysqld stop || true
rm -rf /var/lib/mysql/mysql.sock || true
if [[ ! -d /var/run/mysqld/ ]]; then
        mkdir /var/run/mysqld/
        chmod 0777 /var/run/mysqld/
fi

yum install -y prl-disp-service prl-disk-tool || true

if [[ ! -d ~stack/devstack ]]; then
	sudo su stack -c "
	cd ~
	git config --global user.email \"stack@example.com\"
	git config --global user.name \"Open Stack\"

	git clone git://git.openstack.org/openstack-dev/devstack
	"
fi

if [[ ! -d /var/log/nova ]]; then
	sudo mkdir /var/log/nova
	sudo chmod a+w /var/log/nova
fi

set +x

cat > ~stack/devstack/local.conf << _EOF

[[local|localrc]]
HOST_IP=$1
MYSQL_PASSWORD=$2
SERVICE_TOKEN=$2
SERVICE_PASSWORD=$2
ADMIN_PASSWORD=$2
LIBVIRT_TYPE=parallels
RABBIT_PASSWORD=$2


#Basic services
ENABLED_SERVICES=key,rabbit,mysql,horizon,tempest

# Enable Nova services
ENABLED_SERVICES+=,n-api,n-crt,n-cond,n-sch,n-cauth,n-novnc

# Enable Glance services
ENABLED_SERVICES+=,g-api,g-reg

# Enable Cinder services
ENABLED_SERVICES+=,c-sch,c-api,c-vol

# Enable Heat, to test orchestration
ENABLED_SERVICES+=,heat,h-api,h-api-cfn,h-api-cw,h-eng

# Enable Neutron services
ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta,neutron

# Destination path for installation
DEST=$DEST

# Destination for working data
DATA_DIR=${DEST}/data

# Destination for status files
SERVICE_DIR=${DEST}/status

LOG_COLOR=False
LOGDAYS=3
LOGFILE=$DEST/logs/stack.sh.log
SCREEN_LOGDIR=$DEST/logs/screen
ENABLE_METADATA_NETWORK=True
ENABLE_ISOLATED_METADATA=True
IMAGE_URLS="file://$DEST/centos7-exe.hds"

_EOF
set -x

if [[ $MULTIHOST == true ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF

MULTI_HOST=True
_EOF
set -x

else

set +x
cat >> ~stack/devstack/local.conf << _EOF

# Enable Nova compute service
ENABLED_SERVICES+=,n-cpu

_EOF
set -x

fi

sudo su stack -c "cd ~ && wget -N http://updates.virtuozzo.com/server/virtuozzo/en_us/odin/7/techpreview-ct/centos7-exe.hds.tar.gz"
sudo su stack -c "cd ~ && tar -xzvf centos7-exe.hds.tar.gz"

fix_nova
fixup_configs_for_libvirt

sudo su stack -c "
	cd ~/devstack
        ./unstack.sh
        ./stack.sh
"

popd

echo "Consider removing iptables rejecting rule if you want to use Horizon dashboard"
echo "-= iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited =-"

exit 0
