pipeline {
    agent any

    tools {
        maven 'maven'
    }

    /*
    environment{
        SONAR_HOME= tool "SQ"
    }
    */

    stages {

        stage('Prepare: Increment Application Version') {
            steps {
                script {
                    echo 'incrementing app version...'
                    sh 'mvn build-helper:parse-version versions:set \
                        -DnewVersion=\\\${parsedVersion.majorVersion}.\\\${parsedVersion.minorVersion}.\\\${parsedVersion.nextIncrementalVersion} \
                        versions:commit'
                    def matcher = readFile('pom.xml') =~ '<version>(.+)</version>'
                    def version = matcher[0][1]
                    env.IMAGE_NAME = "$version-$BUILD_NUMBER"
            }
            }
        }
        
        stage('CI: Compile and Package Application') {
            steps {
                script {
                    echo "building the application..."
                    // Use mvn clean package to compile, run tests, and package the app
                    // mvn builds app. clean removes older builds files. Dockerfile will fetch newer build app version 
                    sh 'mvn clean package -DskipTests'
                }
            }
        }
        
        stage('Test: Execute Unit Tests') {
            steps {
                echo 'Running Unit Tests...'
                // 'withMaven' step ensures the correct Maven environment is used
                withMaven(maven: 'maven') { 
                    sh 'mvn test'
                }
            }            
            post {
                // 'always' ensures the reports are collected even if tests fail
                always {
                    // Collect and publish JUnit test reports
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/TEST-*.xml' 
                }
            }
        }
                
        stage('Test: Run Integration Tests') {
            steps {
                echo 'Running Integration Tests...'
                // Running 'verify' executes both the tests and the result check
                withMaven(maven: 'maven') { 
                    sh 'mvn verify -DskipUnitTests'  // Skip unit tests, only run integration tests
                }
            }
            post {
                always {
                    // Collect and publish Failsafe test reports
                    junit allowEmptyResults: true, testResults: '**/target/failsafe-reports/TEST-*.xml'
                }
            }
        }
        
        
        //stage("Security & Quality: SonarQube Static Analysis"){
            //steps{
                //withSonarQubeEnv("SQ"){                    
                    // The Maven plugin handles paths to binaries automatically.
                    //sh "mvn clean verify sonar:sonar"
                //}
            //}
        //}
        
        
        //stage("Security: OWASP Dependency Check (SCA)"){
            //steps{
                //dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dc'
                //dependencyCheckPublisher pattern: '**/app-dep-check-report.html'
            //}
        //}
        
        /*
        stage("Security: Trivy Filesystem Scan"){
            steps{
                sh "trivy fs --format  table -o trivy-fs-report.json ."
            }
        }
        

        stage("Quality Gate: Wait for SonarQube Approval"){
            steps{
                timeout(time: 2, unit: "MINUTES"){
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        */
        /*
        stage('Package: Build and Tag Docker Image') {

            //when {
                //expression { 
                    //BRANCH_NAME == 'main' 
                //} 
            //}

            steps {
                script {
                    echo "building the docker image..."
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'PASS', usernameVariable: 'USER')]) {

                        sh "docker build -t awaisakram11199/devopsimages:${IMAGE_NAME} ."
                        sh 'echo $PASS | docker login -u $USER --password-stdin'
                        sh "docker push awaisakram11199/devopsimages:${IMAGE_NAME}"
                        
                    }
                }
            }
        }    
        
        stage('Security: Trivy Container Image Scan'){            
            steps{
                script {                    
                    // 1. Define local variable for the image tag
                    def FULL_IMAGE_TAG = "awaisakram11199/devopsimages:${IMAGE_NAME}"

                    // 2. Execute the shell command using the variable                    
                    //sh "trivy image --format json -o trivy-image-report.json ${FULL_IMAGE_TAG}"
                    sh "trivy image --format json -o trivy-image-report.json ${FULL_IMAGE_TAG}"                    

                    // 3. Archive the report artifact (This step can be outside 'script' but is often placed here for flow)
                    archiveArtifacts artifacts: 'trivy-image-report.json', onlyIfSuccessful: true
                }
            }
        }
        */
        
        stage("Infrastructure: Plan Terraform Changes"){
             environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')                
            }
            steps{
                script {
                    echo '==========================================='
                    echo 'Planning Infrastructure Changes...'
                    echo '==========================================='
                    
                    dir('infra') {
                        try {
                            // Verify AWS credentials
                            sh 'aws sts get-caller-identity'
                            
                            // Initialize Terraform
                            echo 'Initializing Terraform...'
                            sh 'terraform init -upgrade -reconfigure -no-color'
                            
                            // Validate configuration
                            echo 'Validating Terraform configuration...'
                            sh 'terraform validate -no-color'
                            
                            // Format check
                            echo 'Checking Terraform formatting...'
                            sh 'terraform fmt -check -recursive || true'
                            
                            // Create plan
                            echo 'Creating Terraform plan...'
                            sh 'terraform plan -out=tfplan -no-color -input=false'
                            sh 'terraform show -no-color tfplan > tfplan-output.txt'
                            
                            // Archive plan
                            archiveArtifacts artifacts: 'tfplan,tfplan-output.txt', 
                                        allowEmptyArchive: false,
                                        fingerprint: true
                            
                            echo '✓ Terraform plan completed successfully'
                            
                        } catch (Exception e) {
                            echo "✗ Terraform planning failed: ${e.message}"
                            currentBuild.result = 'FAILURE'
                            error("Planning stage failed: ${e.message}")
                        }
                    }
                }
            }
        }

        stage("Infrastructure: Review and Approve"){
            steps{
                script {
                    echo 'Waiting for manual approval...'
                    
                    try {
                        timeout(time: 2, unit: 'MINUTES') {
                            input message: 'Review the Terraform plan and approve to proceed', 
                                ok: 'Apply Infrastructure',
                                submitter: 'admin,devops-team'
                        }
                        echo '✓ Deployment approved'
                    } catch (Exception e) {
                        echo '✗ Deployment not approved'
                        currentBuild.result = 'ABORTED'
                        error('Infrastructure deployment was not approved')
                    }
                }
            }
        }

        stage("Infrastructure: Apply Terraform Changes"){
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
                AWS_REGION = 'ap-northeast-2'               
            }
            steps{
                script {
                    echo '==========================================='
                    echo 'Applying Infrastructure Changes...'
                    echo '==========================================='
                    
                    dir('infra') {
                        try {
                            // Re-verify credentials
                            sh 'aws sts get-caller-identity'
                            
                            // Apply the plan
                            echo 'Applying Terraform changes...'
                            sh 'terraform apply -auto-approve -no-color -input=false tfplan 2>&1 | tee terraform-apply.log'
                            
                            // Capture outputs
                            echo 'Capturing Terraform outputs...'
                            sh 'terraform output -no-color > terraform-outputs.txt'
                            sh 'terraform output -json > terraform-outputs.json'
                            
                            archiveArtifacts artifacts: 'terraform-apply.log,terraform-outputs.txt,terraform-outputs.json', 
                                        allowEmptyArchive: true
                            
                            // Extract infrastructure details
                            def clusterName = sh(
                                script: 'terraform output -raw cluster_name 2>/dev/null || echo "N/A"', 
                                returnStdout: true
                            ).trim()
                            
                            def clusterEndpoint = sh(
                                script: 'terraform output -raw cluster_endpoint 2>/dev/null || echo "N/A"', 
                                returnStdout: true
                            ).trim()
                            
                            def vpcId = sh(
                                script: 'terraform output -raw dc-llc-vpc-id 2>/dev/null || echo "N/A"', 
                                returnStdout: true
                            ).trim()
                            
                            // Store as environment variables
                            env.EKS_CLUSTER_NAME = clusterName
                            env.EKS_CLUSTER_ENDPOINT = clusterEndpoint
                            env.VPC_ID = vpcId
                            
                            // Configure kubectl
                            if (clusterName != 'N/A') {
                                echo 'Configuring kubectl for EKS cluster...'
                                sh """
                                    aws eks update-kubeconfig \
                                        --name ${clusterName} \
                                        --region ${AWS_REGION}
                                    kubectl cluster-info
                                    kubectl get nodes
                                """
                            }
                            
                            // Display summary
                            echo '==========================================='
                            echo '✓ Infrastructure Provisioned Successfully!'
                            echo '==========================================='
                            echo "EKS Cluster Name: ${clusterName}"
                            echo "EKS Cluster Endpoint: ${clusterEndpoint}"
                            echo "VPC ID: ${vpcId}"
                            echo '==========================================='
                            
                        } catch (Exception e) {
                            echo "✗ Terraform apply failed: ${e.message}"
                            sh 'tail -100 terraform-apply.log 2>/dev/null || true'
                            currentBuild.result = 'FAILURE'
                            error("Apply stage failed: ${e.message}")
                        }
                    }
                }
            }
            post {
                cleanup {
                    dir('infra') {
                        sh 'rm -f tfplan 2>/dev/null || true'
                    }
                }
            }
        }

        stage('Deploy: Deploy to Environment') {

            //when {
                //expression { 
                    //BRANCH_NAME == 'main' 
                //} 
            //}
            
            steps {
                script {
                    echo 'deploying docker image to EC2...'
                }
            }
        }

        stage('SCM: Commit New App Version') {
            steps {
                script {

                    // Retrieve the credentials. $PASS MUST be the GitHub Personal Access Token (PAT).
                  
                  withCredentials([usernamePassword(credentialsId: 'github-credentials', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                                  
                    // --- GITHUB PAT AUTH FIX ---
                    // GitHub rejects the traditional 'username:password@...' format.
                    // It requires the token to be used as the password with 'x-oauth-basic' as the placeholder username.
                    
                    def patUsername = "x-oauth-basic"
                    
                    // Construct the secure URL: https://x-oauth-basic:<PAT>@github.com/...
                    
                    def remoteUrl = "https://${patUsername}:${PASS}@github.com/awaisdevops/enterprise-devsecops-java-pipeline1.git"
                    
                    // ---------------------------

                    // 1. Configure Git for the commit author                    
                    sh 'git config --global user.email "jenkins@example.com"'
                    sh 'git config --global user.name "jenkins"'

                    // 2. Set the remote URL using the PAT-based authentication URL                    
                    sh "git remote set-url origin ${remoteUrl}"
                    
                    // 3. Commit and Push  
                    sh '''
                        git add pom.xml
                        git add src/
                        git commit -m "ci: Automated version bump [skip ci]"
                        git push origin HEAD:main
                    '''
                    }
                }
            }
        }
        
    }

    /*
    post {
        // Send email on successful completion
        success {
            mail to: 'awais.akram11199@gmail.com',
                 subject: "SUCCESS: Jenkins Build ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The Jenkins build was successful. Check the build details here: ${env.BUILD_URL}"
        }

        // Send email on unstable completion (e.g., tests failed)
        unstable {
            mail to: 'awais.akram11199@gmail.com', // Add QA/Test Automation Engineer Email
                 subject: "UNSTABLE: Jenkins Build ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The Jenkins build is UNSTABLE (e.g., tests failed). Please review: ${env.BUILD_URL}"
        }

        // Send a different email on failure
        failure {
            mail to: 'awais.akram11199@gmail.com',
                 subject: "FAILURE: Jenkins Build ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                 body: "The Jenkins build FAILED! Please investigate immediately: ${env.BUILD_URL}"
        }
    }
    */
}
