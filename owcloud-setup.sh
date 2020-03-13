#!/bin/sh
echo \"---------Getting Apache and MySQL Packages\"
apt update
apt install -y apache2 mariadb-server expect

#Configure MySQL
MYSQLROOTPW=''
MYSQLOwnCloudPW=''

DigitalOceanSpacesName=''
DigitalOceanEndpoint=''
# AWSRegion=''
DigitalOceanSpacesUserKey=''
DigitalOceanSpacesUserSecret=''

OCAdminUser=''
OCAdminPassword=''

# IPA=`curl http://169.254.169.254/latest/meta-data/public-ipv4 | sed -r 's@\.@-@g'`
# OCDomain=`dig @resolver1.opendns.com ANY myip.opendns.com +short`

service mysql start

expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"Y\r\"
expect \"New password:\"
send \"$MYSQLROOTPW\r\"
expect \"Re-enter new password:\"
send \"$MYSQLROOTPW\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
"

apt -y purge expect

#Create MySql User
echo \"---------Create Mysql User\"
mysql -u root -e "Create DATABASE owncloud;"
mysql -u root -e "Grant ALL ON owncloud.* to 'owncloud'@'localhost' IDENTIFIED BY '$MYSQLOwnCloudPW';"
mysql -u root -e "Flush Privileges"



#Install PHP
echo \"---------Installing PHP\"
apt -y install php libapache2-mod-php php-mysql  

#Install Owncloud
# echo \"---------Installing Owncloud\"
# curl https://download.ownCloud.org/download/repositories/10.0/Ubuntu_18.04/Release.key | sudo apt-key add - 
# echo 'deb http://download.ownCloud.org/download/repositories/10.0/Ubuntu_18.04/ /' | sudo tee /etc/apt/sources.list.d/ownCloud.list  
# apt update  
apt -y install php-bz2 php-curl php-gd php-imagick php-intl php-mbstring php-xml php-zip
wget -O owncloud-10.4.0.tar.bz2 https://download.owncloud.org/community/owncloud-10.4.0.tar.bz2
tar -xjf owncloud-10.4.0.tar.bz2
cp -r /root/owncloud /var/www
chown -R www-data:www-data /var/www/owncloud

#Configure Apache with owncloud directory
echo \"---------updating apache config file\"
sed -i 's@DocumentRoot /var/www/html@DocumentRoot /var/www/owncloud@' /etc/apache2/sites-enabled/000-default.conf

service apache2 restart

#Download S3 owncloud libraries
echo \"---------downloading and install s3 library and config\"
cd ~
git clone https://github.com/Reillylane/aws_student_lab_files.git

cp -R aws_student_lab_files/ /var/www/owncloud/apps/files_primary_s3

#Create Config File
sudo -u www-data printf "
<?php
\$CONFIG = array (
  'objectstore' =>
  array (
    'class' => 'OCA\Files_Primary_S3\S3Storage',
    'arguments' =>
    array (
      'bucket' => '$DigitalOceanSpacesName',
      'options' =>
      array (
        'version' => '2006-03-01',
        'region' => '',
        'credentials' =>
        array (
          'key' => '$DigitalOceanSpacesUserKey',
          'secret' => '$DigitalOceanSpacesUserSecret',
        ),
        'use_path_style_endpoint' => true,
        'endpoint' => '$DigitalOceanEndpoint',
      ),
    ),
  ),
  'trusted_domains' =>
  array (
    0 => '$OCDomain',
  ),
);
" > /var/www/owncloud/config/config.php
chown www-data:www-data /var/www/owncloud/config/config.php

sudo -u www-data php /var/www/owncloud/occ maintenance:install --database "mysql" --database-name "owncloud"  --database-user "owncloud" --database-pass "$MYSQLOwnCloudPW" --admin-user "$OCAdminUser" --admin-pass "$OCAdminPassword"

echo \"$OCDomain\"
sudo -u www-data php /var/www/owncloud/occ config:system:set trusted_domains 0 --value $OCDomain 
echo \"---------done\"
"\n"
