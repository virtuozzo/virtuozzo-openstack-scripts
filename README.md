### Scripts to help to install OpenStack devstack on Virtuozzo7 server

```
Usage:
     $ source vzrc [--host_ip HOST] [--password PASSWORD]
            [--use_provider_network]  [--fixed_range FIXED_RANGE]
            [--floating_range FLOATING_RANGE] [--floating_pool FLOATING_POOL]
            [--public_gateway PUBLIC_GATEWAY] [--gateway GATEWAY]
            [--vzstorage CLUSTER_NAME] [--mode MODE]
            [--controller_host CONTROLLER_HOST] [--dest DEST]
     $ ./setup_devstack_for_vz7.sh
Where:
     HOST_IP - network interface IP address to be used by OpenStack services
     PASSWORD - your password for OpenStack services
     MODE - [ALL|COMPUTE|CONTROLLER] ALL is default value
     CONTROLLER_IP - IP address of CONTROLLER host, required parameter if MODE=COMPUTE
```


