#!/bin/bash
################################################################################
# INSTALL SONARQUBE
################################################################################
cp /etc/sysctl.conf /root/sysctl.conf_backup

cat <<EOT> /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
ulimit -n 65536
ulimit -u 4096
EOT
cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT> /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    409
EOT

apt-get update -y
apt-get install openjdk-11-jdk -y
update-alternatives --config java
java -version
apt update
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | apt-key add -
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
apt install postgresql postgresql-contrib -y
#-u postgres psql -c "SELECT version();"
systemctl enable postgresql.service
systemctl start  postgresql.service
echo "postgres:admin123" | chpasswd
runuser -l postgres -c "createuser sonar"
-i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
-i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
-i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"
systemctl restart  postgresql
#systemctl status -l   postgresql
netstat -tulpena | grep postgres
mkdir -p /sonarqube/
cd /sonarqube/
curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
apt-get install zip -y
unzip -o sonarqube-8.3.0.34182.zip -d /opt/
mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
groupadd sonar
useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
chown sonar:sonar /opt/sonarqube/ -R
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup

cat <<EOT> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

cat <<EOT> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable sonarqube.service
systemctl start sonarqube.service
systemctl status -l sonarqube.service

echo "System reboot in 30 sec"
sleep 30
reboot
