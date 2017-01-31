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
   * Setup the variables to create the stack. We provide a handy script `aws-env-sysadmin-env.sh` *with instructions* so you can automate this process.
     To load in the values, just `source` the script. Here's a sample run:

        ```
        CloudraticSolutionsLLCs-MacBook-Pro:aws-env-sysadmin l.abruce$ source ~/aws-env-sysadmin.sh
        AWS_VPC_ID='vpc-d8d6d6bd'
        AWS_VGW_ID='vgw-32a07e2c'
        AWS_IGW_ID='igw-a3c6b4c6'
        ```
     And we should be ready to go with the above values.
   * Create the stack. First, we need to compress the template - as it is, it is slightly above the 51,200 character limit imposed by AWS. We use a tool called `cfn-check` (see https://www.npmjs.com/package/cfn-check); this tool not only verifies AWS CloudFormation templates, it also *compresses* the output.

        ```
        mkdir -p ./work
        DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" ~/bin/aws-helpers cfn-check \
          --compact ./cfn/aws-env-sysadmin.cfn \
          > ./work/aws-env-sysadmin.cfn
        ```
        Next, we use our nifty Docker wrapper in conjunction with a python wrapper over the AWS cloudformation calls:

        ```
        DOCKER_OPTS="-v $(pwd -P):/local:ro -w /local" \
          ./aws-env-sysadmin.py \
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
        The above doesn't actually run the command; it simply outputs the proper command that needs to be updated.
   * Get the list of IPs. We created a gnarly little script that gets this information directly from AWS; we provide a script for this to update `/etc/hosts`. Here's a sample run:

        ```
        CloudraticSolutionsLLCs-MacBook-Pro:aws-env-sysadmin l.abruce$ ./aws-env-sysadmin-hosts.sh
        172.20.241.4 Ubuntu
        172.20.241.9 W2K12
        172.20.197.4 Oob
        172.20.241.6 W2K16
        172.20.241.14 Centos
        ```
<br />
1. *Useful Stack Data Calls*. While the stack is building, you can login to each VM as it is created. You may be curious to see what metadata is passed in. Here are some examples:

   * _General Metadata_. You can use:
   
       ```
       curl http://169.254.169.254/latest/ && echo ''
       ```
       That returns all metadata available from the instance.
   * _UserData._ The `UserData` is executed automatically by the launched VM (instance). We use it to kick-start the `cfn-init` process we discuss just below :)
   
       ```
       curl http://169.254.169.254/latest/user-data && echo ''
       ```
     You will see the commands that the instance executes.
   * _cfn-init._ The `cfn-init` processes permit you to drive policy (such as installed programs) directly from the CloudFormation template. In fact, you can add new commands / software to the running instance by simply modifying the `AWS::CloudFormation::Init` section of the CloudFormation template associated with the launched instance.

     First, get the stack information (either from the AWS Console or by examining the `user-data` call above). For example:
   
       ```
       [root@ip-172-20-197-4 data]# curl -s http://169.254.169.254/latest/user-data | grep cfn-init
       /opt/aws/bin/cfn-init --stack aws-env-sysadmin --resource vmOob --region us-west-2
       ```
     The output above shows the stack and region name. Now we can query CloudFormation to get the list of commands that will execute:
   
       ```
       /opt/aws/bin/cfn-get-metadata --stack aws-env-sysadmin --resource vmOob --region us-west-2
       ```
     We cut the output from the above...but you will recognize it from the CloudFormation template submitted to AWS.
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

