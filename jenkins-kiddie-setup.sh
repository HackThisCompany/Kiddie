#!/bin/bash -e

#
# AWS Credentials.
# ----------------
#   This AWS keys will be uploaded to Jenkins as a secret for
#   Terraform usage purposes. Setup the profile you want to use
#   for Kiddie.
#   You can configure it by executing the following command:
#     $ aws configure --profile kiddie
#
KIDDIE_AWS_CREDENTIALS_PROFILE="kiddie"

#
# SSH private key for Kiddie.
# ---------------------------
#   It will be used to connect to servers. If it is not found,
#   this script will try to generate it via ssh-keygen.
#
KIDDIE_SSH_PRIVATE_KEY_FILE="$HOME/.ssh/kiddie.id_rsa"

#
# Jenkins Instance URL and credentials.
# --------------------------------------------------------
#   - URL where jenkins can be reached.
#   - Credentials file to access Jenkins. Can be generated with:
#      $ echo '<user>:<pass>' > $HOME/.jenkins.credentials
#
KIDDIE_JENKINS_URL="http://localhost:8080"
KIDDIE_JENKINS_CREDENTIALS_FILE="$HOME/.jenkins.credentials"

#################################################################
#    1. SETUP
#################################################################

# Create tmp directory
TMP=$(mktemp -d) && cd $TMP
trap "rm -rf ${TMP}" EXIT

echo '--------------------------------'
# Check requirements
echo "[*] Checking AWS Credentials"
aws sts get-caller-identity --profile ${KIDDIE_AWS_CREDENTIALS_PROFILE}

if [ ! -f "${KIDDIE_SSH_PRIVATE_KEY_FILE}" ]
then
  echo >&2 "[!] File ${KIDDIE_SSH_PRIVATE_KEY_FILE} was not found."
  read -n 1 -r -s -p "[*] Press [ENTER] to force ${KIDDIE_SSH_PRIVATE_KEY_FILE} generation..." && echo
  ssh-keygen -f ${KIDDIE_SSH_PRIVATE_KEY_FILE}
fi

echo '--------------------------------'
# Download jenkins-cli and lias setup
echo "[*] Setting up jenkins-cli"
wget -q -O ${TMP}/jenkins-cli.jar ${KIDDIE_JENKINS_URL}/jnlpJars/jenkins-cli.jar || ( echo >&2 "[!] Jenkins instance seems to be unavailable. Exiting..." && exit 1 )
shopt -s expand_aliases
alias jenkins-cli="java -jar ${TMP}/jenkins-cli.jar -auth @${KIDDIE_JENKINS_CREDENTIALS_FILE} -s ${KIDDIE_JENKINS_URL}"

echo "[*] Testing authentication against Jenkins"
jenkins-cli who-am-i || ( echo >&2 "[!] Cannot authenticate against Jenkins. Exiting..." && exit 1 )

echo '--------------------------------'

#################################################################
#    2. INSTALL JENKINS PLUGINS
#################################################################
JENKINS_PLUGINS=(job-dsl blueocean pipeline-aws)
INSTALLED_PLUGINS=$(jenkins-cli list-plugins | awk '{print $1}')

echo "[*] Installing Jenkins plugins"
installed=false
for plugin in "${JENKINS_PLUGINS[@]}"
do
  if ! fgrep -qx $plugin <<< $INSTALLED_PLUGINS
  then
    jenkins-cli install-plugin $plugin
    installed=true
  else
    echo "Already installed"
  fi
done

if $installed
then
  echo "[*] Restarting jenkins"
  jenkins-cli safe-restart
  echo "[*] Waiting for Jenkins to start"
  until jenkins-cli who-am-i >/dev/null 2>&1
  do
    sleep 5 && echo -n '.'
  done && echo
  echo "[*] Jenkins is ready"
else
  echo "[*] No need to restart jenkins"
fi

echo '--------------------------------'

#################################################################
#    3. CREATE CREDENTIALS
#################################################################
set +e

echo "[*] Creating credential 'AWS-Kiddie'"
KIDDIE_AWS_ACCESS_KEY=$( aws configure get aws_access_key_id     --profile ${KIDDIE_AWS_CREDENTIALS_PROFILE} )
KIDDIE_AWS_SECRET_KEY=$( aws configure get aws_secret_access_key --profile ${KIDDIE_AWS_CREDENTIALS_PROFILE} )
cat > ${TMP}/aws-kiddie-credentials.xml <<EOF
<com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl plugin="aws-credentials@1.28">
  <scope>GLOBAL</scope>
  <id>AWS-Kiddie</id>
  <description>AWS Credential for Kiddie</description>
  <accessKey>${KIDDIE_AWS_ACCESS_KEY}</accessKey>
  <secretKey>${KIDDIE_AWS_SECRET_KEY}</secretKey>
  <iamRoleArn></iamRoleArn>
  <iamMfaSerialNumber></iamMfaSerialNumber>
</com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl>
EOF
jenkins-cli create-credentials-by-xml system::system::jenkins _ < ${TMP}/aws-kiddie-credentials.xml
RC=$?
if [ $RC -ne 0 ] && [ $RC -ne 1 ]
then
  echo >&2 "Something failed. Exiting..." && exit $RC
fi


echo "[*] Creating credential 'kiddie.id_rsa'"
KIDDIE_SSH_PRIVATE_KEY=$( cat ${KIDDIE_SSH_PRIVATE_KEY_FILE} )
cat > ${TMP}/kiddie_id_rsa-credential.xml <<EOF
<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.18.1">
  <scope>GLOBAL</scope>
  <id>kiddie.id_rsa</id>
  <description>Private key for kiddie</description>
  <username>user</username>
  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
    <privateKey>${KIDDIE_SSH_PRIVATE_KEY}</privateKey>
  </privateKeySource>
</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
EOF
jenkins-cli create-credentials-by-xml system::system::jenkins _ < ${TMP}/kiddie_id_rsa-credential.xml
RC=$?
if [ $RC -ne 0 ] && [ $RC -ne 1 ]
then
  echo >&2 "Something failed. Exiting..." && exit $RC
fi

set -e
echo '--------------------------------'

#################################################################
#    3. CREATE Kiddie Seed Job
#################################################################
set +e
KIDDIE_SEED_REPO_URL="https://github.com/HackThisCompany/Kiddie.git"
KIDDIE_SEED_BRANCH="master"
KIDDIE_SEED_FILE="seed.groovy"

echo "[*] Creating Kiddie seed job: ${KIDDIE_SEED_FILE} ( ${KIDDIE_SEED_REPO_URL} )"
cat > ${TMP}/kiddie_seed.xml <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Kiddie seed job</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.plugins.jira.JiraProjectProperty plugin="jira"/>
  </properties>
  <scm class="hudson.plugins.git.GitSCM" plugin="git">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>${KIDDIE_SEED_REPO_URL}</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/${KIDDIE_SEED_BRANCH}</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class="list"/>
    <extensions/>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <javaposse.jobdsl.plugin.ExecuteDslScripts plugin="job-dsl">
      <targets>${KIDDIE_SEED_FILE}</targets>
      <usingScriptText>false</usingScriptText>
      <sandbox>false</sandbox>
      <ignoreExisting>false</ignoreExisting>
      <ignoreMissingFiles>false</ignoreMissingFiles>
      <failOnMissingPlugin>false</failOnMissingPlugin>
      <failOnSeedCollision>false</failOnSeedCollision>
      <unstableOnDeprecation>false</unstableOnDeprecation>
      <removedJobAction>IGNORE</removedJobAction>
      <removedViewAction>IGNORE</removedViewAction>
      <removedConfigFilesAction>IGNORE</removedConfigFilesAction>
      <lookupStrategy>JENKINS_ROOT</lookupStrategy>
    </javaposse.jobdsl.plugin.ExecuteDslScripts>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF
OUTPUT=$( jenkins-cli create-job Kiddie_seed < ${TMP}/kiddie_seed.xml 2>&1 )
RC=$?
if [ $RC -eq 4 ]
then
  echo "Already created"
  echo "[*] Trying to update Kiddie seed job"
  jenkins-cli update-job Kiddie_seed < ${TMP}/kiddie_seed.xml 2>&1
else
  echo $OUTPUT
  if [ $RC -ne 0 ]
  then
    echo >&2 "Something failed. Exiting..." && exit $RC
  fi
fi

set -e
echo '--------------------------------'

#################################################################
#    4. NEXT STEPS INFO
#################################################################
cat <<EOF


================================
          NEXT STEPS            
================================
1) Disable "script security for Job DSL scripts":
     Go to ${KIDDIE_JENKINS_URL}/configureSecurity/ and uncheck "Enable script
     security for Job DSL scripts"
2) Run seed job to generate Kiddie jobs: ${KIDDIE_JENKINS_URL}/job/Kiddie_seed/
3) Use Kiddie/Deploy and Kiddie/Destroy jobs to manage the scenario in your AWS account:
     - ${KIDDIE_JENKINS_URL}/job/Kiddie/job/Deploy
     - ${KIDDIE_JENKINS_URL}/job/Kiddie/job/Destroy
4) Enjoy :)

================================

EOF
