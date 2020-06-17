def awsCredentials = 'AWS-HackThisCompany'
def github_baseurl = "https://github.com/HackThisCompany"

def terraform_tfvars = 'htc-kiddie-test.tfvars'
def kiddie_sshkey = "kiddie.id_rsa"

pipeline {
    agent any
    
    parameters {
        string(
            name: 'Kiddieterraformbranch', defaultValue: 'master',
            description: 'Which Kiddie-terraform branch should be used?'
        )
        string(
            name: 'DC9ansiblebranch', defaultValue: 'htc',
            description: 'Which DC-9-ansible branch should be used?'
        )
        string(
            name: 'WintermuteStraylightansiblebranch', defaultValue: 'master',
            description: 'Which Wintermute-Straylight-ansible branch should be used?'
        )
    }

    stages {
        stage('Clone repos') {
            steps {
                dir('Kiddie-terraform') {
                    git url: "${github_baseurl}/Kiddie-terraform.git", branch: "${params.Kiddieterraformbranch}"
                }
                dir('DC-9-ansible') {
                    git url: "${github_baseurl}/DC-9-ansible.git", branch: "${params.DC9ansiblebranch}"
                }
                dir('Wintermute-Straylight-ansible') {
                    git url: "${github_baseurl}/Wintermute-Straylight-ansible.git", branch: "${params.WintermuteStraylightansiblebranch}"
                }
            }
        }
        stage('Terraform init and apply') {
            steps {
                withAWS(credentials: "${awsCredentials}"){
                    withCredentials([sshUserPrivateKey(credentialsId: "${kiddie_sshkey}", keyFileVariable: 'kiddie_sshkeyfile')]) {
                        sh """
                        cp "${kiddie_sshkeyfile}" "${env.WORKSPACE}/kiddie.id_rsa"
                        """
                        sh """
                        cat "${env.WORKSPACE}/kiddie.id_rsa"
                        """
                        dir('Kiddie-terraform') {
                            sh """
                            terraform init
                            """
                            sh """
                            terraform workspace select test
                            """
                            sh """
                            [ ! -f "${terraform_tfvars}" ] && cat > "${terraform_tfvars}" <<EOF
                            tags = {
                                Project            = "HackThisCompany"
                                Environment        = "test"
                            }
                            local_privkey_path = "${env.WORKSPACE}/kiddie.id_rsa"
                            EOF
                            """.stripIndent()
                            sh """
                            cat "${terraform_tfvars}"
                            """
                            sh """
                            terraform apply --var-file ${terraform_tfvars} --auto-approve
                            """
                        }
                    }
                }
            }
        }
        
        stage('Retrieve Ansible inventory from Terraform output') {
            steps {
                script {
                    withAWS(credentials: "${awsCredentials}"){
                        dir('Kiddie-terraform') {
                            sh """
                            terraform output -json ansibleinventory > ${env.WORKSPACE}/ansibleinventory.json
                            """
                        }
                    }
                }
            }
        }
        
        stage('Wait for servers to be ready') {
            steps {
                sh """
                export ANSIBLE_HOST_KEY_CHECKING=False
                while ! ansible all -i ${env.WORKSPACE}/ansibleinventory.json -m ping -e ansible_python_interpreter=python
                do
                    sleep 5
                done
                """
            }
        }
        
        stage('Server provision') {
            steps {
                parallel(
                    dc9: {
                        sh """
                        ansible dc9 -i ${env.WORKSPACE}/ansibleinventory.json -m shell -a "yum update -y && yum install -y python3 python3-pip git-core" -e ansible_python_interpreter=/usr/bin/python --become
                        """
                        sh """
                        ansible dc9 -i ${env.WORKSPACE}/ansibleinventory.json -m shell -a "pip3 install -r https://raw.githubusercontent.com/HackThisCompany/DC-9-ansible/htc/tests/requirements.txt" -e ansible_python_interpreter=/usr/bin/python --become
                        """
                        sh """
                        cat > dc9-provision.yml <<EOF
                        - name: 'Provide DC-9 server'
                          hosts: dc9
                          become: yes
                          roles:
                            - role: ./DC-9-ansible
                              vars:
                                ansible_python_interpreter: python3
                        EOF
                        """.stripIndent()
                        sh """
                        ansible-playbook -i ${env.WORKSPACE}/ansibleinventory.json dc9-provision.yml
                        """
                    },
                    wintermute_straylight: {
                        sh """
                        ansible wintermute_straylight -i ${env.WORKSPACE}/ansibleinventory.json -m shell -a "yum update -y && yum install -y python3 python3-pip git-core" -e ansible_python_interpreter=/usr/bin/python --become
                        """
                        sh """
                        cat > wintermute-straylight-provision.yml <<EOF
                        - name: 'Provide Wintermute Straylight server'
                          hosts: wintermute_straylight
                          become: yes
                          roles:
                            - role: ./Wintermute-Straylight-ansible
                              vars:
                                ansible_python_interpreter: python3
                        EOF
                        """.stripIndent()
                        sh """
                        ansible-playbook -i ${env.WORKSPACE}/ansibleinventory.json wintermute-straylight-provision.yml
                        """
                    }
                )
            }
        }
    }
    post {
        cleanup {
            cleanWs()
        }
    }
}

