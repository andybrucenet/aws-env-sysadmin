#!/usr/bin/env sh

# Instructions:
# 1. Copy this file locally. The below will work if you have
#    ~/bin in your PATH.
#
#      cp ./aws-env-sysadmin-env.sh ~/bin/
#
# 2. Modify the settings of the *copied* file to be your AWS environment setup
#
#      vi ~/bin/aws-env-sysadmin-env.sh
#
# 3. Source in the file:
#
#      source ~/bin/aws-env-sysadmin-env.sh

# settings unique to your environment
export STACK_NAME='aws-env-sysadmin'
export AWS_KEYPAIR_NAME='aws-env-sysadmin'
export AWS_REGION='YOUR_AWS_REGION'
export AWS_VPC_NAME='YOUR_AWS_VPC'
export AWS_PUBLIC_CIDR='YOUR_AWS_PUBLIC_SUBNET'
export AWS_PRIVATE_CIDR='YOUR_AWS_PRIVATE_SUBNET'
export AWS_VGW_NAME='YOUR_AWS_VPN_GATEWAY'
export AWS_IGW_NAME='YOUR_AWS_INTERNET_GATEWAY'

# gather information
export AWS_VPC_ID=$(aws-cli ec2 describe-vpcs --filter Name=tag:Name,Values=$AWS_VPC_NAME --query 'Vpcs[].VpcId' --output text | sed -e 's#\s##g')
echo "AWS_VPC_ID='$AWS_VPC_ID'"
export AWS_VGW_ID=$(aws-cli ec2 describe-vpn-gateways --filter Name=tag:Name,Values=$AWS_VGW_NAME --query 'VpnGateways[].VpnGatewayId' --output text | sed -e 's#\s##g')
echo "AWS_VGW_ID='$AWS_VGW_ID'"
export AWS_IGW_ID=$(aws-cli ec2 describe-internet-gateways --filter Name=tag:Name,Values=$AWS_IGW_NAME --query 'InternetGateways[].InternetGatewayId' --output text | sed -e 's#\s##g')
echo "AWS_IGW_ID='$AWS_IGW_ID'"

