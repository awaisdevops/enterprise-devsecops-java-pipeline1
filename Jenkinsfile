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
        
        // --- Stages for APPLYING Infrastructure ---

        stage("Terraform: Plan Apply"){
            when { expression { params.ACTION == 'apply' } }
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')                
            }
            steps{
                script {
                    echo '==========================================='
                    echo 'Planning Infrastructure Creation...'
                    echo '==========================================='
                    
                    dir('infra') {
                        sh 'terraform init -upgrade'
                        sh 'terraform validate'
                        sh 'terraform plan -out=tfplan -input=false'
                    }
                }
            }
        }

        stage("Infra: Approve Apply"){
            when { expression { params.ACTION == 'apply' } }
            steps{
                script {
                    echo 'Waiting for manual approval...'
                    timeout(time: 30, unit: 'MINUTES') {
                        input message: 'Review the Terraform plan. Approve to apply changes.', 
                              ok: 'Apply Infrastructure'
                    }
                }
            }
        }

        stage("Infra: Apply"){
            when { expression { params.ACTION == 'apply' } }
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps{
                script {
                    echo '==========================================='
                    echo 'Applying Infrastructure Changes...'
                    echo '==========================================='
                    
                    dir('infra') {
                        sh 'terraform apply -auto-approve -input=false tfplan'
                        echo '✓ Infrastructure provisioning complete.'
                    }
                }
            }
        }

        // --- Stages for DESTROYING Infrastructure ---

        stage("Terraform: Plan Destroy") {
            when { expression { params.ACTION == 'destroy' } }
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
                        sh 'terraform plan -destroy -out=tfdestroyplan -input=false'
                    }
                }
            }
        }

        stage("Infra: Approve Destroy") {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                script {
                    echo 'Waiting for manual approval...'
                    timeout(time: 30, unit: 'MINUTES') {
                        input message: 'DANGER: Review the plan. This will DESTROY all infrastructure. Approve to proceed.',
                              ok: 'DESTROY Infrastructure'
                    }
                }
            }
        }

        stage("Terraform: Destroy") {
            when { expression { params.ACTION == 'destroy' } }
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps {
                script {
                    echo '==========================================='
                    echo 'Destroying Infrastructure...'
                    echo '==========================================='
                    dir('infra') {
                        sh 'terraform apply -auto-approve tfdestroyplan'
                        echo '✓ Infrastructure destruction complete.'
                    }
                }
            }
        }
    }
    
    post {
        cleanup {
            // Clean up plan files after any run
            dir('infra') {
                sh 'rm -f tfplan tfdestroyplan 2>/dev/null || true'
            }
        }
    }
}