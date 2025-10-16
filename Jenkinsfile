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
        
        stage('Unit Tests') {
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

        stage('Integration Tests') {
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
        

        
        stage("Infra: Approve"){
            steps{
                script {
                    echo 'Waiting for manual approval...'
                    
                    try {
                        // SElect the approval time as required
                        timeout(time: 30, unit: 'MINUTES') {
                            input message: 'Review the Terraform plan and approve to proceed', 
                                ok: 'Apply Infrastructure',
                                submitter: 'admin,devops-team' // Select the approvers as required
                        }
                        echo '✓ Deployment approved'
                    } catch (Exception e) {
                        echo '✗ Deployment not approved'
                        currentBuild.result = 'ABORTED'
                        error("Terraform: Approve: ${e.message}")
                    }
                }
            }
        }
        
        
        
        stage("Infra: Apply"){
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
        

        stage('Blue-Green Deploy') {
            when {
                expression { params.DEPLOY_TO_K8S == true }
            }
            
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            
            steps {
                script {
                    // Define environment-specific configurations
                    def envConfig = [
                        'dev': [
                            namespace: 'dev',
                            replicas: 1,
                            cpuRequest: '100m',
                            cpuLimit: '200m',
                            memoryRequest: '128Mi',
                            memoryLimit: '256Mi',
                            appName: 'devops-app-dev',
                            lbScheme: 'internal',
                            minReadySeconds: 5,
                            approvalRequired: false,
                            blueGreenEnabled: false  // Simple deployment for dev
                        ],
                        'staging': [
                            namespace: 'staging',
                            replicas: 1,
                            cpuRequest: '100m',
                            cpuLimit: '200m',
                            memoryRequest: '256Mi',
                            memoryLimit: '512Mi',
                            appName: 'devops-app-staging',
                            lbScheme: 'internet-facing',
                            minReadySeconds: 10,
                            approvalRequired: false,
                            blueGreenEnabled: true  // Enable Blue-Green for staging
                        ],
                        'prod': [
                            namespace: 'production',
                            replicas: 1,
                            cpuRequest: '100m',
                            cpuLimit: '200m',
                            memoryRequest: '256Mi',
                            memoryLimit: '256Mi',
                            appName: 'devops-app-prod',
                            lbScheme: 'internet-facing',
                            minReadySeconds: 30,
                            approvalRequired: true,
                            blueGreenEnabled: true  // Enable Blue-Green for production
                        ]
                    ]
                    
                    def config = envConfig[params.DEPLOY_ENV]
                    
                    // Set common environment variables
                    env.NAMESPACE = config.namespace
                    env.APP_NAME = config.appName
                    env.REPLICAS = config.replicas.toString()
                    env.CPU_REQUEST = config.cpuRequest
                    env.CPU_LIMIT = config.cpuLimit
                    env.MEMORY_REQUEST = config.memoryRequest
                    env.MEMORY_LIMIT = config.memoryLimit
                    env.LB_SCHEME = config.lbScheme
                    env.MIN_READY_SECONDS = config.minReadySeconds.toString()
                    
                    echo '==========================================='
                    echo "Deploying to ${params.DEPLOY_ENV.toUpperCase()} Environment"
                    echo "Strategy: ${config.blueGreenEnabled ? 'Blue-Green' : 'Rolling Update'}"
                    echo '==========================================='
                    
                    try {
                        // Production approval
                        if (config.approvalRequired) {
                            echo '⚠️  Production deployment requires approval'
                            timeout(time: 30, unit: 'MINUTES') {
                                input message: "Deploy to PRODUCTION?", 
                                      ok: 'Deploy',
                                      submitter: 'admin,devops-leads'
                            }
                            echo '✓ Deployment approved'
                        }

                        // Ensure IMAGE_NAME is set before any kubectl/envsubst usage
                        if (!env.IMAGE_NAME || env.IMAGE_NAME.trim() == '') {
                            def pomVersion = sh(
                                script: "grep -m1 '<version>' pom.xml | sed -E 's/.*<version>([^<]+)<\\/version>.*/\\1/'",
                                returnStdout: true
                            ).trim()
                            env.IMAGE_NAME = "${pomVersion}-${BUILD_NUMBER}"
                            echo "IMAGE_NAME resolved to ${env.IMAGE_NAME}"
                        }

                        // Verify image tag exists on Docker Hub before proceeding
                        def tagCode = sh(
                            script: "curl -s -o /dev/null -w '%{http_code}' https://hub.docker.com/v2/repositories/${DOCKER_REGISTRY}/tags/${env.IMAGE_NAME}/",
                            returnStdout: true
                        ).trim()
                        if (tagCode != '200') {
                            error("Image tag not found on Docker Hub: ${env.IMAGE_NAME}. Run 'Docker: Build Image' first.")
                        }

                        // Configure kubectl
                        if (!env.EKS_CLUSTER_NAME || env.EKS_CLUSTER_NAME == 'N/A') {
                            error('EKS cluster name not available.')
                        }
                        
                        sh """
                            aws eks update-kubeconfig \
                                --name ${env.EKS_CLUSTER_NAME} \
                                --region ${AWS_REGION}
                        """

                        // Ensure AWS Load Balancer Controller webhook is ready
                        sh """
                            kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=5m || true
                            kubectl -n kube-system get svc aws-load-balancer-webhook-service || true
                            kubectl -n kube-system get endpoints aws-load-balancer-webhook-service || true
                        """
                        def albReady = sh(
                            script: "kubectl -n kube-system get endpoints aws-load-balancer-webhook-service -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || true",
                            returnStdout: true
                        ).trim()
                        
                        // Setup namespace and secrets
                        sh """
                            kubectl get namespace ${env.NAMESPACE} 2>/dev/null || \
                            kubectl create namespace ${env.NAMESPACE}
                            
                            kubectl label namespace ${env.NAMESPACE} \
                                environment=${params.DEPLOY_ENV} \
                                managed-by=jenkins \
                                --overwrite
                        """
                        // Creates or updates a Kubernetes Docker registry secret using Jenkins credentials 
                        // so the cluster can pull private images from Docker Hub securely.
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                            sh """
                                kubectl create secret docker-registry my-registry-key \
                                    --docker-server=https://index.docker.io/v1/ \
                                    --docker-username=\${DOCKER_USER} \
                                    --docker-password=\${DOCKER_PASS} \
                                    --namespace=${env.NAMESPACE} \
                                    --dry-run=client -o yaml | kubectl apply -f -
                            """
                        }
                        
                        // Blue-Green Deployment Logic
                        if (config.blueGreenEnabled) {
                            echo '========================================='
                            echo 'Executing Blue-Green Deployment'
                            echo '========================================='
                            
                            // Determine current active slot
                            def currentSlot = sh(
                                script: """
                                    kubectl get service ${env.APP_NAME}-service \
                                        --namespace=${env.NAMESPACE} \
                                        -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo 'none'
                                """,
                                returnStdout: true
                            ).trim()
                            
                            echo "Current active slot: ${currentSlot}"
                            
                            // Determine target slot (opposite of current)
                            def targetSlot = 'blue'
                            if (currentSlot == 'none' || currentSlot == '') {
                                targetSlot = 'blue'
                                currentSlot = 'none'
                            } else if (currentSlot == 'blue') {
                                targetSlot = 'green'
                            } else if (currentSlot == 'green') {
                                targetSlot = 'blue'
                            }
                            
                            env.TARGET_SLOT = targetSlot
                            env.CURRENT_SLOT = currentSlot
                            
                            echo "Deploying to: ${targetSlot} slot"
                            echo "Current production: ${currentSlot}"
                            
                            // Process and apply manifests for target slot
                            dir('kubernetes') {
                                sh """
                                    export APP_NAME="${env.APP_NAME}"
                                    export IMAGE_NAME="${env.IMAGE_NAME}"
                                    export NAMESPACE="${env.NAMESPACE}"
                                    export REPLICAS="${env.REPLICAS}"
                                    export CPU_REQUEST="${env.CPU_REQUEST}"
                                    export CPU_LIMIT="${env.CPU_LIMIT}"
                                    export MEMORY_REQUEST="${env.MEMORY_REQUEST}"
                                    export MEMORY_LIMIT="${env.MEMORY_LIMIT}"
                                    export LB_SCHEME="${env.LB_SCHEME}"
                                    export MIN_READY_SECONDS="${env.MIN_READY_SECONDS}"
                                    export DEPLOY_ENV="${params.DEPLOY_ENV}"
                                    export SLOT="${targetSlot}"
                                    export ACTIVE_SLOT="${currentSlot}"
                                    
                                    mkdir -p processed
                                    
                                    # Process Blue-Green deployment manifest
                                    if [ -f "deployment-bluegreen.yaml" ]; then
                                        envsubst < deployment-bluegreen.yaml > processed/deployment-${targetSlot}.yaml
                                    else
                                        echo "Warning: deployment-bluegreen.yaml not found, using standard deployment"
                                        envsubst < deployment.yaml > processed/deployment-${targetSlot}.yaml
                                    fi
                                    
                                    # Process preview service
                                    if [ -f "service-preview.yaml" ]; then
                                        envsubst < service-preview.yaml > processed/service-preview-${targetSlot}.yaml
                                    fi
                                    
                                    # Process main service (only if it doesn't exist)
                                    if [ -f "service-bluegreen.yaml" ]; then
                                        envsubst < service-bluegreen.yaml > processed/service-main.yaml
                                    else
                                        envsubst < service.yaml > processed/service-main.yaml
                                    fi
                                """
                                
                                // Deploy to target slot
                                echo "Deploying ${targetSlot} slot..."
                                sh "kubectl apply -f processed/deployment-${targetSlot}.yaml --namespace=${env.NAMESPACE}"
                                
                                // Create preview service for testing (only if ALB webhook is ready)
                                if (albReady) {
                                    sh """
                                        if [ -f processed/service-preview-${targetSlot}.yaml ]; then
                                            kubectl apply -f processed/service-preview-${targetSlot}.yaml --namespace=${env.NAMESPACE}
                                        fi
                                    """
                                } else {
                                    echo 'ALB webhook not ready; skipping preview service for now'
                                }
                                
                                // Ensure main service exists (with current slot or default to target)
                                def initialSlot = currentSlot == 'none' ? targetSlot : currentSlot
                                if (albReady) {
                                    sh """
                                        export ACTIVE_SLOT="${initialSlot}"
                                        envsubst < processed/service-main.yaml | kubectl apply -f - --namespace=${env.NAMESPACE}
                                    """
                                } else {
                                    echo 'ALB webhook not ready; skipping Service creation'
                                    currentBuild.result = 'UNSTABLE'
                                    return
                                }
                            }
                            
                            // Wait for target slot to be ready
                            echo "Waiting for ${targetSlot} deployment to be ready..."
                            sh """
                                kubectl rollout status deployment/${env.APP_NAME}-${targetSlot} \
                                    --namespace=${env.NAMESPACE} \
                                    --timeout=2m
                            """
                            
                            // Verify pods are healthy
                            echo "Verifying ${targetSlot} pods health..."
                            sh """
                                kubectl wait --for=condition=ready pod \
                                    -l app=${env.APP_NAME},slot=${targetSlot} \
                                    --namespace=${env.NAMESPACE} \
                                    --timeout=2m
                            """
                            
                            // Run smoke tests on target slot
                            echo "Running smoke tests on ${targetSlot} slot..."
                            def smokeTestPassed = true
                            try {
                                // Get a pod from target slot for testing
                                def testPod = sh(
                                    script: """
                                        kubectl get pod -l app=${env.APP_NAME},slot=${targetSlot} \
                                            --namespace=${env.NAMESPACE} \
                                            -o jsonpath='{.items[0].metadata.name}'
                                    """,
                                    returnStdout: true
                                ).trim()
                                
                                echo "Testing pod: ${testPod}"
                                
                                // Port-forward and test (or use preview service)
                                sh """
                                    # Test health endpoints
                                    kubectl exec ${testPod} --namespace=${env.NAMESPACE} -- \
                                        wget -O- -q http://localhost:8090/actuator/health/readiness || exit 1
                                    
                                    kubectl exec ${testPod} --namespace=${env.NAMESPACE} -- \
                                        wget -O- -q http://localhost:8090/actuator/health/liveness || exit 1
                                    
                                    echo "✓ Health checks passed"
                                """
                                
                            } catch (Exception e) {
                                echo "✗ Smoke tests failed: ${e.message}"
                                smokeTestPassed = false
                            }
                            
                            if (!smokeTestPassed) {
                                echo "Smoke tests failed. Rolling back..."
                                sh "kubectl delete deployment ${env.APP_NAME}-${targetSlot} --namespace=${env.NAMESPACE} || true"
                                error("Deployment failed smoke tests")
                            }
                            
                            // Traffic Switch Approval
                            echo '========================================='
                            echo "Ready to switch traffic from ${currentSlot} to ${targetSlot}"
                            echo '========================================='

                            // Waits up to mention duration for manual approval from authorized users 
                            // before switching traffic to the target deployment.
                            timeout(time: 3, unit: 'MINUTES') { //select the some tests duration accordingly
                                input message: """
                                    Switch traffic to ${targetSlot}?
                                    
                                    Current: ${currentSlot}
                                    Target: ${targetSlot}
                                    Version: ${env.IMAGE_NAME}
                                """,
                                ok: 'Switch Traffic',
                                submitter: 'admin,devops-leads' //select the approvers as required
                            }
                            
                            // Switch traffic to target slot
                            echo "Switching traffic to ${targetSlot}..."
                            sh """
                                kubectl patch service ${env.APP_NAME}-service \
                                    --namespace=${env.NAMESPACE} \
                                    -p '{"spec":{"selector":{"slot":"${targetSlot}"}}}'
                            """
                            
                            echo "✓ Traffic switched to ${targetSlot}"
                            
                            // Wait and monitor
                            echo "Monitoring new deployment for 30 seconds..."
                            sleep 30
                            
                            // Check if new slot is stable
                            sh """
                                kubectl get pods -l app=${env.APP_NAME},slot=${targetSlot} \
                                    --namespace=${env.NAMESPACE}
                            """
                            
                            // Cleanup old slot after successful switch
                            if (currentSlot != 'none' && currentSlot != '') {
                                echo "Cleaning up old ${currentSlot} deployment..."
                                timeout(time: 30, unit: 'MINUTES') { //select the some tests duration accordingly
                                    def cleanup = input(
                                        message: "Remove old ${currentSlot} deployment?",
                                        ok: 'Yes, remove it',
                                        parameters: [
                                            booleanParam(
                                                name: 'CLEANUP_OLD',
                                                defaultValue: true,
                                                description: 'Remove old deployment'
                                            )
                                        ]
                                    )
                                    
                                    if (cleanup) {
                                        sh """
                                            kubectl delete deployment ${env.APP_NAME}-${currentSlot} \
                                                --namespace=${env.NAMESPACE} || true
                                        """
                                        echo "✓ Old ${currentSlot} deployment removed"
                                    } else {
                                        echo "I'm Keeping ${currentSlot} deployment for manual cleanup"
                                    }
                                }
                            }
                            
                            env.ACTIVE_SLOT = targetSlot
                            
                        } else {
                            // Standard rolling update deployment for dev
                            echo 'Executing standard rolling update deployment...'
                            
                            dir('kubernetes') {
                                sh """
                                    export APP_NAME="${env.APP_NAME}"
                                    export IMAGE_NAME="${env.IMAGE_NAME}"
                                    export NAMESPACE="${env.NAMESPACE}"
                                    export REPLICAS="${env.REPLICAS}"
                                    export CPU_REQUEST="${env.CPU_REQUEST}"
                                    export CPU_LIMIT="${env.CPU_LIMIT}"
                                    export MEMORY_REQUEST="${env.MEMORY_REQUEST}"
                                    export MEMORY_LIMIT="${env.MEMORY_LIMIT}"
                                    export LB_SCHEME="${env.LB_SCHEME}"
                                    export MIN_READY_SECONDS="${env.MIN_READY_SECONDS}"
                                    export DEPLOY_ENV="${params.DEPLOY_ENV}"
                                    
                                    mkdir -p processed
                                    
                                    for file in storageclass.yaml deployment.yaml service.yaml; do
                                        if [ -f "\$file" ]; then
                                            envsubst < \$file > processed/\$file
                                        fi
                                    done
                                """
                                
                                sh """
                                    kubectl apply -f processed/storageclass.yaml --namespace=${env.NAMESPACE} || true
                                    kubectl apply -f processed/deployment.yaml --namespace=${env.NAMESPACE}
                                    kubectl apply -f processed/service.yaml --namespace=${env.NAMESPACE}
                                """
                            }
                            
                            sh """
                                kubectl rollout status deployment/${env.APP_NAME} \
                                    --namespace=${env.NAMESPACE} \
                                    --timeout=2m
                            """
                        }
                        
                        // Get service endpoint
                        def serviceEndpoint = sh(
                            script: """
                                kubectl get service ${env.APP_NAME}-service \
                                    --namespace=${env.NAMESPACE} \
                                    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending..."
                            """,
                            returnStdout: true
                        ).trim()
                        
                        env.SERVICE_ENDPOINT = serviceEndpoint
                        
                        // Deployment Summary
                        echo '==========================================='
                        echo "✓ Deployed to ${params.DEPLOY_ENV.toUpperCase()} Successfully!"
                        echo '==========================================='
                        echo "Strategy: ${config.blueGreenEnabled ? 'Blue-Green' : 'Rolling Update'}"
                        echo "Environment: ${params.DEPLOY_ENV}"
                        echo "Namespace: ${env.NAMESPACE}"
                        echo "Image: ${DOCKER_REGISTRY}:${env.IMAGE_NAME}"
                        if (config.blueGreenEnabled) {
                            echo "Active Slot: ${env.ACTIVE_SLOT}"
                        }
                        echo "Service Endpoint: ${serviceEndpoint}"
                        echo '==========================================='
                        
                        // Save deployment info
                        sh """
                            mkdir -p deployment-reports
                            cat > deployment-reports/${params.DEPLOY_ENV}-deployment.txt << EOF
Deployment Summary
==================
Environment: ${params.DEPLOY_ENV}
Strategy: ${config.blueGreenEnabled ? 'Blue-Green' : 'Rolling Update'}
Namespace: ${env.NAMESPACE}
Build: ${BUILD_NUMBER}
Image: ${DOCKER_REGISTRY}:${env.IMAGE_NAME}"
${config.blueGreenEnabled ? "Active Slot: ${env.ACTIVE_SLOT}" : ""}
Service: ${env.SERVICE_ENDPOINT}
Deployed: \$(date)
EOF
                        """
                        
                        archiveArtifacts artifacts: "deployment-reports/${params.DEPLOY_ENV}-deployment.txt",
                                    allowEmptyArchive: true
                        
                    } catch (Exception e) {
                        echo "✗ Deployment failed: ${e.message}"
                        sh """
                            kubectl get pods --namespace=${env.NAMESPACE} || true
                            kubectl get events --namespace=${env.NAMESPACE} --sort-by='.lastTimestamp' || true
                        """
                        currentBuild.result = 'FAILURE'
                        error("Deployment failed: ${e.message}")
                    }
                }
            }
            
            post {
                cleanup {
                    sh 'rm -rf kubernetes/processed 2>/dev/null || true'
                }
            }
        }

        stage('Rollback') {
            when {
                expression {
                    return currentBuild.result == 'FAILURE' || 
                           params.DEPLOY_ENV in ['staging', 'prod']
                }
            }
            
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
            }
            
            steps {
                script {
                    def envConfig = [
                        'staging': [namespace: 'staging', appName: 'devops-app-staging'],
                        'prod': [namespace: 'production', appName: 'devops-app-prod']
                    ]
                    
                    if (!envConfig.containsKey(params.DEPLOY_ENV)) {
                        echo "Rollback not applicable for ${params.DEPLOY_ENV}"
                        return
                    }
                    
                    def config = envConfig[params.DEPLOY_ENV]
                    
                    echo '========================================='
                    echo 'Rollback Available'
                    echo '========================================='
                    
                    try {
                        // Check if both slots exist
                        def blueExists = sh(
                            script: "kubectl get deployment ${config.appName}-blue --namespace=${config.namespace} 2>/dev/null",
                            returnStatus: true
                        ) == 0
                        
                        def greenExists = sh(
                            script: "kubectl get deployment ${config.appName}-green --namespace=${config.namespace} 2>/dev/null",
                            returnStatus: true
                        ) == 0
                        
                        if (!blueExists && !greenExists) {
                            echo "No blue-green deployments found. Rollback not possible."
                            return
                        }
                        
                        def currentSlot = sh(
                            script: """
                                kubectl get service ${config.appName}-service \
                                    --namespace=${config.namespace} \
                                    -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo 'unknown'
                            """,
                            returnStdout: true
                        ).trim()
                        
                        def previousSlot = currentSlot == 'blue' ? 'green' : 'blue'
                        
                        echo "Current slot: ${currentSlot}"
                        echo "Previous slot: ${previousSlot}"
                        
                        // Check if previous slot is available
                        def previousSlotExists = sh(
                            script: "kubectl get deployment ${config.appName}-${previousSlot} --namespace=${config.namespace} 2>/dev/null",
                            returnStatus: true
                        ) == 0
                        
                        if (!previousSlotExists) {
                            echo "Previous deployment (${previousSlot}) not found. Cannot rollback."
                            return
                        }
                        
                        timeout(time: 5, unit: 'MINUTES') {
                            input message: """
                                Rollback to ${previousSlot}?
                                
                                This will switch traffic from ${currentSlot} back to ${previousSlot}
                            """,
                            ok: 'Rollback Now',
                            submitter: 'admin,devops-leads'
                        }
                        
                        echo "Rolling back to ${previousSlot}..."
                        sh """
                            kubectl patch service ${config.appName}-service \
                                --namespace=${config.namespace} \
                                -p '{"spec":{"selector":{"slot":"${previousSlot}"}}}'
                        """
                        
                        echo "✓ Rolled back to ${previousSlot}"
                        
                        // Verify rollback
                        sh """
                            kubectl get pods -l app=${config.appName},slot=${previousSlot} \
                                --namespace=${config.namespace}
                        """
                        
                    } catch (Exception e) {
                        echo "Rollback cancelled or failed: ${e.message}"
                    }
                }
            }
        }
        
        /*
        stage('Ansible: Configure Swap') {
            when {
                expression { 
                    return params.DEPLOY_ENV in ['staging', 'prod'] 
                }
            }
            
            environment {
                AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
                AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_secret_access_key')
                AWS_REGION = 'ap-northeast-2'
            }
            
            steps {
                script {
                    echo '==========================================='
                    echo 'Configuring EKS Worker Nodes with Ansible'
                    echo '==========================================='
                    
                    try {
                        // Ensure cluster name is available
                        if (!env.EKS_CLUSTER_NAME || env.EKS_CLUSTER_NAME == 'N/A') {
                            echo "⚠️  EKS cluster name not available, skipping Ansible configuration"
                            return
                        }
                        
                        dir('ansible') {
                            // Install Ansible if not already installed
                            echo 'Checking Ansible installation...'
                            sh '''
                                if ! command -v ansible &> /dev/null; then
                                    echo "Installing Ansible..."
                                    python3 -m pip install --user ansible boto3 botocore
                                else
                                    echo "Ansible already installed: $(ansible --version | head -1)"
                                fi
                            '''
                            
                            // Setup AWS credentials for Ansible
                            sh '''
                                mkdir -p ~/.aws
                                cat > ~/.aws/config << EOF
[default]
region = ${AWS_REGION}
output = json
EOF
                                
                                cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
                                chmod 600 ~/.aws/credentials
                            '''
                            
                            // Generate dynamic inventory from EKS cluster
                            echo 'Generating Ansible inventory from EKS cluster...'
                            sh '''
                                # Make script executable
                                chmod +x scripts/generate-inventory.sh
                                
                                # Generate inventory
                                bash scripts/generate-inventory.sh ${EKS_CLUSTER_NAME} ${AWS_REGION}
                                
                                echo ""
                                echo "Generated inventory:"
                                cat inventory/eks-nodes.ini
                            '''
                            
                            // Alternative: Use AWS EC2 dynamic inventory plugin
                            echo 'Setting up AWS EC2 dynamic inventory...'
                            sh '''
                                # Create AWS EC2 inventory plugin configuration
                                cat > inventory/aws_ec2.yml << 'EOF'
plugin: amazon.aws.aws_ec2
regions:
  - ${AWS_REGION}
filters:
  tag:eks:cluster-name: ${EKS_CLUSTER_NAME}
  instance-state-name: running
keyed_groups:
  - key: tags['eks:nodegroup-name']
    prefix: nodegroup
  - key: placement.availability_zone
    prefix: az
hostnames:
  - private-ip-address
compose:
  ansible_user: "'ec2-user'"
  ansible_ssh_common_args: "'-o StrictHostKeyChecking=no'"
EOF
                            '''
                            
                            // Setup SSH access (using SSM Session Manager as proxy)
                            echo 'Configuring SSH access to nodes...'
                            sh '''
                                # Install AWS Session Manager plugin if needed
                                if ! command -v session-manager-plugin &> /dev/null; then
                                    echo "Installing Session Manager plugin..."
                                    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
                                        -o /tmp/session-manager-plugin.deb
                                    sudo dpkg -i /tmp/session-manager-plugin.deb || true
                                fi
                                
                                # Create SSH config for SSM
                                mkdir -p ~/.ssh
                                cat >> ~/.ssh/config << 'EOF'

# EKS Nodes via SSM
Host i-* mi-*
    ProxyCommand bash -c "aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters 'portNumber=%p'"
    User ec2-user
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
                                chmod 600 ~/.ssh/config
                            '''
                            
                            // Test connectivity
                            echo 'Testing connectivity to EKS nodes...'
                            sh '''
                                export ANSIBLE_HOST_KEY_CHECKING=False
                                
                                # Ping test using SSM
                                ansible all -i inventory/aws_ec2.yml -m ping --ssh-extra-args="-o StrictHostKeyChecking=no" || {
                                    echo "Warning: Could not reach all nodes, continuing anyway..."
                                }
                            '''
                            
                            // Run Ansible playbook to configure swap
                            echo 'Running Ansible playbook to configure swap memory...'
                            sh '''
                                export ANSIBLE_HOST_KEY_CHECKING=False
                                
                                ansible-playbook playbooks/configure-swap.yml \
                                    -i inventory/aws_ec2.yml \
                                    --extra-vars "swap_size_mb=1024" \
                                    -v
                            '''
                            
                            // Verify swap configuration
                            echo 'Verifying swap configuration...'
                            sh '''
                                ansible all -i inventory/aws_ec2.yml \
                                    -m shell \
                                    -a "free -h && swapon --show" \
                                    -b
                            '''
                            
                            // Collect configuration reports
                            echo 'Collecting configuration reports...'
                            sh '''
                                mkdir -p ../ansible-reports
                                
                                # Get node details
                                aws ec2 describe-instances \
                                    --region ${AWS_REGION} \
                                    --filters "Name=tag:eks:cluster-name,Values=${EKS_CLUSTER_NAME}" \
                                    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,State.Name]' \
                                    --output table > ../ansible-reports/eks-nodes.txt
                                
                                # Get swap status from all nodes
                                ansible all -i inventory/aws_ec2.yml \
                                    -m shell \
                                    -a "free -h" \
                                    -b > ../ansible-reports/swap-status.txt || true
                                
                                echo "Ansible configuration completed at $(date)" >> ../ansible-reports/summary.txt
                            '''
                        }
                        
                        // Archive reports
                        archiveArtifacts artifacts: 'ansible-reports/*.txt', 
                                    allowEmptyArchive: true
                        
                        echo '==========================================='
                        echo '✓ Swap Memory Configuration Completed'
                        echo '==========================================='
                        
                    } catch (Exception e) {
                        echo "✗ Ansible configuration failed: ${e.message}"
                        echo "This is not critical, continuing with deployment..."
                        // Don't fail the build, just warn
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
            
            post {
                cleanup {
                    sh '''
                        rm -f ~/.aws/credentials 2>/dev/null || true
                        rm -rf ansible/inventory/eks-nodes.ini 2>/dev/null || true
                    '''
                }
            }
        }
        
*/

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