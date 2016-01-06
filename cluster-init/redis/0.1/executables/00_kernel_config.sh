#!/bin/bash

echo "Configuring kernel for high memory redis application..."

# rc.local is deprecated in centos, find something better
echo 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' >> /etc/rc.local
echo never > /sys/kernel/mm/transparent_hugepage/enabled

echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
sysctl vm.overcommit_memory=1

echo 'net.core.somaxconn = 512' > /etc/sysctl.conf
sysctl net.core.somaxconn=512
