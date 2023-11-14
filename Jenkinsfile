def COLOR_MAP = [
    'SUCCESS': 'good', 
    'FAILURE': 'danger',
]

pipeline {
    agent any

    options {
        timeout(time: 40, unit: 'MINUTES')
        /*parallelsAlwaysFailFast()*/
    }

    tools{
        jdk 'jdk17'
    }

    environment {
        SONAR_SCANNER_HOME = tool 'sonar_scanner'
        DOCKER_REGISTRY = "yemisiomonijo/vprofileapp"
        DOCKER_REG_CRED = 'docker_reg_cred'
    }

    stages {

        // stage('Git Checkout'){
        //     steps{
        //         git branch: 'develop', url: 'https://github.com/yemisprojects/eks-app.git'
        //     }
        // }

        stage('BUILD'){
            steps {
                sh 'mvn clean install -DskipTests'
            }
            post {
                success {
                    echo 'Now Archiving...'
                    archiveArtifacts artifacts: '**/target/*.war'
                }
            }
        }  

        stage('UNIT TEST'){
            steps {
                sh 'mvn test'
            }
        }

        stage('INTEGRATION TEST'){
            steps {
                sh 'mvn verify -DskipUnitTests'
            }
        }

        stage ('CODE ANALYSIS WITH CHECKSTYLE'){
            steps {
                sh 'mvn checkstyle:checkstyle'
            }
            post {
                success {
                    echo 'Generated Analysis Result'
                }
            }
        }

        stage('CODE ANALYSIS with SONARQUBE') {
            steps {
                withSonarQubeEnv('sonarqube_server') {
                    sh '''${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=vprofile-app \
                   -Dsonar.projectName=vprofile-app \
                   -Dsonar.projectVersion=1.0 \
                   -Dsonar.sources=src/ \
                   -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/ \
                   -Dsonar.junit.reportsPath=target/surefire-reports/ \
                   -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                   -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
                }

                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('FileSystem scan') {
            steps {
                sh "trivy fs . | tee filesystem_scan.txt"
                //https://aws.amazon.com/blogs/security/how-to-build-ci-cd-pipeline-container-vulnerability-scanning-trivy-and-aws-security-hub/
            }
        }

        stage("Docker Build & Push"){
            steps{
                    script{
                            withDockerRegistry(credentialsId: 'docker_cred', toolName: 'docker'){   
                                sh "docker build -t $DOCKER_REGISTRY:latest ."
                                sh "docker tag $DOCKER_REGISTRY:latest ${DOCKER_REGISTRY}:V${BUILD_NUMBER}"
                                sh "docker push $DOCKER_REGISTRY:latest && docker push ${DOCKER_REGISTRY}:V${BUILD_NUMBER}"
                            }
                    } 
            }
        }

        stage("Image Scan"){
            steps{
                sh "trivy image $DOCKER_REGISTRY:latest | tee image_scan.txt"  
            }
        }

        stage('Cleanup Unused docker image') {
          steps{
            sh "docker rmi $registry:$BUILD_NUMBER"
          }
        }

        stage('Update K8s manifest') {
            steps {

                    script {
                            withCredentials([usernamePassword(credentialsId: 'github_token', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
                            sh "git config user.email jenkins@gmail.com"
                            sh "git config user.name jenkins"
                            sh "cat vprofile-app-deployment.yml"
                            sh "sed -i 's|image: ${DOCKER_REGISTRY}:.*|image: ${DOCKER_REGISTRY}:V${BUILD_NUMBER}|g' vprofile-app-deployment.yml"
                            sh "cat vprofile-app-deployment.yml"
                            sh "git vprofile-app-deployment.yml"
                            sh "git commit -m 'Manifest change done by Jenkins Build: ${env.BUILD_NUMBER}'"
                            sh "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GIT_USERNAME}/kubernetes-manifests.git HEAD:main"
                        }
                    }
                
            }
        }


    }

    post {

        always {
            echo 'Slack Notifications'
            slackSend channel: '#k8s-jenkins-cicd',
                color: COLOR_MAP[currentBuild.currentResult],
                message: "*${currentBuild.currentResult}:* Job ${env.JOB_NAME} build ${env.BUILD_NUMBER} \n More info at: ${env.BUILD_URL}"
            
            emailext attachLog: true,
                subject: "'${currentBuild.result}'",
                body: "Project: ${env.JOB_NAME}<br/>" +
                        "Build Number: ${env.BUILD_NUMBER}<br/>" +
                        "URL: ${env.BUILD_URL}<br/>",
                to: 'yemisiomonijo20@yahoo.com',
                attachmentsPattern: 'filesystem_scan.txt,image_scan.txt'

            cleanWs(    
                    cleanWhenNotBuilt: false,
                    cleanWhenAborted: true, cleanWhenFailure: true, cleanWhenSuccess: true, cleanWhenUnstable: true,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true
            )
        }

    }

    
}
