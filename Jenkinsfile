def COLOR_MAP = [
    'SUCCESS': 'good', 
    'FAILURE': 'danger',
]

pipeline {
    agent any

    options {
        timeout(time: 40, unit: 'MINUTES')
        parallelsAlwaysFailFast()
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

        stage('Build'){
            steps {
                sh "mvn clean install -DskipTests"
            }
            post {
                success {
                    echo 'Now Archiving...'
                    archiveArtifacts artifacts: '**/target/*.war'
                }
            }
        }  

        stage('Test'){
            parallel {
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
                    }
        }

        stage('Vulnerability check'){
            parallel {
                        stage('OWASP Dependency check') {
                            steps {
                                dependencyCheck additionalArguments: '--scan ./ ', odcInstallation: 'dependency_check'
                                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'

                                //SET FAILURE THRESHOLDS HERE
                                // dependencyCheckPublisher (
                                //     pattern: '**/dependency-check-report.xml',
                                //     failedTotalLow: 1,
                                //     failedTotalMedium: 1,
                                //     failedTotalHigh: 1,
                                //     failedTotalCritical: 1
                                // )
                                //Uncomment to fail pipeline at this stage
                                /*
                                script{
                                    if (currentBuild.result == 'UNSTABLE') {
                                        unstable('UNSTABLE: Dependency check')
                                    } else if (currentBuild.result == 'FAILURE') {
                                        error('FAILED: Dependency check')
                                    }
                                } 
                                */
                            }
                        }

                        stage('FileSystem scan') {
                            steps {
                                sh "trivy fs --scanners vuln,config . | tee filesystem_scanresults.txt"
                                sh "trivy fs --scanners vuln,config -f json -o filesystem_scanresults.json --severity CRITICAL --exit-code 0 --clear-cache . " //UPDATE EXIT CODE TO FAIL PIPELINE
                                sh "bash check-trivy-scan-status.sh"
                            
                            }
                        }

                    }
        }

        stage('SonarQube Analysis') {
            steps {
                sh 'mvn checkstyle:checkstyle'
                withSonarQubeEnv('sonarcloud_server') {
                    sh '''${SONAR_SCANNER_HOME}/bin/sonar-scanner -Dsonar.projectKey=vprofile-app \
                -Dsonar.projectName=vprofile-app \
                -Dsonar.projectVersion=1.0 \
                -Dsonar.organization=yemis-projects \
                -Dsonar.sources=src/ \
                -Dsonar.java.binaries=target/test-classes/com/visualpathit/account/controllerTest/ \
                -Dsonar.junit.reportsPath=target/surefire-reports/ \
                -Dsonar.jacoco.reportsPath=target/jacoco.exec \
                -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml'''
                }
            }
        }

        stage('Quality gate'){
            steps {
                    timeout(time: 20, unit: 'MINUTES') {
                        waitForQualityGate abortPipeline: true
                    }
                }
        }

        stage("Docker Build"){
            steps{
                    sh "docker build -t $DOCKER_REGISTRY:latest ."
                }
        }

        stage("Image Scan"){
            steps{
               script{
                            sh "trivy image $DOCKER_REGISTRY:latest | tee image_scan.txt"
                            sh "trivy image $DOCKER_REGISTRY:latest --severity HIGH,CRITICAL --exit-code 1 -f json -o image_scanresults.json --clear-cache" //UPDATE EXIT CODE TO FAIL PIPELINE
                            sh "bash check-trivy-scan-status.sh" //FAIL PIPELINE ON exit code 1
                            sh "docker tag $DOCKER_REGISTRY:latest ${DOCKER_REGISTRY}:V${BUILD_NUMBER}"
                            
                            withDockerRegistry(credentialsId: 'docker_cred'){   
                                            sh "docker push $DOCKER_REGISTRY:latest && docker push ${DOCKER_REGISTRY}:V${BUILD_NUMBER}"
                            }
                   } 
            }
        }

        stage('Update Helm repo'){
            parallel {
                        stage('Image tag update') {
                            environment{
                                DOCKER_TAG = "V${BUILD_NUMBER}"
                            }
                            steps {
                                script{
                                    echo "triggering updatemanifestjob"
                                    build job: 'update-k8-manifest', parameters: [string(name: 'DOCKER_TAG', value: env.DOCKER_TAG)]
                                }

                            }
                        }
                        stage('Cleanup unused docker image') {
                            steps{
                                sh "docker rmi $DOCKER_REGISTRY:latest && docker rmi $DOCKER_REGISTRY:V$BUILD_NUMBER"
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
                attachmentsPattern: 'filesystem_scanresults.txt,filesystem_scanresults.json,image_scan.txt,image_scanresults.json'

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
