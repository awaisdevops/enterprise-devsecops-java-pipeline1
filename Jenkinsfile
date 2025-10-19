pipeline {
    agent any

    tools {
        maven 'maven'
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
        
        stage('App Version Bump') {
            // tags: maven,version,parse-version,set-version,image-tag
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
        
        stage("Terraform: Plan"){
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
                            sh 'aws sts get-caller-identity'
                            sh 'terraform init -upgrade'
                            sh 'terraform validate'
                            sh 'terraform plan -out=tfplan -input=false'
                            
                            archiveArtifacts artifacts: 'tfplan', allowEmptyArchive: false
                            
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

        stage("Infra: Approve"){
            steps{
                script {
                    echo 'Waiting for manual approval to apply infrastructure changes...'
                    timeout(time: 30, unit: 'MINUTES') {
                        input message: 'Review the Terraform plan. Approve to proceed with applying changes.', 
                              ok: 'Apply Infrastructure'
                    }
                    echo '✓ Deployment approved'
                }
            }
        }

        stage("Infra: Apply & Kubeconfig"){
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
                        try {
                            sh 'aws sts get-caller-identity'
                            sh 'terraform apply -auto-approve -input=false tfplan'
                            
                            def clusterName = sh(
                                script: 'terraform output -raw cluster_name', 
                                returnStdout: true
                            ).trim()
                            
                            env.EKS_CLUSTER_NAME = clusterName
                            
                            echo 'Configuring kubectl for EKS cluster...'
                            sh """
                                aws eks update-kubeconfig --name ${clusterName} --region ${AWS_REGION}
                                kubectl cluster-info
                            """
                            
                            echo '✓ Infrastructure Provisioned Successfully!'
                            
                        } catch (Exception e) {
                            echo "✗ Terraform apply failed: ${e.message}"
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
        
        stage('Ansible: EC2 Swap Config') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps {
                script {
                    echo '==========================================='
                    echo 'Configuring EC2 Instance with Ansible'
                    echo '==========================================='
                    
                    def ec2_public_ip
                    dir('infra') {
                        // Get the public IP of the EC2 instance from Terraform output
                        ec2_public_ip = sh(
                            script: 'terraform output -raw ec2_public_ip',
                            returnStdout: true
                        ).trim()
                    }

                    if (ec2_public_ip) {
                        // Ensure the inventory directory exists before writing to it
                        sh "mkdir -p ansible/inventory"
                        
                        // Dynamically create the Ansible inventory file from the workspace root
                        sh "echo '[ec2-instance]' > ansible/inventory/hosts"
                        sh "echo '${ec2_public_ip}' >> ansible/inventory/hosts"

                        echo "Ansible Inventory created for host: ${ec2_public_ip}"
                        
                        // Use the ssh-agent plugin to provide the SSH key to Ansible
                        sshagent(credentials: ['ec2-ssh-key']) {
                            // Change to the ansible directory to run the playbook.
                            // This allows Ansible to automatically find ansible.cfg and the inventory.
                            dir('ansible') {
                                sh 'ansible-playbook playbooks/configure-swap.yml'
                            }
                        }
                        
                        echo '✓ Ansible playbook executed successfully!'
                    } else {
                        echo 'Warning: EC2 public IP not found. Skipping Ansible configuration.'
                    }
                }
            }
            post {
                cleanup {
                    // Clean up the dynamic inventory file
                    sh 'rm -f ansible/inventory/hosts'
                }
            }
        }

        stage('Blue-Green Deploy') {
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            steps {
                script {
                    echo '==========================================='
                    echo 'Starting Blue-Green Deployment'
                    echo '==========================================='

                    // --- 1. Determine Target and Current Slots ---
                    // Check which slot is currently active by inspecting the main service's selector.
                    def currentSlot = sh(
                        script: "kubectl get service my-app -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo 'none'",
                        returnStdout: true
                    ).trim()

                    def targetSlot = (currentSlot == 'blue') ? 'green' : 'blue'
                    echo "Current active slot: ${currentSlot}"
                    echo "Deploying to new slot: ${targetSlot}"

                    // --- 2. Deploy New Version to Target Slot ---
                    // Create the docker registry secret for pulling the image
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                        sh """
                            kubectl create secret docker-registry my-registry-key \\
                                --docker-server=https://index.docker.io/v1/ \\
                                --docker-username=\${DOCKER_USER} \\
                                --docker-password=\${DOCKER_PASS} \\
                                --dry-run=client -o yaml | kubectl apply -f -
                        """
                    }

                    // Substitute variables and deploy the blue-green manifests
                    sh '''
                    export APP_NAME="my-app"
                    export IMAGE_NAME="${env.IMAGE_NAME}"
                    export SLOT="''' + targetSlot + '''"
                    export ACTIVE_SLOT="''' + currentSlot + '''"

                    # If no service exists yet, have it point to the target slot initially
                    if [ "$ACTIVE_SLOT" == "none" ]; then
                        export ACTIVE_SLOT="''' + targetSlot + '''"
                    fi

                    echo "Applying manifests for '$SLOT' slot..."
                    envsubst < kubernetes/deployment-bluegreen.yaml | kubectl apply -f -
                    envsubst < kubernetes/service-preview.yaml | kubectl apply -f -
                    envsubst < kubernetes/service-main.yaml | kubectl apply -f -
                    '''

                    // --- 3. Wait for New Deployment to be Ready ---
                    echo "Waiting for ${targetSlot} deployment to be ready..."
                    sh "kubectl rollout status deployment/my-app-${targetSlot} --timeout=5m"
                    echo "✓ ${targetSlot} deployment is ready."

                    // (Optional) This is where you would run automated tests against the preview service
                    // e.g., kubectl exec <test-pod> -- curl http://my-app-preview-green:8090/actuator/health

                    // --- 4. Manual Approval for Traffic Switch ---
                    if (currentSlot != 'none') {
                        timeout(time: 30, unit: 'MINUTES') {
                            input message: "Ready to switch live traffic from '${currentSlot}' to '${targetSlot}'. Approve?",
                                  ok: "Switch Traffic to ${targetSlot}"
                        }

                        // --- 5. Switch Live Traffic ---
                        echo "Switching live traffic to ${targetSlot}..."
                        sh "kubectl patch service my-app -p '{\\\"spec\\\":{\\\"selector\\\":{\\\"slot\\\":\\\"${targetSlot}\\\"}}}'"
                        echo "✓ Traffic is now routed to the ${targetSlot} deployment."

                        // --- 6. (Optional) Cleanup Old Deployment ---
                        timeout(time: 15, unit: 'MINUTES') {
                            input message: "Traffic switch is complete. Clean up the old '${currentSlot}' deployment?",
                                  ok: "Yes, Remove Old Deployment"
                        }
                        sh "kubectl delete deployment my-app-${currentSlot}"
                        sh "kubectl delete service my-app-preview-${currentSlot}"
                        echo "✓ Old ${currentSlot} deployment and preview service have been removed."
                    }
                    
                    echo '==========================================='
                    echo '✓ Blue-Green Deployment Successful!'
                    echo "Active Slot: ${targetSlot}"
                    echo '==========================================='
                }
            }
        }
                           
            
        stage('Commit App Version') {
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
    
}