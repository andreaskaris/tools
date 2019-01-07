#!/bin/bash
# This will move 'unused' instance disks from /var/lib/nova/instances to /opt/nova_backup
# 'unused' meaning that no server could be found in nova server-list --all-tenants
#

stackrc_hypervisor_name=$1
overcloudrc_hypervisor_name=$2

if [ "$stackrc_hypervisor_name" == ""  ] || [ "$overcloudrc_hypervisor_name" == "" ] ; then
  echo "Usage:"
  echo "$0 <stackrc hypervisor name from stackrc nova list> \\"
  echo "   <overcloudrc hypervisor name from overcloudrc nova service-list>"
  exit 1
fi

echo "Cleaning up stackrc hypervisor $1"
echo "with overcloudrc hypervisor name $2"
echo ""

cd /home/stack
source stackrc
if ! $(nova list | grep -q " $stackrc_hypervisor_name "); then
  echo "A stackrc_hypervisor_name with name $stackrc_hypervisor_name does not exist in"
  echo "source stackrc; nova list"
  nova list
  exit 1
fi

source overcloudrc
if ! $(nova service-list --host $overcloudrc_hypervisor_name | grep -q " $overcloudrc_hypervisor_name " ); then
  echo "A nova service with name $overcloudrc_hypervisor_name does not exist in"
  echo "source overcloudrc; nova service-list"
  nova service-list
  exit 1
fi

source overcloudrc
instance_list=$(openstack server list --all-projects --host $overcloudrc_hypervisor_name -c ID -f value | tr '\n' ' ')
echo "The following instances were found on $overcloudrc_hypervisor_name"
echo "$instance_list"
echo ""

source stackrc
serverip=$(openstack server show $stackrc_hypervisor_name | grep addresses | awk -F '[ \t]+|=' '{print $(NF-1)}')
echo "Connecting to server $stackrc_hypervisor_name with IP $serverip"
echo ""

instances_on_disk=$(ssh heat-admin@${serverip} "sudo ls /var/lib/nova/instances | egrep '[a-f0-9]+-[a-f0-9]+-[a-f0-9]+-[a-f0-9]+-[a-f0-9]+'" | tr '\n' ' ')
echo "The following instances were found on the hypervisor's disk"
echo "$instances_on_disk"
echo ""

disks_to_move=""
for disk in $instances_on_disk; do
    append_to_list=true
    for instance in $instance_list; do
        if [ "$disk" == "$instance" ] ; then
            append_to_list=false
        fi
    done
    if $append_to_list ; then
        disks_to_move="$disks_to_move $disk"
    fi
done

if [ "$disks_to_move" == "" ] ; then
    echo "No disks to move"
    echo ""
    exit 0
fi

echo "The following disks will be moved"
echo "$disks_to_move"
echo ""

echo "If this is correct, then confirm with 'yes'. Any other key to cancel."
read yesno
if [ "$yesno" != "yes" ] ; then
    echo "Aborting due to user request"
    echo ""
    exit 0
fi
echo ""

ssh heat-admin@${serverip} "sudo mkdir /opt/nova_backup ; for disk in $disks_to_move ; do echo \"Moving \$disk\"; sudo mv /var/lib/nova/instances/\$disk /opt/nova_backup ; done ; sudo ls -al /opt/nova_backup"

echo ""
echo "Done"
