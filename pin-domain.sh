#!/bin/bash -x

DOMAIN=undercloud
# needs to be comma separated list, every CPU individually
TUNED_CORES="7,8,9,10,11,19,20,21,22,23,31,32,33,34,35,43,44,45,46,47" 

# KERNEL_ARGS="default_hugepagesz=1GB hugepagesz=1G hugepages=32 iommu=pt intel_iommu=on"
KERNEL_ARGS=""

if [ -n "$TUNED_CORES" ]; then
  echo "Installing new tuned profile"
  tuned_conf_path="/etc/tuned/cpu-partitioning-variables.conf"
  yum install -y tuned-profiles-cpu-partitioning
  tuned-adm profile cpu-partitioning
  grep -q "^isolated_cores" $tuned_conf_path
  if [ "$?" -eq 0 ]; then
    sed -i "s/^isolated_cores=.*/isolated_cores=$TUNED_CORES/" $tuned_conf_path
  else
    echo "isolated_cores=$TUNED_CORES" >> $tuned_conf_path
  fi
  tuned-adm profile cpu-partitioning
  if ! `grep -q cpu-partitioning /etc/rc.local`; then
    echo "tuned-adm profile cpu-partitioning" >> /etc/rc.local
    chmod +x /etc/rc.local
  fi
fi

if ! `grep -q isolcpus /etc/default/grub`;then
  echo "Changing grub cmdline"
  sed "s/^\\(GRUB_CMDLINE_LINUX=\".*\\)\"/\\1 $KERNEL_ARGS isolcpus=$TUNED_CORES\"/g" -i /etc/default/grub
  grub2-mkconfig -o /etc/grub2.cfg
fi

echo "Pinning $DOMAIN to CPUs 1 2 3 4 5 6 7 8 and emulatorpin to CPU 0"
LIVE=""
if `virsh list | grep -q $DOMAIN`;then
  LIVE="--live"
fi


echo "Pin $DOMAIN emulatorpin 0 --config $LIVE"
virsh emulatorpin $DOMAIN 0 --config $LIVE

echo "Pin $DOMAIN vcpus $LIVE"
VCPU=0
for CORE in $(echo $TUNED_CORES | sed 's/,/ /g'); do
  echo "Pinning $DOMAIN vcpu $VCPU to core $CORE --config $LIVE..."
  virsh vcpupin $DOMAIN --vcpu $VCPU --cpulist $CORE --config $LIVE
  VCPU=$[ $VCPU + 1 ]
done

echo "Verification ..."
echo "cmdline:"
grep GRUB_CMDLINE_LINUX /etc/default/grub
echo "vcpupin:"
virsh vcpupin $DOMAIN

echo "Please reboot hypervisor to apply changes"

# ---------------------------------------------------------

#echo "Setting $DOMAIN as autostart"
# virsh autostart $DOMAIN

# if ! `grep -q isolcpus /proc/cmdline`;then
#  echo "Running yum update -y"
#  yum update -y
#  echo "Rebooting now to apply isolcpus"
#  reboot
# fi
