pipeline {

    agent any

    tools {
        maven 'Maven3'      // Name must match Manage Jenkins > Tools > Maven installation
        jdk 'JDK11'         // Name must match Manage Jenkins > Tools > JDK installation
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')   // Jenkins credential ID
        DOCKER_IMAGE          = "yourdockerhubusername/demo-cicd-app"
        NEXUS_URL             = "http://NEXUS_SERVER_IP:8081"
        SONARQUBE_ENV         = "MySonarQubeServer"               // Name from Manage Jenkins > System
        DEPLOY_SERVER         = "ubuntu@DEPLOY_SERVER_IP"          // EC2 user@ip to deploy the container to
    }

    stages {

        stage('1. Checkout Code') {
            steps {
                echo 'Pulling latest code from GitHub...'
                git branch: 'main',
                    url: 'https://github.com/YOUR_USERNAME/cicd-pipeline-project.git',
                    credentialsId: 'github-creds'
            }
        }

        stage('2. Build with Maven') {
            steps {
                echo 'Compiling and packaging the application...'
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('3. Run Unit Tests') {
            steps {
                echo 'Running JUnit tests...'
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('4. Code Quality Analysis - SonarQube') {
            steps {
                echo 'Running SonarQube static analysis...'
                withSonarQubeEnv("${SONARQUBE_ENV}") {
                    sh '''
                        mvn sonar:sonar \
                          -Dsonar.projectKey=demo-cicd-app \
                          -Dsonar.projectName=demo-cicd-app
                    '''
                }
            }
        }

        stage('5. Quality Gate') {
            steps {
                echo 'Waiting for SonarQube Quality Gate result...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('6. Upload Artifact to Nexus') {
            steps {
                echo 'Publishing build artifact to Nexus repository...'
                sh 'mvn deploy -DskipTests'
            }
        }

        stage('7. Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                sh "docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('8. Push Docker Image') {
            steps {
                echo 'Pushing image to Docker Hub...'
                sh "echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin"
                sh "docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}"
                sh "docker push ${DOCKER_IMAGE}:latest"
            }
        }

        stage('9. Deploy to EC2') {
            steps {
                echo 'Deploying container to the target EC2 instance...'
                sshagent(credentials: ['ec2-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${DEPLOY_SERVER} '
                            docker pull ${DOCKER_IMAGE}:latest &&
                            docker stop demo-cicd-app || true &&
                            docker rm demo-cicd-app || true &&
                            docker run -d --name demo-cicd-app -p 8080:8080 ${DOCKER_IMAGE}:latest
                        '
                    """
                }
            }
        }
    }

    post {
        success {
            emailext(
                subject: "SUCCESS: Build #${BUILD_NUMBER} - ${JOB_NAME}",
                body: "Good news! The pipeline for ${JOB_NAME} build #${BUILD_NUMBER} completed successfully.\n\nCheck console: ${BUILD_URL}",
                to: 'you@example.com'
            )
        }
        failure {
            emailext(
                subject: "FAILED: Build #${BUILD_NUMBER} - ${JOB_NAME}",
                body: "The pipeline for ${JOB_NAME} build #${BUILD_NUMBER} failed.\n\nCheck console: ${BUILD_URL}",
                to: 'you@example.com'
            )
        }
        always {
            cleanWs()
        }
    }
}
