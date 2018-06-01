#!/bin/bash

for p in beam.smp celery cinder-api cinder-schedule cinder-volume csd dnsmasq docker-containe dockerd-current glance-api glance-registry heat-api heat-engine httpd kolla_start libvirtd libvirt_exporte mdsd memcached neutron-dhcp-ag neutron-l3-agen neutron-metadat neutron-ns-meta neutron-openvsw neutron-server nginx node_exporter nova-api nova-compute nova-conductor nova-consoleaut nova-novncproxy nova-scheduler ovsdb-client ovsdb-server ovs-vswitchd postgres privsep-helper rabbitmq-server redis-server registry shaman-monitor uwsgi vcmmd vstorage-mount ; do

    top -n 1 -b | grep $p | awk ' {rss+=$6; num=num+1} END {printf "%s(%s) RSS memory (total KiB)....  %s\n", $12, num, rss}'
done
