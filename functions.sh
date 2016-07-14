#!/bin/bash

create_stack_user(){
        #add stack user and make him be sudoer
        # 9 code = user already exist
        adduser stack -d $1 || [ $? -eq 9 ]

        if ! grep -q "stack ALL=(ALL) NOPASSWD: ALL" "/etc/sudoers"; then
                echo "stack ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
                echo "Defaults:stack !requiretty" >> /etc/sudoers
        else
                usermod -m -d $1 stack || echo "call \" rm -rf $1\""
        fi
}

onboot_preparations () {
        # Enable connection tracking for CT0
        # There was first beta where we had two files controlling this
        # vz.conf and parallels.conf. Let's modify both
        MODEPROBE_VZ="options nf_conntrack ip_conntrack_disable_ve0"
        NEED_REBOOT=false

        if ! grep -q "$MODEPROBE_VZ=0" /etc/modprobe.d/parallels.conf ||
           ! grep -q "$MODEPROBE_VZ=0" /etc/modprobe.d/vz.conf; then
                NEED_REBOOT=true
        fi

        if grep -q "$MODEPROBE_VZ" /etc/modprobe.d/parallels.conf; then
                sed -i s/"$MODEPROBE_VZ=.*"/"$MODEPROBE_VZ=0"/ /etc/modprobe.d/parallels.conf
        else
                echo -ne "$MODEPROBE_VZ=0" >> /etc/modprobe.d/parallels.conf
        fi

        if grep -q "$MODEPROBE_VZ" /etc/modprobe.d/vz.conf; then
                sed -i s/"$MODEPROBE_VZ=.*"/"$MODEPROBE_VZ=0"/ /etc/modprobe.d/vz.conf
        else
                echo -ne "$MODEPROBE_VZ=0" >> /etc/modprobe.d/vz.conf

        fi

        # devstack requires set hostname
        [ -n "$(hostname -f)" ] || hostname localhost

        #sometimes this file prevents from starting mysql
        service mysqld stop || true
        [[ ! -f /var/lib/mysql/mysql.sock ]] || rm -f /var/lib/mysql/mysql.sock

        # we kill prl_naptd because it conflicts with used by devstack dnsmasq
        # we kill httpd because in some circumstances it does't restart well
        # all other are openstack services that shouldn't be  running at the moment we start stack.sh
        for proc in prl_naptd httpd qpid rabbit mysqld horizon keystone cinder glance nova ceilometer neutron swift trove heat;
        do
            kill_proc $proc;
        done;

        if [[ -n "$1" ]]; then
              eval $1=$NEED_REBOOT
        fi
}

function apply_cherry_pick {
        local git_remote=$1
        local dest_dir=$2
        local cherry_pick_refs=$3

        pushd .
        cd $dest_dir
        # modify current source
        for ref in ${cherry_pick_refs//,/ }; do
                echo "Applying $ref from $git_remote ..."
                git fetch $git_remote $ref
                git cherry-pick FETCH_HEAD
                echo "Applying $ref from $git_remote ... done"
        done
        popd
}


function fix_openstack_project {

local project=$1
local changes=$2
local repo=https://review.openstack.org/openstack/$project

if [[ ! -d ~stack/$project ]]; then

	su stack -c "source ~stack/devstack/functions && \
        git_clone $repo ~stack/$project master"

        su stack -c "source functions.sh && \
        apply_cherry_pick $repo ~stack/$project $changes"
fi

}

function kill_proc() {
        local name=$1
        id_list=`ps -ef | grep $name | grep -v grep | awk '{print $2}'`
        for proc_id in $id_list
        do
                proc_info=`sudo ps -ef | grep ${proc_id}`
                if [[ -n $proc_info ]]; then
                   kill $proc_id 2 > /dev/null
                else
                   break 2
                fi
        done
}

fixup_configs_for_libvirt(){

# fix libvirtd.conf
sed -i s/"#log_level = 3"/"log_level = 2"/ /etc/libvirt/libvirtd.conf
sed -i s/"#unix_sock_group = \"libvirt\""/"unix_sock_group = \"stack\""/ /etc/libvirt/libvirtd.conf
sed -i s/"#unix_sock_ro_perms = \"0777\""/"unix_sock_ro_perms = \"0777\""/ /etc/libvirt/libvirtd.conf
sed -i s/"#unix_sock_rw_perms = \"0770\""/"unix_sock_rw_perms = \"0770\""/ /etc/libvirt/libvirtd.conf
sed -i s/"#unix_sock_dir = \"\/var\/run\/libvirt\""/"unix_sock_dir = \"\/var\/run\/libvirt\""/ /etc/libvirt/libvirtd.conf

sed -i s/"#auth_unix_ro = \"none\""/"auth_unix_ro = \"none\""/ /etc/libvirt/libvirtd.conf
sed -i s/"#auth_unix_rw = \"none\""/"auth_unix_rw = \"none\""/ /etc/libvirt/libvirtd.conf

}

function cleanup_compute(){

	# cleanup existing OpenStack instances
	# stop running
	prlctl list | grep instance- | awk '{ system("prlctl stop " $1 " --kill")} '

	# destroy destroy them
	prlctl list -a | grep instance- | awk '{ system("prlctl destroy " $1)} '
}
