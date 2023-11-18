# DevSecOps CI/CD with Jenkins and ArgoCD

This repository contains the source code and Jenkinsfile used to automate the Continous Integration phases of a CI/CD pipeline to EKS. Continous delivery is accomplished via ArgoCD. This repo is intended to be used with the two repositories listed below.
- https://github.com/yemisprojects/eks-infra (contains terraform code and github workflow to automate EKS deployment)
- https://github.com/yemisprojects/kubernetes-manifests (contains helm charts for deployment by ArgoCD)


## Pipeline 

.....insert image here

Jenkins is open source and free. With numerous plugins available it provides easy integration to many third party systems. If server management is a not a major concern, Jenkins is a great choice for CI and CD to streamline your application delivery pipeline

## Application Stack
Java app, MySQL, Rabbitmq, Memcache 

#### Application requirements
- JDK 1.8 or later
- Maven 3 or later
- MySQL 5.6 or later

<!--- 
## Technologies 
- Spring MVC
- Spring Security
- Spring Data JPA
- Maven
- JSP
- MySQL
--->

#### Database
`src/main/resources/db_backup.sql` is a mysql script to import some dummy data. To import against an existing database run this command.

```sh
mysql -u <user_name> -p accounts < accountsdb.sql
```

#### 
**Note**: The docker images memcache

## CICD setup prerequisites
1. DockerHub account
2. SonarCloud account
3. Github account
4. Email address
5. Slack Channel
5. Jenkins Instance (This should have been deployed using instructions from my [eks-infra repo](https://github.com/yemisprojects/eks-infra))
6. EKS Cluster (This should have been deployed using instructions from my [eks-infra repo](https://github.com/yemisprojects/eks-infra))

## CI/CD initial setup (required)

#### Step 1. Setup Slack
- Create a new Slack account followed by a workspace using the [steps here](https://slack.com/help/articles/206845317-Create-a-Slack-workspace). 
- Within the new workspace [create a slack channel](https://slack.com/help/articles/201402297-Create-a-channel) named `k8s-jenkins-cicd`.
- Apply the Jenkins App within the Slack workspace. 
    - Go to the Slack Jenkins app [here](https://slack.com/apps/A0F7VRFKN-jenkins-ci?tab=more_info) → Click Install → Add to Slack
    - Choose the channel `k8s-jenkins-cicd`. 
    - Add Jenkins CI integration
    - Proceed with the Setup Instructions and note down the auto-generated _Integration token credential ID_

#### Step 2. Setup Github repository
- Fork this repository
- Create Github webhook: To trigger the Jenkins pipeline automatically after each push, create a github webhook with these steps
    - Go to your GitHub repository. Under Settings → Add Webhooks. Use the information below _where x.x.x.x is jenkins public IP_. Refresh browser and confirm the test ping is successful. The Jenkins security group has been setup allow the Github webhook access
    ```
            Payload URL: http://x.x.x.x:8080/github-webhook/   
            Content type: application/json
    ```
- Create a Github personal access token(classic) with admin privileges and note down the token for a later step when setting up Jenkins

#### Step 3. Setup SonarCloud
- Go to the SonarCloud [website](https://sonarcloud.io/) and signup for a free account
- Create an organization and note down the name for a latter step
- Create a project named `vprofile-app`. 
- Create a webook 
    - Go to the `vprofile-app` → `Administration` → `Configuration` → `Webhooks`
    - Click Create and provide the information below, _where x.x.x.x is jenkins public IP_
    ```
    Name: Jenkins
    URL: http://x.x.x.x:8080/sonarqube-webhook          
    ``` 
- Create a new Quality Gate. Documentation [here](https://docs.sonarsource.com/sonarcloud/standards/managing-quality-gates/#:~:text=To%20create%20a%20new%20quality,in%20Your%20Organization%20>%20Quality%20Gates.)
    - Go to Organization → Quality Gates → Create → Name (jenkins)
    - Add a condition. Select `On Overall Code` → `Quality Gate failes when` → `Bugs` → is greater than `50` (For test purposes)
    - The app used for this project has 29 bugs so the Quality gate test will pass
    - Ensure to set the new Quality gate as default to make sure that this quality gate will apply to any new code analysis
    <!---IMPORTANT https://jenkinshero.com/sonarqube-quality-gates-in-jenkins-build-pipeline/ --->

#### Step 4. Setup Jenkins
- Login to Jenkins via SSM or SSH to get the initial password with the command below: 
   ``` cat /var/lib/jenkins/secrets/initialAdminPassword```
- Login to the Jenkins Web UI at http://x.x.x.x:8080/ _where x.x.x.x is jenkins public IP_ using the default username (admin)and the password obtained  above. Accept the recommendation to Install the recommended plugins. 
- Install Jenkins Plugins
    - Goto Manage Jenkins → Plugins → Available Plugins → Select all the plugins below → Install. If a plugin is not listed, it is most likely installed
        - SonarQube Scanner 
        - Email Extension Plugin
        - Eclipse Temurin Installer
        - OWASP Dependency-Check
        - Docker
        - Docker Commons
        - Docker Pipeline
        - Docker API
        - Docker-build-step
        - Slack Notification
        - Github Integration
- Install Jenkins Tools
    - Goto Manage Jenkins → Tools. Install each tool using the configuration below. Click Apply and Save
        - JDK Installations
            - Name: jdk17
            - Tick Install automatically → Click Add Installer → Install from adoptium.net 
            - Version: JDK-17.0.8.1+1
        - SonarQube Scanner Installations
            - Name: sonar_scanner
            - Tick: Install automatically
            - Version: SonarQube Scanner 5.0.1.3006
        - Dependency-Check Installations
            - Name: dependency_check
            - Tick: Install automatically → Click Install from github.com
            - Version: dependency-check 6.5.1	
- Add credentials to Jenkins
    - Goto Jenkins Dashboard → Manage Jenkins → Credentials → Select global → Add credentials
    - Add Sonarqube token
        - Obtain the token by logging into SonarCloud. Goto My Account  → Security → Enter Token Name →   Create a token → Click on Generate Token.
        - Add the sonar token in Jenkins using the configuration below and click Create
            - Kind: Secret text
            - Secret: ****			         _(Provide sonarqube token obtained above)_
            - ID: sonar_token
            - Description: sonar_token
    - Add Jenkins Slack integration token using the configuration below 
            - Kind: Secret text
            - Secret: ****	           _(Provide slack integration token previously obtained above)_
            - ID: slack_token
            - Description: slack_token


