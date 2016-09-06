### Scripts to help to install OpenStack devstack on Virtuozzo7 server

```
Usage:
     $ source vzrc [--host_ip HOST] [--password PASSWORD]
            [--virt_type vz|qemu|kvm]
            [--use_provider_network true|false] [--fixed_range FIXED_RANGE]
            [--floating_range FLOATING_RANGE] [--floating_pool FLOATING_POOL]
            [--public_gateway PUBLIC_GATEWAY] [--gateway GATEWAY]
            [--existing_cluster true|false]
            [--vzstorage CLUSTER_NAME] [--mode MODE]
            [--controller CONTROLLER_IP] [--dest DEST]
     $ ./setup_devstack_vz7.sh

Where:

     HOST - network interface IP address to be used by OpenStack services
     PASSWORD - your password for OpenStack services
     MODE - [ALL|COMPUTE|CONTROLLER] ALL is default value
     CONTROLLER_IP - IP address of CONTROLLER host, required parameter if MODE=COMPUTE

     To setup public network and tenant (internal) network for default admin tenant with
     your environment specific parameters you need also to configure network options. Otherwise,
     public and tenant networks will be configured with default parameters which can't be changed
     later.

     If you want to use physical segment for your public network, and plan to allow your instances to
     access/be accessible from directly from other hosts, ' --use_provider_network true'.
     Specify 'false' to set up isolated public network.
     FIXED_RANGE - range of IP addresses for tenant network,
     FLOATING_RANGE - range of IP addresses for public network,
     FLOATING_POOL - pool of IP addresses for public network to provide floating IPs to instances.

       Example: "start=10.24.41.51,end=10.24.41.99"

     PUBLIC_GATEWAY - default gateway for public network,
     GATEWAY - default gateway for tenant network,
     CLUSTER_NAME - name of your Virtuozzo Storage cluster.
```


