#!/bin/sh
# aws-env-sysadmin-hosts.sh, ABr
# Read created hosts from AWS and extract IP addresses.
# Useful for creating a standard /etc/hosts file for each generated VM.
#set -x
l_names=$(DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" aws-cli ec2 describe-instances \
  --filters \
    Name=tag:aws:cloudformation:stack-name,Values=$STACK_NAME \
    Name=instance-state-name,Values=running \
  --query \
    'Reservations[].Instances[].Tags[?Key==`Name`].Value[]' \
    --output text \
  | sed -e 's#\s# #g' \
)
for i in $l_names ; do
  l_ip=$(DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" aws-cli ec2 describe-instances \
    --filters Name=tag:Name,Values=$i Name=instance-state-name,Values=running \
    --query 'Reservations[].Instances[].NetworkInterfaces[0].PrivateIpAddresses[0].PrivateIpAddress' \
    --output text \
    | sed -e 's#\s##g' \
  )
  l_short_name=$(echo "$i" | sed -e 's#^[^A-Z]\+\(.*\)#\1#')
  echo "$l_ip $l_short_name"
done

