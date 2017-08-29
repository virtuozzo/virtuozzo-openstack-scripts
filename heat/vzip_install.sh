#!/bin/bash -ve

yum install -y kolla-ansible

echo ${host_names} >> /etc/hosts
ssh-keyscan ${host_names} >> /root/.ssh/known_hosts

cat > /etc/kolla/globals.yml <<EOF
---
#########################
# Docker registry options
#########################
# By default images are pulled from Docker Hub. Uncomment these options
# to use a private Docker registry.
docker_registry: "10.28.29.130:5000"
docker_namespace: "kolla"


####################
# Networking Options
####################
# This should be a VIP, an unused IP on your network that will float between
# the hosts running keepalived for high availability.
kolla_internal_vip_address: "${vip_address}"

# This interface is what all your API services will be bound to by default.
# This interface must contain an IPv4 address.
network_interface: "eth0"

# This is the raw interface given to Neutron as its external network port. Even
# though an IP address can exist on this interface, it will be unusable in most
# configurations. For this reason, it is recommended to not assign any IP addresses
# to this interface. Don't specify the same interface as network_interface!
neutron_external_interface: "eth3"

# The interface used by your Virtuozzo Storage cluster. By default this is the same
# interface as network_interface although this is not recommended.
# This interface must contain an IPv4 address.
storage_interface: "eth2"

# This interface will be used for virtual overlay networks. By default this is the same
# interface as network_interface although this is not recommended.
# This interface must contain an IPv4 address.
tuninel_interface: "eth1"

# Arbitrary number from 0..255 used for VRRP.
# Must be unique within the current broadcast domain.
#keepalived_virtual_router_id: "51"

###########################
# Virtuozzo Storage options
###########################
# Virtuozzo Storage cluster name. Required option.
vstorage_cluster_name: "${cluster_name}"

# Virtuozzo Storage cluster password. Required option.
vstorage_cluster_password: "${cluster_password}"

# Enables shaman service for high availability of instances.
# Enabled by default.
#vstorage_enable_shaman: "yes"

# Virtuozzo Storage mount point used by OpenStack services.
# /vzip by default.
#vstorage_mount_point: "/vzip"


#################
# Neutron options
#################
# Default Neutron networks will be configured if options below
# are specified.

# Private network CIDR. Required option.
# 192.168.128.0/24 by default.
#neutron_private_net_cidr: "192.168.128.0/24"

# IP pool for the private network. If this option is not specified,
# Neutron allocates IP addresses within the entire private CIDR.
# Format: "start1-end1,start2-end2". Example: "192.168.128.100-192.168.128.200".
#neutron_private_net_pool: ""

# Comma-separated list of DNS addresses served to instances using
# DHCP when connected to the private network.
#neutron_private_net_dns: "8.8.8.8,8.8.4.4"

# Public network CIDR. Required option.
# Value must reflect the physical network attached to neutron_external_interface.
# Example: "172.16.50.0/24".
#neutron_public_net_cidr: ""

# Floating IP pool for the public network. If this option is not specified,
# Neutron allocates IP addresses within the entire public CIDR.
# Format: "start1-end1,start2-end2". Example: "172.16.50.100-172.16.50.200".
#neutron_public_net_pool: ""

# Default gateway address in the public network. If not specified, Neutron
# uses the first address in the public network CIDR.
# Example: "172.16.50.1".
#neutron_public_net_gw: ""

#############
# TLS options
#############
# TLS can be enabled to provide encryption and authentication for services.
# When TLS is enabled, certificates must be provided to allow
# clients to authenticate.
#kolla_enable_tls_external: "no"
#kolla_external_fqdn_cert: "{{ node_config_directory }}/certificates/haproxy.pem"
EOF

kolla-genpwd
kolla-inventory gen --key /root/.ssh/ansible --control ${host_names} --network ${host_names} --compute ${host_names} --storage ${host_names} --monitoring ${host_names} -- myinventory
kolla-ansible -i myinventory bootstrap-servers
kolla-ansible -i myinventory prechecks
kolla-ansible -i myinventory deploy
kolla-ansible post-deploy
cat /etc/kolla/admin-openrc.sh
