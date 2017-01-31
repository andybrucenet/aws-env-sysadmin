# AWS SysAdmin Test Lab Setup

The associated CloudFormation template will require some work from you before you can use it effectively. It was created for a different environment with a backend Puppet, access to authorized Cisco IOS images (for `dynagen` / `dynamips` support), and so on. But it should be an excellent starting point.

The goal is to create a SysAdmin interview test lab on AWS. This test lab will consist of a CentOS, Ubuntu, W2K12R2 and W2K16 server.

1. *AWS Setup*. This all happens ahead of time.
   * VPC - You need to specify the VPC to use.
   * Public CIDR (Subnet) - Routable to a backend that can do something withe the Puppet integration used by the CentOS box. If you don't have this, you will only need to change the launch configuration for the CentOS box *not* to use the customized yum repositories.
   * Private CIDR (Subnet) - This is the subnet that all of the created systems will be on. Should be non-routable from everywhere.
   * InternalGatewayId - Gateway to get to your backend. In the generic case where you are starting from this project to setup your own testing environment and you don't have a VPN, then modify the CloudFormation template so that you leverage your Internet Gateway.
   * InternetGatewayId - Your gateway to get to Internet.
<br />
1. *S3 Setup*. Do this before building the stack.
   * Create an S3 bucket for this effort using the same name as the stack.
1. *Create Stack*.
   * Create a new keypair on AWS for the test. This keypair will be used by the candidate. For example:

        ```
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-env-sysadmin.pem
        ```

     Import this to AWS. Be sure to copy this private key as the file `private-key` in the S3 bucket. This private key will then be available to the auto-created `l.login` user on the OOB box. This will permit the candidate to move around between boxes.
   * Setup the variables to create the stack:

        ```
        STACK_NAME='aws-env-sysadmin'
        AWS_REGION='YOUR_REGION'
        AWS_VPC_NAME='YOUR_VPC'
        AWS_PUBLIC_CIDR='YOUR_PUBLIC_SUBNET'
        AWS_VGW_NAME='YOUR_VPN_GATEWAY_NAME'
        AWS_IGW_NAME='YOUR_INTERNET_GATEWAY_NAME'
        AWS_PRIVATE_CIDR='YOUR_PRIVATE_SUBNET'
        AWS_KEYPAIR_NAME='aws-env-sysadmin'
        ```
     _Note:_ For convenience, I save off these settings in a single shell script with values specific to my environment.
   * Load the variables using dynamic lookup. Note in the below we assume an alias named aws-cli which will properly resolve to the correct `aws` command. (We do this because we use a Docker wrapper over the AWS CLI in our environment.)

        ```
        AWS_VPC_ID=$(aws-cli ec2 describe-vpcs --filter Name=tag:Name,Values=$AWS_VPC_NAME --query 'Vpcs[].VpcId' --output text | sed -e 's#\s##g')
        echo "AWS_VPC_ID='$AWS_VPC_ID'"
        AWS_VGW_ID=$(aws-cli ec2 describe-vpn-gateways --filter Name=tag:Name,Values=$AWS_VGW_NAME --query 'VpnGateways[].VpnGatewayId' --output text | sed -e 's#\s##g')
        echo "AWS_VGW_ID='$AWS_VGW_ID'"
        AWS_IGW_ID=$(aws-cli ec2 describe-internet-gateways --filter Name=tag:Name,Values=$AWS_IGW_NAME --query 'InternetGateways[].InternetGatewayId' --output text | sed -e 's#\s##g')
        echo "AWS_IGW_ID='$AWS_IGW_ID'"
        ```
     _Note:_ For convenience, I combined the above with the variable settings from the previous step...now I simply `source` in a single shell script and I get all of my settings ready to go. Here's a standard run:

        ```
        CloudraticSolutionsLLCs-MacBook-Pro:aws-env-sysadmin l.abruce$ source aws-env-sysadmin
        AWS_VPC_ID='vpc-d8d6d6bd'
        AWS_VGW_ID='vgw-32a07e2c'
        AWS_IGW_ID='igw-a3c6b4c6'
        ```
     And we should be ready to go with the above values.
   * Create the stack. The following users our nifty Docker wrapper in conjunction with a python wrapper over the AWS cloudformation calls.
     First, we need to compress the template - as it is, it is slightly above the 51,200 character limit imposed by AWS. We use a tool called `cfn-check` (see https://www.npmjs.com/package/cfn-check); this tool not only verifies AWS CloudFormation templates, it also *compresses* the output.

        ```
        mkdir -p ./work
        DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" ~/bin/aws-helpers cfn-check \
          --compact ./cfn/aws-env-sysadmin.cfn \
          > ./work/aws-env-sysadmin.cfn
        ```
        Now we can do the actual stack build using AWS CLI:

        ```
        DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" \
          ./aws-env-sysadmin-stacks.py \
          --cmd `which aws-cli` \
          --option create \
          --region $AWS_REGION \
          --name $STACK_NAME \
          --file-template ./work/aws-env-sysadmin.cfn \
          --override-keys \
            VpcId PublicCidrBlock InternalGatewayId InternetGatewayId PrivateCidrBlock KeyName \
          --override-values \
            $AWS_VPC_ID $AWS_PUBLIC_CIDR $AWS_VGW_ID $AWS_IGW_ID $AWS_PRIVATE_CIDR $AWS_KEYPAIR_NAME
        ```
   * Get the list of IPs. We'll use the output from the below script to update `/etc/hosts`

        ```
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
        ```
        Output will be similar to:

        ```
        172.20.241.4 W2K12
        172.20.241.11 Ubuntu
        172.20.197.12 Oob
        172.20.241.7 Centos
        172.20.241.10 W2K16
        ```
<br />
1. *Post-Process Stack - Windows Passwords*. We don't use any Chocolatey or Puppet - so get the passwords manually and save them to a file that `l.login` user can access.
<br />
1. *Post-Process Stack - OOB Node*. There are a number of steps which are too time-consuming / error-prone to automate.
   * Set `l.login` password:

        ```
        sudo passwd l.login
        ```
   * Setup VNC.

        ```
        sudo su - l.login
        vncserver
        ```
     * Verify that VNC login works through the public IP.
     * *While are in the login*, save the Windows passwords.
   * Update `/etc/hosts`. Use the output from the script above.
<br />
1. *Post-Process Stack - CentOS Node*. We just setup some quick networking for tests.
   * Run `puppet` agent. We don't do this automatically in case the PuppetMaster still has an old definition.

        ```
        sudo su -
        puppet agent -t
        exit
        ```
   * Start `dynamips`:

        ```
        sudo su -
        mkdir -p /home/dynagen/dynamips
        cd /home/dynagen/dynamips
        screen -md -S dynamips -t dynamips dynamips -H 7200
        cd -
        exit
        ```
   * Start first `dynagen` lab.

        ```
        cd /home/dynagen/proj/00-FirstLab
        sudo chmod 777 .
        yes | sudo cp 00-FirstLab.net-orig 00-FirstLab.net
        yes | sudo cp R1.cfg-orig R1.cfg
        screen -md -S dynagen -t dynagen dynagen ./00-FirstLab.net
        cd -
        ```
   * Verify that you can connect:

        ```
        screen telnet localhost 50001
        ```

After the stack creates, you must enable VNC login. This is not enabled by default as VNC is a major security risk.

