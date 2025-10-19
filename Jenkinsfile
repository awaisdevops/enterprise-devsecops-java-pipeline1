pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select the Terraform action to perform (apply or destroy).'
        )
    }
     
    environment {
        AWS_REGION = 'ap-northeast-2'
    }   
    
    stages {
        
        

        // --- Stages for DESTROYING Infrastructure ---

        stage("Terraform: Plan Destroy") {
           
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps {
                script {
                    echo '==========================================='
                    echo 'Planning Infrastructure Destruction...'
                    echo '==========================================='
                    dir('infra') {
                        sh 'terraform init -upgrade'
                        sh 'terraform plan -destroy --out=tfdestroyplan'
                    }
                }
            }
        }
    }
   
}