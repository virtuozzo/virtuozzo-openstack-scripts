#!/bin/bash -xe

ct=$1
ipaddr=$2
dns=$3

prlctl create glance-$ct --vmtype ct --ostemplate $ct
prlctl set glance-$ct --ipadd $ipaddr --nameserver $dns
prlctl start glance-$ct
prlctl exec glance-$ct yum install cloud-init -y
prlctl stop glance-$ct
mkdir /tmp/ploop-$ct
ploop init -s 950M /tmp/ploop-$ct/$ct.hds
mkdir /tmp/ploop-$ct/dst
ploop mount -m /tmp/ploop-$ct/dst /tmp/ploop-$ct/DiskDescriptor.xml
prlctl mount glance-$ct

id=$(vzlist glance-$ct | awk ' NR>1 { print $1 }')

cat > /vz/root/$id/etc/sysconfig/network-scripts/ifcfg-eth0 << _EOF
DEVICE=eth0
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp
_EOF
cp /vz/root/$id/etc/sysconfig/network-scripts/ifcfg-eth0 /vz/root/$id/etc/sysconfig/network-scripts/ifcfg-eth1
sed -i '/eth0/eth1' /vz/root/$id/etc/sysconfig/network-scripts/ifcfg-eth1
rm -f /vz/root/$id/etc/sysconfig/network-scripts/ifcfg-venet0*
rm -f /vz/root/$id/etc/resolv.conf
sed -i '/- growpart/d' /vz/root/$id/etc/cloud/cloud.cfg
sed -i '/- resizefs/d' /vz/root/$id/etc/cloud/cloud.cfg

cp -Pr --preserve=all /vz/root/$id/* /tmp/ploop-$ct/dst/
prlctl umount glance-$ct
ploop umount -m /tmp/ploop-$ct/dst/
