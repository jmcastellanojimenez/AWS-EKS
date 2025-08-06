#!/bin/bash
set -o xtrace

# Bootstrap the node
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments}

# Install additional tools for learning
yum update -y
yum install -y htop iotop

# Configure container runtime optimizations for cost
echo 'net.core.somaxconn=65535' >> /etc/sysctl.conf
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
sysctl -p

# Setup logging
/opt/aws/bin/cfn-signal -e $? --stack ${cluster_name} --resource NodeGroup --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)