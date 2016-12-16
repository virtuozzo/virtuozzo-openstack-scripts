#!/bin/bash -xe

source functions.sh

usage(){
    set +x
    echo "Usage:"
    echo "     source vzrc [--host_ip HOST_IP] [--password PASSWORD]"
    echo "            [--virt_type vz|qemu|kvm] [--images_type ploop|qcow2]"
    echo "            [--use_provider_network]  [--fixed_range FIXED_RANGE]"
    echo "            [--floating_range FLOATING_RANGE] [--floating_pool FLOATING_POOL]"
    echo "            [--public_gateway PUBLIC_GATEWAY] [--gateway GATEWAY]"
    echo "            [--vzstorage CLUSTER_NAME] [--mode MODE]"
    echo "            [--controller_host CONTROLLER_IP] [--dest DEST]"
    echo "     `pwd`/setup_devstack_for_vz7.sh"
    echo "Where:"
    echo "     HOST_IP - network interface IP address to be used by OpenStack services"
    echo "     PASSWORD - your password for OpenStack services"
    echo "     MODE - [ALL|COMPUTE|CONTROLLER] ALL is default value"
    echo "     CONTROLLER_IP - IP address of CONTROLLER host, required parameter if MODE=COMPUTE"
    echo "     FIXED_RANGE - [IP/MASK]"
    echo "     FLOATING_RANGE - [IP/MASK]"
    echo "     FLOATING_POOL - [start=START_IP,end=END_IP]"
    echo "     PUBLIC_GATEWAY - IP address of gateway associated with the public network"
    echo "     GATEWAY - IP address of gateway associated with the private network"
    echo "     CLUSTER_NAME - The name of vzcluster to connect to"
    echo "     DEST - [LOCAL_PATH] Path to local directory for openstack projects"
    exit 1
}


# start

if [[ $EUID -ne 0 ]]; then
    set +x
    echo "This script should be run as root"
    exit 1
fi

if [[ -z "$HOST_IP" || -z "$PASSWORD" || -z "$MODE" || -z "$USE_PROVIDERNET" || -z "$VIRT_TYPE" ]]; then
    usage
fi

MODE=${MODE^^}

if [[ "${USE_PROVIDERNET,,}" == "true" ]]; then
	USE_PROVIDERNET=True
fi

VIRT_TYPE=${VIRT_TYPE,,}
if [[ "$VIRT_TYPE" == "vz" ]]; then
	VIRT_TYPE=parallels
fi
if [[ "$VIRT_TYPE" != "parallels" &&  "$VIRT_TYPE" != "qemu" &&  "$VIRT_TYPE" != "kvm" ]]; then
	usage
fi

if [[ "$MODE" != "COMPUTE" ]] && [[ "$MODE" != "CONTROLLER" ]] && [[ "$MODE" != "ALL" ]]; then
    usage
fi

if [[ "$MODE" == "COMPUTE" ]]; then

	if [[ -z "$CONTROLLER_IP" ]]; then
            set +x
            echo "Missing CONTROLLER IP address parameter"
	    usage
	fi
fi

if [[ "$MODE" == "COMPUTE" ]] || [[ "$MODE" == "ALL" ]]; then

	cleanup_compute
fi
export DEST=${DEST:-/vz/stack}
echo "Using destination $DEST"
create_stack_user $DEST

if [[ ! -d /opt/stack ]] && [[ "$DEST" != "/opt/stack" ]]; then
	ln -s $DEST /opt/stack
fi
chmod 700 $DEST

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

# There is a problem after yum update that python-requests and urllib3 packets conflict
# with ones provided by pip. We need either to ship necessary rpm versions of these packages,
# which is not done yet, or do the following trick

pip uninstall requests -y || true
pip uninstall requests -y || true
pip install requests || true

pip uninstall urllib3 -y || true
pip uninstall urllib3 -y || true
pip install urllib3 || true

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
        fix_openstack_project devstack refs/changes/91/356091/6 git://git.openstack.org/openstack-dev/devstack
fi

if [[ ! -d /var/log/nova ]]; then
	sudo mkdir /var/log/nova
	sudo chmod a+w /var/log/nova
fi

if [[ "$MODE" == "CONTROLLER" ]] || [[ "$MODE" == "ALL" ]]; then

set +x
cat > ~stack/devstack/local.conf << _EOF

[[local|localrc]]
HOST_IP=$HOST_IP
MYSQL_PASSWORD=$PASSWORD
SERVICE_TOKEN=$PASSWORD
SERVICE_PASSWORD=$PASSWORD
ADMIN_PASSWORD=$PASSWORD
LIBVIRT_TYPE=$VIRT_TYPE
LIBVIRT_IMAGES_TYPE=$IMAGES_TYPE
RABBIT_PASSWORD=$PASSWORD
SUBNETPOOL_PREFIX_V4=$FIXED_RANGE


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


FLOATING_RANGE=$FLOATING_RANGE
FIXED_RANGE=$FIXED_RANGE
Q_FLOATING_ALLOCATION_POOL=$FLOATING_POOL
PUBLIC_NETWORK_GATEWAY=$PUBLIC_GATEWAY
NETWORK_GATEWAY=$GATEWAY

#Open vSwitch provider networking configuration
Q_USE_PROVIDERNET_FOR_PUBLIC=$USE_PROVIDERNET
OVS_PHYSICAL_BRIDGE=br-ex
PUBLIC_BRIDGE=br-ex
OVS_BRIDGE_MAPPINGS=public:br-ex
PHYSICAL_NETWORK=public


IMAGE_URLS="file://$DEST/centos7-exe.hds"
_EOF
set -x

sudo su stack -c "cd ~ && wget -N http://updates.virtuozzo.com/server/virtuozzo/en_us/odin/7/techpreview-ct/centos7-exe.hds.tar.gz"
sudo su stack -c "cd ~ && tar -xzvf centos7-exe.hds.tar.gz"
fi



if ([[ "$MODE" == "CONTROLLER" ]] || [[ "$MODE" == "ALL" ]]) && [[ "${TELEMETRY,,}" == "true" ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF

# Enable telemetry services
ENABLED_SERVICES+=,gnocchi-grafana,gnocchi-api,gnocchi-metricd,ceilometer
CEILOMETER_BACKEND=gnocchi
enable_plugin ceilometer https://git.openstack.org/openstack/ceilometer.git
enable_plugin gnocchi https://github.com/openstack/gnocchi master
#enable_plugin monasca-api https://git.openstack.org/openstack/monasca-api.git
_EOF
fi

if ([[ "$MODE" == "CONTROLLER" ]] || [[ "$MODE" == "ALL" ]]) && [[ "${FWAAS,,}" == "true" ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF
ENABLED_SERVICES+=,q-fwaas
enable_plugin neutron-fwaas https://git.openstack.org/openstack/neutron-fwaas
_EOF
fi

if ([[ "$MODE" == "CONTROLLER" ]] || [[ "$MODE" == "ALL" ]]) && [[ "${LBAAS,,}" == "true" ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF
ENABLED_SERVICES+=,q-lbaasv2
enable_plugin neutron-lbaas https://git.openstack.org/openstack/neutron-lbaas
enable_plugin neutron-lbaas-dashboard https://git.openstack.org/openstack/neutron-lbaas-dashboard
_EOF
fi

if [[ "$MODE" == "CONTROLLER" ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF
MULTI_HOST=True
_EOF
set -x
fi

if [[ "${SETUP_VZSTORAGE,,}" == "true" ]] && ( [[ "$MODE" == "CONTROLLER" ]] || [[ "$MODE" == "ALL" ]] ); then
set +x
cat >> ~stack/devstack/local.conf << _EOF
enable_plugin devstack-plugin-vzstorage https://github.com/virtuozzo/devstack-plugin-vzstorage
CONFIGURE_VZSTORAGE_CINDER=$SETUP_VZSTORAGE
VZSTORAGE_CLUSTER_NAME=$VZSTORAGE_CLUSTER_NAME
VZSTORAGE_EXISTING_CLUSTER=$VZSTORAGE_EXISTING_CLUSTER
CINDER_ENABLED_BACKENDS=lvm:lvmdriver-1,vzstorage:vstorage-ploop,vzstorage:vstorage-qcow2
_EOF
set -x
mkdir -p /var/log/pstorage/$VZSTORAGE_CLUSTER_NAME
fi


if [[ "$MODE" == "COMPUTE" ]]; then
        EXTERNAL_BRIDGE=br-external
        ovs-vsctl add-br $EXTERNAL_BRIDGE || true
else
        EXTERNAL_BRIDGE=br-ex
fi


if [[ "$MODE" == "COMPUTE" ]]; then
set +x
cat > ~stack/devstack/local.conf << _EOF

[[local|localrc]]
HOST_IP=$HOST_IP
MYSQL_PASSWORD=$PASSWORD
SERVICE_TOKEN=$PASSWORD
SERVICE_PASSWORD=$PASSWORD
ADMIN_PASSWORD=$PASSWORD
LIBVIRT_TYPE=$VIRT_TYPE
LIBVIRT_IMAGES_TYPE=$IMAGES_TYPE
RABBIT_PASSWORD=$PASSWORD
MULTI_HOST=True
SERVICE_HOST=$CONTROLLER_IP
MYSQL_HOST=$CONTROLLER_IP
RABBIT_HOST=$CONTROLLER_IP
GLANCE_HOSTPORT=$CONTROLLER_IP:9292
NOVA_VNC_ENABLED=True
NOVNCPROXY_URL="http://$CONTROLLER_IP:6080/vnc_auto.html"
VNCSERVER_LISTEN=$HOST_IP
VNCSERVER_PROXYCLIENT_ADDRESS=$HOST_IP

ENABLED_SERVICES=n-cpu,rabbit,neutron,q-agt
LIBVIRT_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver

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

#Open vSwitch provider networking configuration
OVS_BRIDGE_MAPPINGS=public:$EXTERNAL_BRIDGE
OVS_PHYSICAL_BRIDGE=$EXTERNAL_BRIDGE
PUBLIC_BRIDGE=$EXTERNAL_BRIDGE
PHYSICAL_NETWORK=public

MULTI_HOST=True
_EOF
set -x
fi


if [[ "$MODE" == "ALL" ]]; then
set +x
cat >> ~stack/devstack/local.conf << _EOF
# Enable Nova compute service
ENABLED_SERVICES+=,n-cpu
_EOF
set -x
fi

clone_and_fix_openstack_project nova refs/changes/14/214314/6,refs/changes/05/355805/12,refs/changes/29/397829/8,refs/changes/88/312488/12,refs/changes/18/396218/5,refs/changes/66/397166/6
clone_and_fix_openstack_project glance refs/changes/33/341633/8,refs/changes/23/341623/3
clone_and_fix_openstack_project cinder refs/changes/35/400235/1,refs/changes/79/357679/9
fixup_configs_for_libvirt

sudo su - stack -c "cd ~/devstack && ./unstack.sh && DEST=$DEST ./stack.sh"

# connect br0 with $EXTERNAL_BRIDGE if provider network should be configured
if [[ "$USE_PROVIDERNET" == "True" ]]; then

ip link add veth-public0 type veth peer name veth-public1 || true

ip l set dev veth-public0 up || true
ip l set dev veth-public1 up || true
ovs-vsctl add-port $EXTERNAL_BRIDGE veth-public0 || true
brctl addif br0 veth-public1 || true

fi

pip uninstall -y psutil || true
yum reinstall -y python-psutil
systemctl reset-failed
systemctl restart vcmmd.service

popd

set +x
echo "ATTENTION: we are removing iptables rejecting rule!!!"
iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited

exit 0
