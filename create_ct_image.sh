#!/bin/bash -xe

ct=$1
ipaddr=$2
dns=$3

prlctl create glance-$ct --vmtype ct --ostemplate $ct
prlctl set glance-$ct --ipadd $ipaddr --nameserver $dns
prlctl set glance-$ct --device-add net --network Bridged --dhcp on
prlctl start glance-$ct
prlctl exec glance-$ct yum install cloud-init -y
prlctl exec glance-$ct sed -i '/- growpart/d' /etc/cloud/cloud.cfg
prlctl exec glance-$ct sed -i '/- resizefs/d' /etc/cloud/cloud.cfg
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << _EOF
DEVICE=eth0
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
_EOF
# prlctl exec glance-$ct cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth1
# prlctl exec glance-$ct sed -i '/eth0/eth1' /etc/sysconfig/network-scripts/ifcfg-eth1
rm -f /etc/sysconfig/network-scripts/ifcfg-venet0*
rm -f /etc/resolv.conf
prlctl stop glance-$ct
mkdir /tmp/ploop-$ct
ploop init -s 950M /tmp/ploop-$ct/$ct.hds
mkdir /tmp/ploop-$ct/dst
ploop mount -m /tmp/ploop-$ct/dst /tmp/ploop-$ct/DiskDescriptor.xml
prlctl mount glance-$ct
id=$(vzlist glance-$ct | awk ' NR>1 { print $1 }')
cp -Pr --preserve=all /vz/root/$id/* /tmp/ploop-$ct/dst/
prlctl umount glance-$ct
ploop umount -m /tmp/ploop-$ct/dst/
