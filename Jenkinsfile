pipeline {
    agent any

    tools {
        maven 'maven'
    }
     
    // Add parameters for environment selection
    parameters {
        choice(
            name: 'DEPLOY_ENV',
            choices: ['dev', 'staging', 'prod'],
            description: 'Select deployment environment'
        )    
        booleanParam(
            name: 'DEPLOY_TO_K8S',
            defaultValue: true,
            description: 'Deploy to Kubernetes cluster'
        )
    }

    // Environment-specific configurations
    environment {
        // Docker registry
        DOCKER_REGISTRY = 'awaisakram11199/devopsimages'
        
        // AWS Region
        AWS_REGION = 'ap-northeast-2'

        // Sonar Qube
        SONAR_HOME= tool "SQ"
    }   
    
    stages {              
        
        
        stage('Build & Package') {
            // tags: maven,compile,package
            steps {
                script {
                    echo "building the application..."
                    // Use mvn clean package to compile, run tests, and package the app
                    // mvn builds app. clean removes older builds files. Dockerfile will fetch newer build app version 
                    sh 'mvn clean package -DskipTests'
                }
            }
        }
            

        /*
        stage("SonarQube: Code Scan"){
            steps{
                withSonarQubeEnv("SQ"){                    
                    // The Maven plugin handles paths to binaries automatically.
                    sh "mvn clean verify sonar:sonar"
                }
            }
        }     
        */   

        /*
        stage("OWASP: Dependency Check"){
            steps{
                dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dc'
                dependencyCheckPublisher pattern: '/app-dep-check-report.html'
            }
        }        
        */

        /*
        stage("Trivy: Filesystem Scan"){
            steps{
                sh "trivy fs --format  table -o trivy-fs-report.json ."
            }
        }   
        */

        /*
        stage("SonarQube: Quality Gate"){
            steps{
                timeout(time: 10, unit: "MINUTES"){
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        */

        /*    
        stage('Docker: Build Image') {              

            steps {
                script {
                    echo "building the docker image..."
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'PASS', usernameVariable: 'USER')]) {

                        sh "docker build -t ${DOCKER_REGISTRY}:${env.IMAGE_NAME} ."
                        sh 'echo $PASS | docker login -u $USER --password-stdin'
                        sh "docker push ${DOCKER_REGISTRY}:${env.IMAGE_NAME}"
                        
                    }
                }
            }
        }    
        
        /*
        stage('Trivy: Image Scan'){            
            steps{
                script {                    
                    // 1. Define local variable for the image tag
                    def FULL_IMAGE_TAG = "${DOCKER_REGISTRY}:${env.IMAGE_NAME}"

                    // 2. Execute the shell command using the variable                    
                    //sh "trivy image --format json -o trivy-image-report.json ${env.FULL_IMAGE_TAG}"
                    sh "trivy image --format json -o trivy-image-report.json ${FULL_IMAGE_TAG}"                    

                    // 3. Archive the report artifact (This step can be outside 'script' but is often placed here for flow)
                    archiveArtifacts artifacts: 'trivy-image-report.json', onlyIfSuccessful: true
                }
            }
        }   
        */    
                
        
        stage("Terraform: Destroy"){
            
             environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')                
            }
            steps{
                script {
                    echo '==========================================='
                    echo 'Destroying Infrastructure...'
                    echo '==========================================='
                    
                    dir('infra') {
                        
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
    }
    
    post {
        success {
            mail to: 'awais.akram11199@gmail.com',
                 subject: "SUCCESS: Jenkins Build ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The Jenkins build was successful. Check build details: ${env.BUILD_URL}"
        }
        
        failure {
            mail to: 'awais.akram11199@gmail.com',
                 subject: "FAILURE: Jenkins Build ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The Jenkins build FAILED! Please investigate: ${env.BUILD_URL}"
        }
    }
}