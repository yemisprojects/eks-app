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
        nodejs 'nodejs16'
    }

    environment {
        SONAR_SCANNER_HOME = tool 'sonar_scanner'
        DOCKER_REGISTRY = "yemisiomonijo/demoapp"
        DOCKER_REG_CRED = 'docker_reg_cred'
        TMDB_API_KEY = credentials('tmdb_api_key')
    }

    stages {

        stage('Git Checkout'){
            steps{
                git branch: 'develop', url: 'https://github.com/yemisprojects/eks-app.git'
            }
        }

        stage('Unit test'){
            steps{
                sh "npm install"
                sh "echo 'This is a placeholder for running tests'"
                // dir("${env.WORKSPACE}/demo_webapp"){
                //     sh "npm install"
                //     sh "echo 'This is a placeholder for running tests'"
                // }

            }
        }    

        stage("Sonarqube Analysis"){
            steps{
                    withSonarQubeEnv('sonarqube_server') {
                        sh '''ls -al && ${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectName=webapp -Dsonar.projectKey=webapp \
                        -Dsonar.projectCreation.mainBranchName=develop  \
                        '''
                    }
                // dir("${env.WORKSPACE}/demo_webapp"){
                //         withSonarQubeEnv('sonarqube_server') {
                //                 sh '''ls -al && ${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectName=webapp -Dsonar.projectKey=webapp \
                //                 -Dsonar.projectCreation.mainBranchName=deploy_app  \
                //                 '''
                //         }
                // }

            }
        }

        stage("Quality Gate"){
           steps {
                    timeout(time: 10, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true, credentialsId: 'sonar_token' 
                    }            
                // dir("${env.WORKSPACE}/demo_webapp"){
                //         timeout(time: 10, unit: 'MINUTES') {
                //             waitForQualityGate abortPipeline: true, credentialsId: 'sonar_token' 
                //         }
                // }
            } 
        }

        stage('Trivy FileSystem scan') {
            steps {
                sh "trivy fs . | tee filesystem_scan.txt"
                // dir("${env.WORKSPACE}/demo_webapp"){
                //     sh "trivy fs . | tee filesystem_scan.txt"
                // } 
            }
        }

        stage("Docker Build & Push"){
            steps{
                    script{
                            withDockerRegistry(credentialsId: 'docker_cred', toolName: 'docker'){   
                                sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_API_KEY} -t $DOCKER_REGISTRY:latest ."
                                sh "docker tag $DOCKER_REGISTRY:latest ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                                sh "docker push $DOCKER_REGISTRY:latest && docker push ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                            }
                    } 
                // dir("${env.WORKSPACE}/demo_webapp"){
                //     script{
                //             withDockerRegistry(credentialsId: 'docker_cred', toolName: 'docker'){   
                //                 sh "docker build --build-arg TMDB_V3_API_KEY=${TMDB_API_KEY} -t $DOCKER_REGISTRY:latest ."
                //                 sh "docker tag $DOCKER_REGISTRY:latest ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                //                 sh "docker push $DOCKER_REGISTRY:latest && docker push ${DOCKER_REGISTRY}:${BUILD_NUMBER}"
                //                 }
                //     }   
                // }

            }
        }

        stage("Image Scan"){
            steps{
                sh "trivy image $DOCKER_REGISTRY:latest | tee image_scan.txt" 
                // dir("${env.WORKSPACE}/demo_webapp"){
                //     sh "trivy image $DOCKER_REGISTRY:latest | tee image_scan.txt" 
                // }
                
            }
        }

        // stage('Deploy to container'){
        //     steps{
        //         sh 'docker run -d --name testapp${BUILD_NUMBER} -p 808${BUILD_NUMBER}:80 $DOCKER_REGISTRY:latest'
        //     }
        // }


        // stage('Update K8s manifest') {
        //     steps {

        //             script {
        //                     withCredentials([usernamePassword(credentialsId: 'github_token', passwordVariable: 'GIT_PASSWORD', usernameVariable: 'GIT_USERNAME')]) {
        //                     sh "git config user.email yemi@gmail.com"
        //                     sh "git config user.name yemi"
        //                     sh "cat deployment.yml"
        //                     sh "sed -i 's|image: ${DOCKER_REGISTRY}:.*|image: ${DOCKER_REGISTRY}:${BUILD_NUMBER}|g' deployment.yml"
        //                     sh "cat deployment.yml"
        //                     sh "git add deployment.yml"
        //                     sh "git commit -m 'Done by Jenkins Job changemanifest: ${env.BUILD_NUMBER}'"
        //                     sh "git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/${GIT_USERNAME}/kubernetes-manifests.git HEAD:main"
        //                 }
        //             }
                
        //     }
        // }


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
                // attachmentsPattern: '${env.WORKSPACE}/demo_webapp/filesystem_scan.txt,${env.WORKSPACE}/demo_webapp/image_scan.txt'
                attachmentsPattern: 'filesystem_scan.txt,image_scan.txt'

            sh "docker rmi ${DOCKER_REGISTRY}:${BUILD_NUMBER} && docker rmi ${DOCKER_REGISTRY}:latest"

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
