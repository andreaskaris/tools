#!/bin/bash

systemctl stop neutron-openvswitch-agent
mv /etc/openvswitch/conf.db{,.back}
systemctl restart openvswitch
socket_mem=4096,4096
pmd_cpu_mask=17c0017c
host_cpu_mask=100001
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem=$socket_mem
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=$pmd_cpu_mask
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-lcore-mask=$host_cpu_mask

ovs-vsctl add-br br1 -- set bridge br1 datapath_type=netdev
ip link add ovs-bond-if0 type veth peer name lx-bond-if0
ip link add ovs-bond-if1 type veth peer name lx-bond-if1
ip link add lx-bond0 type bond miimon 100 mode 802.3ad
ip link set dev lx-bond-if0 master lx-bond0
ip link set dev lx-bond-if1 master lx-bond0
ip link set dev lx-bond-if0 up
ip link set dev lx-bond-if1 up
ip link set dev ovs-bond-if0 up
ip link set dev ovs-bond-if1 up
ip link set dev lx-bond0 up
ovs-vsctl add-bond br1 dpdkbond1 ovs-bond-if0 ovs-bond-if1 -- set port dpdkbond1 lacp=active -- set port dpdkbond1 bond_mode=balance-tcp --  set port dpdkbond1 other-config:lacp-time=fast
ip a a dev lx-bond0 192.168.123.10/24
ip link add veth2 type veth peer name veth3
ip netns add test
ip link set dev veth2 netns test
ip link set dev veth3 up
ip netns exec test ip link set dev lo up
ip netns exec test ip link set dev veth2 up
ip netns exec test ip a a dev veth2 192.168.123.11/24
ovs-vsctl add-port br1 veth3  #  if to be added as tagged, add: tag=905

