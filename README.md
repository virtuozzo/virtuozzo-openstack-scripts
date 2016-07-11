### Scripts to help to install OpenStack devstack on Virtuozzo7 server

```
Usage:
     $ source vzrc [--host_ip HOST] [--password PASSWORD]
            [--use_provider_network true|false] [--fixed_range FIXED_RANGE]
            [--floating_range FLOATING_RANGE] [--floating_pool FLOATING_POOL]
            [--public_gateway PUBLIC_GATEWAY] [--gateway GATEWAY]
            [--vzstorage CLUSTER_NAME] [--mode MODE]
            [--controller CONTROLLER_IP] [--dest DEST]
     $ ./setup_devstack_vz7.sh
Where:
     HOST_IP - network interface IP address to be used by OpenStack services
     PASSWORD - your password for OpenStack services
     MODE - [ALL|COMPUTE|CONTROLLER] ALL is default value
     CONTROLLER_IP - IP address of CONTROLLER host, required parameter if MODE=COMPUTE
     
     To setup public network and tenant (internal) network for default admin tenant with your environment specific parameters you need also to configure network options. Otherwize public and tenant networks will be configured with default parameters which are difficult to change later.
     --use_provider_network true|false - true option will configure flat public network, false will configure isolated public network. Use flat if you want to give instances access to your network.
     FIXED_RANGE - network range for tenant network
     FLOATING_RANGE - network range for public network
     FLOATING_POOL - network pool for public network to distribute floating IPs to the instances. Example: "start=10.24.41.51,end=10.24.41.99"
     PUBLIC_GATEWAY - default gateway for public network
     GATEWAY - default gateway for tenant network
     CLUSTER_NAME - name of your Virtuozzo Storage cluster
```


