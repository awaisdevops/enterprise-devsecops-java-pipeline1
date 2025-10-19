pipeline {
    agent any

    parameters {
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy'],
            description: 'Select the Terraform action to perform (apply or destroy).'
        )
        booleanParam(
            name: 'DEPLOY_TO_K8S',
            defaultValue: true,
            description: 'Deploy to Kubernetes cluster'
        )
        booleanParam(
            name: 'PERFORM_DESTROY',
            defaultValue: false,
            description: 'DANGER: Check this box to enable the infrastructure destroy stage.'
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
        
        stage('Terraform: Destroy') {
            when {
                expression { params.PERFORM_DESTROY == true }
            }
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps {
                script {
                    echo '==========================================='
                    echo 'Destroying Infrastructure...'
                    echo '==========================================='

                    timeout(time: 15, unit: 'MINUTES') {
                        input message: 'DANGER: This will DESTROY all managed infrastructure. Are you sure you want to proceed?',
                              ok: 'Yes, DESTROY Infrastructure'
                    }

                    dir('infra') {
                        try {
                            sh 'terraform init -upgrade'
                            sh 'terraform destroy -auto-approve'
                            echo '✓ Infrastructure destruction complete.'
                        } catch (Exception e) {
                            echo "✗ Terraform destroy failed: ${e.message}"
                            currentBuild.result = 'FAILURE'
                            error("Destroy stage failed: ${e.message}")
                        }
                    }
                }
            }
        }
    }
   
}