String repo="https://github.com/HackThisCompany/Kiddie.git"

folder("Kiddie"){
  displayName('Kiddie')
  description('Kiddie Scenario')
}

pipelineJob("Kiddie/Deploy") {
  description()
  definition {
    cpsScm {
      scm {
        git {
          remote {
            url(repo)
          }
          branch("*/master")
        }
      }
      scriptPath("pipelines/Jenkinsfile.deploy")
    }
  }
}

pipelineJob("Kiddie/Destroy") {
  description()
  definition {
    cpsScm {
      scm {
        git {
          remote {
            url(repo)
          }
          branch("*/master")
        }
      }
      scriptPath("pipelines/Jenkinsfile.destroy")
    }
  }
}
