#!/bin/bash
#####################################
#
#  File: wp_setup.sh
#  Description: this script configures the OS and services of the WordPress server (VM)
#  Author: Fan ZHANG @ BCIT
#  ID: A01012536
#
#####################################

###setup SSH keys
#for some reason, ssh-copy-id is asking for authorized_keys.pub instead of authorized_keys in PXE
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.pub
#Add the public key above to the admin users ~/.ssh/authorized_keys file
ssh-copy-id -i ~/.ssh/authorized_keys admin@192.168.254.10
##needs to click yes and input password of admin at prompt !!!!!!!!!!!!!!!!!!!!!!!!!
ssh root@192.168.254.10
##needs to input password of root at prompt
adduser admin
passwd admin
#type password twice !!!!!!!!!!!!!!!!!!!!!!!
#Use the usermod command to add admin to the wheel group.
usermod -aG wheel admin

####Setup DNS
#DNS Name: wp.snp.acit (you will need to add this to the hosts file of the word press VM)
hostname wp.snp.acit
#Use hostname -s to get the short name (should reflect what you have in /etc/sysconfig/network
hostname -f
#Use the hostname -d command to test your domain (should reflect what you have in /etc/resolv.conf)
hostname -d


####Disable SELinux
setenforce 0
sed -r -i 's/SELINUX=(enforcing|permissive)/SELINUX=disabled/' /etc/selinux/config

#####Base Line Installed Packages
yum -y install @core epel-release vim git tcpdump nmap-ncat curl

#Execute yum update after the above package installation
yum -y update

####firewalld Setup
#Allow access to the following ports: 22, 80, 443.

declare zone="public"
declare portssh="22"
declare porthttp="80"
declare porthttps="443"

firewall-cmd --zone=$zone --add-port=$portssh/tcp --permanent
firewall-cmd --zone=$zone --add-port=$porthttp/tcp --permanent
firewall-cmd --zone=$zone --add-port=$porthttps/tcp --permanent

#should we use sudo firewall-cmd --zone=public --add-service=http --permanent ??
#should we use sudo firewall-cmd --zone=public --add-service=ssh --permanent ??
#should we use sudo firewall-cmd --zone=public --add-service=https --permanent ??

#reload firewall service to activate
firewall-cmd --reload

#Show open host ports
firewall-cmd --zone=$zone --list-all


#####nginx Setup
#1.	Install nginx package and update
yum -y install nginx

#2.	Start nginx using systemctl.
systemctl start nginx

#3.	Enable nginx using systemctl.
systemctl enable nginx.service

#4. Verify its operation using systemctl
systemctl status nginx.service

#5. Verify its operation using curl from the wordpress host itself.
curl -I wp.snp.acit

#6. Verify its operation using and your previous firewall configuration using a web browser from your host OS. (i.e. url = http://localhost:50080)
#confirmed works.

######MariaDB Setup
#1. Install the mariadb-server and mariadb packages
yum -y install mariadb-server mariadb
#2.	Start mariadb using systemctl.
systemctl start mariadb

#3. Execute mysql_secure_installation
# initially I wanted to create the file in pxe and scp to WP, later decided to just create the file.

# # ##scp the mariadb_security_config.sql to wp host
# # #first return to pxe vm
# # exit
# # #scp the mariadb_security_config.sql to wp host
# # cd 
# # scp -P 22 /home/admin/mariadb_security_config.sql admin@192.168.254.10:~/
# # ###enter password at prompt !!!!!!!

# # #log back in to wp vm
# # ssh root@192.168.254.10
# # ###enter password at prompt !!!!!!!

cd /home/admin/

touch /home/admin/mariadb_security_config.sql

cat > /home/admin/mariadb_security_config.sql << "EOF"
# Set root password
UPDATE mysql.user SET Password=PASSWORD('P@ssw0rd') WHERE User='root';

# Remove anonymous users
DELETE FROM mysql.user WHERE User='';

# Disallow remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

# Remove test database
DROP DATABASE test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
EOF

#configure mysql_secure_installation 
mysql -u root -p < mariadb_security_config.sql

#4.	Enable mariadb using systemctl.
systemctl enable mariadb.service

#5. Verify its operation using systemctl
systemctl status mariadb.service

#####PHP Setup
#1. Install the php, php-mysql, and php-fpm packages
yum -y install php php-mysql php-fpm

#2. Uncomment line 763 from /etc/php.ini by removing the leading ; and change the 1 to a 0 so it matches:
# cgi.fix_pathinfo=0
#backup /etc/php.ini
cp /etc/php.ini /etc/php.ini/bak
#remove leading ";"
sed -i '763s/;//' /etc/php.ini
#replace 1 with 0
sed -i '763s/1/0/' /etc/php.ini
#check result line number 763
sed -n 763p /etc/php/ini

#3. Edit /etc/php-fpm.d/www.conf so
cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

#Line 12 matches
#listen = /var/run/php-fpm/php-fpm.sock

#Due to the content contains forward slash "/", use "#" as delim in search
sed -i '12s#.*#listen = /var/run/php-fpm/php-fpm.sock#' /etc/php-fpm.d/www.conf

#Line 31 and 32 match
#listen.owner = nobody
#listen.group = nobody

#remove leading ";" for line 31 and 32
sed -i '31,32s/;//' /etc/php-fpm.d/www.conf

#Line 39 and 41 match
#user = nginx
#group = nginx
sed -i '39,41s/apache/nginx/' /etc/php-fpm.d/www.conf

#4.	Start and Enable php-fpm using systemctl.

systemctl start php-fpm
systemctl enable php-fpm.service
systemctl status php-fpm.service

#5. Configure nginx to process php pages modifying /etc/nginx/nginx.conf so it matches

#comment line 11
sed -i '11{s/^/#/}' /etc/nginx/nginx.conf

# insert "index index.php index.html index.htm;" to line 43
##\\t to insert a tab in front
sed -i '43i\\tindex index.php index.html index.htm;' /etc/nginx/nginx.conf

# insert at line 58
#	location ~ \.php$ {
#	    try_files $uri =404;
#	    fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
#       fastcgi_index index.php;
#	    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
#	    include fastcgi_params;
#   }
sed -i '58i\\tlocation ~ \\.php$ {' /etc/nginx/nginx.conf
sed -i '59i\\t\ttry_files $uri =404;' /etc/nginx/nginx.conf
sed -i '60i\\t\tfastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;' /etc/nginx/nginx.conf
sed -i '61i\\t\tfastcgi_index index.php;' /etc/nginx/nginx.conf
sed -i '62i\\t\tfastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' /etc/nginx/nginx.conf
sed -i '63i\\t\tinclude fastcgi_params;' /etc/nginx/nginx.conf
sed -i '64i\\t}' /etc/nginx/nginx.conf

#6. Create a demonstration file /usr/share/nginx/html/info.php that contains <?php phpinfo(); ?>

echo '<?php phpinfo(); ?>' >  /usr/share/nginx/html/info.php

#7. Restart nginx
systemctl restart nginx

#8. From your host OS browse to the page http://localhost:50080/info.php and verify the operation of php.
#confirmed

#####WordPress Setup
###Database Configuration

#1.Create MariaDB Database for WordPress

touch /home/admin/wp_mariadb_config.sql

cat > /home/admin/wp_mariadb_config.sql << "EOF"
## Wordpress Database Setup
CREATE DATABASE wordpress;
CREATE USER wordpress_user@localhost IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON wordpress.* TO wordpress_user@localhost;

# Reload privilege tables
FLUSH PRIVILEGES;
EOF

#2. Execute the sql statements in the file by redirecting them to the mysql client you will be prompted for the password

mysql -u root -p < wp_mariadb_config.sql

#3. Verify user creation: 

mysql -u root -p -e "SELECT user FROM mysql.user;"
##enter password at prompt!!!!

#4. Verify database creation: 

mysql -u root -p -e "SHOW DATABASES;"
##enter password at prompt!!!!

#####Wordpress Source Setup

#1. Download wordpress
yum -y install wget

wget http://wordpress.org/latest.tar.gz

#2. Untar the archive into your home directory

tar xzvf latest.tar.gz

#3. Create a wordpress configuration using the sample

cp wordpress/wp-config-sample.php wordpress/wp-config.php

#4. Update the wordpress configuration to specify the appropriate mysql/mariadb database and user. Lines 23 - 38 should match:

# /** The name of the database for WordPress */
# define('DB_NAME', 'wordpress');

sed -i '23s/database_name_here/wordpress/' /home/admin/wordpress/wp-config.php

# /** MySQL database username */
# define('DB_USER', 'wordpress_user');

sed -i '26s/username_here/wordpress_user/' /home/admin/wordpress/wp-config.php

# /** MySQL database password */
# define('DB_PASSWORD', 'P@ssw0rd');

sed -i '29s/password_here/P@ssw0rd/' /home/admin/wordpress/wp-config.php

# /** MySQL hostname */
# define('DB_HOST', 'localhost');
#no change

# /** Database Charset to use in creating database tables. */
# define('DB_CHARSET', 'utf8');
#no change

# /** The Database Collate type. Don't change this if in doubt. */
# define('DB_COLLATE', '');
#no change

#5. Copy the WordPress source to the nginx document root using rsync to preserve all meta data (and go faster)

sudo rsync -avP wordpress/ /usr/share/nginx/html/

#6. Make a directory for uploads (we will use this later):

sudo mkdir /usr/share/nginx/html/wp-content/uploads

#7. Set the permissions on the WordPress source:

sudo chown -R admin:nginx /usr/share/nginx/html/*

#8. Verify that the operation of your WordPress site by visiting from your host os.
#confirmed http://localhost:50080/index.php



