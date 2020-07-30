# Kiddie
Kiddie is a CTF-like scenario based on two VulnHub machines:
- DC-9: https://www.vulnhub.com/entry/dc-9,412/
- Wintermute Straylight: https://www.vulnhub.com/entry/wintermute-1,239/

The provision of the infrastructure is done with **Terraform** and the configuration of the instances is done with **Ansible**. In addition, to deploy and destroy the scenario in a more comfortable way, **Jenkins** is used.

The main purpose of this project is to pentest on an AWS infrastructure scenario using ethical hacking techniques (with special mention to pivoting) and technologies like TOR.

## How is it organized?
There are four repositories in the scope of this project:
- [Kiddie](https://github.com/HackThisCompany/Kiddie): Main repository with Jenkins stuff and documentation.
- [Kiddie-terraform](https://github.com/HackThisCompany/Kiddie-terraform): Executes the provision of the infrastructure of the Kiddie scenario in AWS with Terraform.
- [DC-9-ansible](https://github.com/HackThisCompany/DC-9-ansible): Configures a DC-9 instance using an Ansible role.
- [Wintermute-Straylight-ansible](https://github.com/HackThisCompany/Wintermute-Straylight-ansible): Configures a Wintermute-Straylight instance using an Ansible role.

*NOTE:* At this time, only the Amazon Linux 2 operating system is supported for DC-9-ansible and Wintermute-Straylight-ansible.

## How to deploy/destroy the scenario
Basically, we need the following:
- [Docker](https://docs.docker.com/engine/install/) to run Jenkins.
- An [AWS Access Key](https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) with Administrator privileges to manage the scenario.
- [`awscli`](https://github.com/aws/aws-cli#installation) tool to interact with the AWS API
- Java to interact with Jenkins via API. *For **Debian** you can execute `sudo apt-get install openjdk-11-jre`*

### Steps
#### 1. Jenkins basic setup.
First of all, run a Jenkins container:
```
$ mkdir $HOME/jenkins_home
$ docker run -d \
    -v $HOME/jenkins_home:/var/jenkins_home \
    -p 127.0.0.1:8080:8080 -p 127.0.0.1:50000:50000 \
    --name htc-jenkins \
    jenkins/jenkins:lts
```

Complete the [post-installation setup wizard](https://www.jenkins.io/doc/book/installing/#setup-wizard) with the **suggested plugins** and an admin account.

#### 2. Configure AWS Kiddie profile.
Create a profile named 'kiddie'.
```
$ aws configure --profile kiddie
AWS Access Key ID [None]: AKIAI**********
AWS Secret Access Key [None]: CTe**********
Default region name [None]: eu-west-1
Default output format [None]:
```

Check that configuration is OK.
```
$ aws sts get-caller-identity --profile kiddie
{
    "UserId": "15*******",
    "Account": "15*******",
    "Arn": "arn:aws:iam::15*******:***"
}
```

#### 3. Save your Jenkins authentication credentials.
```
$ echo '<user>:<pass>' > $HOME/.jenkins.credentials
```

#### 4. Run [`jenkins-kiddie-setup.sh`](https://github.com/HackThisCompany/Kiddie/blob/master/jenkins-kiddie-setup.sh) script.
```
$ wget https://raw.githubusercontent.com/HackThisCompany/Kiddie/master/jenkins-kiddie-setup.sh
$ chmod +x jenkins-kiddie-setup.sh
```
```
$ ./jenkins-kiddie-setup.sh
--------------------------------
[*] Checking AWS Credentials
{
    "UserId": "15*******",
    "Account": "15*******",
    "Arn": "arn:aws:iam::15*******:***"
}
[!] File /home/user/.ssh/kiddie.id_rsa was not found.
[*] Press [ENTER] to force /home/user/.ssh/kiddie.id_rsa generation...
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/user/.ssh/kiddie.id_rsa.
Your public key has been saved in /home/user/.ssh/kiddie.id_rsa.pub.
The key fingerprint is:
SHA256:Uf+aKlNEKAdfvurT59bAprcyiqctvdRK6dUZ+FpaUto user@debian
The key's randomart image is:
+---[RSA 2048]----+
|      .. .o      |
|      ..o+..     |
|       oo.. .    |
|         ..o .   |
|        S.o.o .  |
|         +.*+=   |
|       .=o=oEo   |
|      .B*o=B+ .  |
|      o+B*+Bo.   |
+----[SHA256]-----+
[*] Kiddie pubkey was not found in AWS. Uploading...
{
    "KeyFingerprint": "fc:e6:27:c6:96:c5:2f:5e:7e:09:31:26:d2:a8:34:af",
    "KeyName": "kiddie",
    "KeyPairId": "key-02c85c107c0957a57"
}
--------------------------------
[*] Setting up jenkins-cli
[*] Testing authentication against Jenkins
Authenticated as: <user>
Authorities:
  authenticated
--------------------------------
[*] Installing Jenkins plugins
Installing job-dsl from update center
Installing blueocean from update center
Installing pipeline-aws from update center
[*] Restarting jenkins
[*] Waiting for Jenkins to start
....
[*] Jenkins is ready
--------------------------------
[*] Creating credential 'AWS-Kiddie'
[*] Creating credential 'kiddie.id_rsa'
--------------------------------
[*] Creating Kiddie seed job: seed.groovy ( https://github.com/HackThisCompany/Kiddie.git )

--------------------------------


================================
          NEXT STEPS            
================================
1) Disable "script security for Job DSL scripts":
     Go to http://localhost:8080/configureSecurity/ and uncheck "Enable script
     security for Job DSL scripts"
2) Download ansible and terraform inside Jenkins and add them to the JENKINS PATH.
     Go to section 'Global properties > Environment variables > List of variables' in
     http://localhost:8080/configure/. Then, add something like this:
      | Name : PATH+EXTRA1
      | Value: $HOME/.local/bin
3) Run seed job to generate Kiddie jobs: http://localhost:8080/job/Kiddie_seed/
4) Use Kiddie/Deploy and Kiddie/Destroy jobs to manage the scenario in your AWS account:
     - http://localhost:8080/job/Kiddie/job/Deploy
     - http://localhost:8080/job/Kiddie/job/Destroy
5) Enjoy :)

================================
```

#### 5. Perform "Next Steps" instructions.
1. Disable "script security for Job DSL scripts" for skipping [script approvals](https://www.jenkins.io/doc/book/managing/script-approval/).
2. Download ansible and Terraform and add them to the PATH:
    ```
    $ docker exec -uroot -it htc-jenkins bash
    root@e8bba4e1f82b:/# apt-get update && apt-get install python3 python3-pip -y
    root@e8bba4e1f82b:/# su - jenkins
    jenkins@e8bba4e1f82b:~$ pip3 install ansible
    jenkins@e8bba4e1f82b:~$ wget -O $HOME/.local/bin/terraform.zip https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
    jenkins@e8bba4e1f82b:~$ cd $HOME/.local/bin/ && unzip terraform.zip
    ```
    To add the directory `$HOME/.local/bin/` to the PATH, you need to add the following environmental variable in `Manage Jenkins > Configure System` page inside `Global properties > Environment variables > List of variables` configuration items:
    ```
     Name : PATH+EXTRA1
     Value: $HOME/.local/bin
    ```
3. Run 'Kiddie_seed' DSL Job ("Build Now").
4. Run Deploy/Destroy jobs inside Kiddie folder on demand to manage the scenario.
5. Hack it!

***NOTE:*** The IPs would be shown in the Job log. In Blue Ocean, **go to the end of `Terraform init and apply` stage.**
