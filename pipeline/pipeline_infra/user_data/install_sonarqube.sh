#!/bin/bash
################################################################################
# INSTALL DOCKER
################################################################################
apt-get update
apt-get install docker.io -y
usermod -aG docker $USER  
chmod 777 /var/run/docker.sock

################################################################################
# RUN SONARQUBE - do not use passwords in github, demo purposes only
################################################################################
mkdir -p /opt/sonar && cd /opt/sonar
apt install docker-compose -y 

cat <<EOT> docker-compose.yml
version: "3"
services:
  sonarqube:
    image: sonarqube:9.9.2-community
    restart: on-failure
    environment:
      SONAR_JDBC_URL: jdbc:postgresql://db:5432/sonardemo
      SONAR_JDBC_USERNAME: sonardemo
      SONAR_JDBC_PASSWORD: sonardemo
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    ports:
      - "9000:9000"
    depends_on:
      - db
  db:
    image: postgres:12
    restart: on-failure
    environment:
      POSTGRES_USER: sonardemo
      POSTGRES_PASSWORD: sonardemo
      POSTGRES_DB: sonardemo
    volumes:
      - postgresql:/var/lib/postgresql
      - postgresql_data:/var/lib/postgresql/data
volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql:
  postgresql_data:
EOT

chown -R ubuntu.ubuntu /opt/sonar
docker-compose up -d
