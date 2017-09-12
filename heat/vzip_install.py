#!/usr/bin/env python

import logging
import os
import ast
import six
import subprocess
import sys


ENV_VARS = ['master_ip_address', 'master_host', 'ip_addresses', 'host_names', 'heat_outputs_path', 'cluster_name', 'cluster_password', 'vip_address', 'ext_vip_address' ,'keepaliveid']
KOLLA_GLOBALS = """
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
kolla_internal_vip_address: "$vip_address"
kolla_external_vip_address: "$ext_vip_address"

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
keepalived_virtual_router_id: "$keepaliveid"

###########################
# Virtuozzo Storage options
###########################
# Virtuozzo Storage cluster name. Required option.
vstorage_cluster_name: "$cluster_name"

# Virtuozzo Storage cluster password. Required option.
vstorage_cluster_password: "$cluster_password"

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

"""


def run_subproc(fn, **kwargs):
    env = os.environ.copy()
    for k, v in kwargs.items():
        env[six.text_type(k)] = v
    try:
        subproc = subprocess.Popen(fn, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE,
                                   env=env)
        stdout, stderr = subproc.communicate()
    except OSError as exc:
        ret = -1
        stderr = six.text_type(exc)
        stdout = ""
    else:
        ret = subproc.returncode
    if not ret:
        ret = 0
    return ret, stdout, stderr


def main(argv=sys.argv):
    log = logging.getLogger('vzip-install')
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(
        logging.Formatter(
            '[%(asctime)s] (%(name)s) [%(levelname)s] %(message)s'))
    log.addHandler(handler)
    handler = logging.FileHandler(filename="/var/log/vzip-install.log")
    log.addHandler(handler)
    log.setLevel('DEBUG')

    env = os.environ.copy()

    missing = False
    for var in ENV_VARS:
        if var not in env:
            missing = True
            log.error("Missing env variable '%s'", var)

    if missing == True:
        log.debug("Some env variable missed")
        return 1

    ma = env['master_ip_address']
    mh = env['master_host']
    a = env['ip_addresses'].replace('u','')
    h = env['host_names'].replace('u','')
    out_path = env['heat_outputs_path']

    a = ast.literal_eval(a)
    h = ast.literal_eval(h)

    ip_addresses = [ma] + a.values()
    host_names = [mh] + h.values()
    hosts = zip(ip_addresses, host_names)

    # construct correct hosts file containing all cluster hosts
    for host in hosts:
        with open('/etc/hosts', 'a') as f:
            f.write(' '.join(host) + '\n')

    # add all ip addresses to known-hosts and
    # copy constructed /etc/hosts to all hosts in cluster
    for host in host_names:

        cmd = ['ssh-keyscan', host]
        ret, out, err = run_subproc(cmd)
        if ret:
            log.error("ssh-keyscan return code %s:\n%s", ret, err)
            exit(ret)

        with open('/root/.ssh/known_hosts', 'a') as f:
            f.write(out + '\n')

        cmd = ['scp', '/etc/hosts', host + ':/etc/' ]
        ret, out, err = run_subproc(cmd)
        if ret:
            log.error("scp return code %s:\n%s", ret, err)
            exit(ret)

    cmd = ['cp', '-R', '/usr/share/kolla-ansible/etc_examples/kolla', '/etc/kolla']
    ret, out, err = run_subproc(cmd)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    kolla_globals = KOLLA_GLOBALS.replace('$cluster_name', env['cluster_name'])
    kolla_globals = kolla_globals.replace('$cluster_password', env['cluster_password'])
    kolla_globals = kolla_globals.replace('$vip_address', env['vip_address'])
    kolla_globals = kolla_globals.replace('$keepaliveid', env['keepaliveid'])

    with open('/etc/kolla/globals.yml', 'w') as f:
        f.write(kolla_globals)

    cmd = ['kolla-genpwd']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['kolla-inventory', 'gen', '--key', '/root/.ssh/id_rsa'] + \
          ['--control'] + host_names[:3] + \
          ['--network'] + host_names[:3] + \
          ['--compute'] + host_names[3:] + \
          ['--storage'] + host_names[:1] + \
          ['--monitoring'] + host_names[:1] + \
          ['--', 'myinventory']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['kolla-ansible', '-i', 'myinventory', 'bootstrap-servers']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['kolla-ansible', '-i', 'myinventory', 'prechecks']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['kolla-ansible', '-i', 'myinventory', 'deploy']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['kolla-ansible', '-i', 'myinventory', 'post-deploy']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

    cmd = ['cp', '/etc/kolla/admin-openrc.sh'] + [out_path + '.admin-openrc']
    ret, out, err = run_subproc(cmd)
    log.debug("%s %s:\n%s", cmd, ret, out)
    if ret:
        log.error("%s %s:\n%s", cmd, ret, err)
        exit(ret)

if __name__ == '__main__':
    sys.exit(main(sys.argv))

