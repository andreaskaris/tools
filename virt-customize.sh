#!/bin/bash -x
# Author: Andreas Karis <ak.karis@gmail.com>
# Usage: ./virt-customize.sh fedora.qcow2 fedora-clone.qcow2 30
# This script takes a base cloud image and prepares it for use in a private
# libvirt lab environment.
# For that it  expands the image's disk to the desired size, allows root password login,
# sets the root password to "password" and removes cloud-init.

BASE=$1
CLONE=$2
SIZE=$3
BASE_RESIZED=${BASE}-resized

if ! [ -f $BASE ]; then
  echo "Base file $BASE does not exist"
  exit 1
fi

cp $BASE $CLONE
qemu-img resize $CLONE ${SIZE}G


if $(virt-filesystems -a $BASE --all --long -h | grep -q 'btrfs'); then
  RFS=$(virt-filesystems -a $BASE --all --long -h | grep 'btrfs' | awk '{print $1}' | head -1)
  virt-resize $BASE $CLONE --expand $RFS
  virt-customize -a $CLONE --run-command 'btrfs filesystem resize max /'
else
  RFS=$(virt-filesystems -a $BASE --all --long -h | egrep 'ext|xfs' | awk '{print $1}')
  virt-resize $BASE $CLONE --expand $RFS

  virt-customize -a $CLONE --run-command 'xfs_growfs /'
  virt-customize -a $CLONE --run-command 'echo -e "d\nn\n\n\n\n\nw\n" | fdisk /dev/sda'
  virt-customize -a $CLONE --run-command 'resize2fs /dev/sda1'
fi

virt-customize -a $CLONE --run-command 'sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g"  /etc/ssh/sshd_config'
virt-customize -a $CLONE --run-command 'sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g"  /etc/ssh/sshd_config'
virt-customize -a $CLONE --run-command 'yum remove cloud-init* -y'
virt-customize -a $CLONE --hostname ${CLONE/.qcow2/}
virt-customize -a $CLONE --root-password password:password
virt-customize -a $CLONE --selinux-relabel
