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

#workaround problem with updated packages links
yum clean all

yum install -y screen || true
yum install -y git patch || true
yum install -y redhat-lsb-core || true
yum install -y https://rdoproject.org/repos/rdo-release.rpm || true
yum install -y http://fedora-mirror01.rbc.ru/pub/epel//epel-release-latest-7.noarch.rpm || true
yum install -y mysql-connector-python || true
yum install -y scsi-target-utils || true

yum remove httpd httpd-tools mod_wsgi mariadb-galera-server -y || true
# clear conflicting with horizon http configuration
rm -rf /etc/httpd/

yum install -y httpd || true

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
FORCE=yes
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
ENABLED_SERVICES+=,n-api,n-crt,n-cpu,n-cond,n-sch,n-novnc,n-cauth

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

if [[ $3 == true ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF
MULTI_HOST=1
_EOF
set -x
fi

sudo su stack -c "cd ~ && wget -N http://updates.virtuozzo.com/server/virtuozzo/en_us/odin/7/techpreview-ct/centos7-exe.hds.tar.gz"
sudo su stack -c "cd ~ && tar -xzvf centos7-exe.hds.tar.gz"

if [[ ! -d ~stack/nova ]]; then

	su stack -c "source ~stack/devstack/functions && \
        git_clone https://github.com/openstack/nova.git ~stack/nova master"

        su stack -c "source functions.sh && \
        apply_cherry_pick https://review.openstack.org/openstack/nova ~stack/nova \
        refs/changes/57/182257/37,refs/changes/79/217679/14,refs/changes/36/260636/5,refs/changes/14/214314/5,refs/changes/98/282398/3"
fi

fixup_configs_for_libvirt

#workaround beta1 problem with updated packages links
yum clean all

sudo su stack -c "
	cd ~/devstack
        ./unstack.sh
        ./stack.sh
"

popd

echo "Consider removing iptables rejecting rule if you want to use Horizon dashboard"
echo "-= iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited =-"

exit 0
