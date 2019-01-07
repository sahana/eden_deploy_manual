#!/bin/bash

# Script to configure an Eden server
# - assumes that install-eden-cherokee-postgis.sh has been run

echo -e "What domain name should we use? : \c "
read DOMAIN

echo -e "What host name should we use? : \c "
read hostname
sitename=$hostname".$DOMAIN"

echo -e "What template should we use? : \c "
read template
if [[ ! "$template" ]]; then
    template="default"
fi

# @ToDo: Generate a random password
echo Note that web2py will not work with passwords with an @ in them
echo -e "What is the new MariaDB password: \c "
read password

echo "Now reconfiguring system to use the hostname: $hostname"

yes | cp /etc/hosts /tmp/hosts
cd /etc
filename="hosts"
sed -i "s|localhost.localdomain localhost|$sitename $hostname localhost.localdomain localhost|" $filename

cd /etc
filename="hostname"
echo $hostname > $filename

cd /etc
filename="mailname"
echo $sitename >  $filename

# Update system (in case run at a much later time than the install script)
yum -y update
# Disabled to ensure we keep Stable version from Install
#cd ~web2py
#git pull
cd ~web2py/applications/eden
git pull
# -----------------------------------------------------------------------------
# Email
# -----------------------------------------------------------------------------
# @ToDo: Check for CentOS equivalent
#echo configure for Internet mail delivery
#dpkg-reconfigure exim4-config

# -----------------------------------------------------------------------------
# Sahana Eden
# -----------------------------------------------------------------------------
echo "Setting up Sahana"

# Copy Templates
yes | cp ~web2py/applications/eden/modules/templates/000_config.py ~web2py/applications/eden/models

sed -i "s|settings.base.template = \"default\"|settings.base.template = \"$template\"|" ~web2py/applications/eden/models/000_config.py
sed -i 's|EDITING_CONFIG_FILE = False|EDITING_CONFIG_FILE = True|' ~web2py/applications/eden/models/000_config.py
sed -i "s|akeytochange|$sitename$password|" ~web2py/applications/eden/models/000_config.py
sed -i "s|#settings.base.public_url = \"http://127.0.0.1:8000\"|settings.base.public_url = \"http://$sitename\"|" ~web2py/applications/eden/models/000_config.py
sed -i 's|#settings.base.cdn = True|settings.base.cdn = True|' ~web2py/applications/eden/models/000_config.py

#########
# MariaDB
#########

# Create Database
mysqladmin -u root create sahana

# Create User
mysql -e "CREATE USER 'sahana'@'localhost' IDENTIFIED BY '$password';FLUSH PRIVILEGES;"
mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'sahana'@'localhost' WITH GRANT OPTION;"

# Remove Test Database
mysql -e "DROP DATABASE IF EXISTS test;" --user=root
# Remove Anonymous Users
mysql -e "DELETE FROM mysql.user WHERE User='';" --user=root
# Remove Remote Root
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" --user=root
# Set Root Password
mysql -e "UPDATE mysql.user SET Password=PASSWORD('$password') WHERE User='root';FLUSH PRIVILEGES;" --user=root

# Allow root user to access database without entering password
cat << EOF > "/root/.my.cnf"
[client]
user=root
EOF

echo "password='$password'" >> "/root/.my.cnf"

# Configure Eden to use Database
sed -i 's|#settings.database.db_type = "mysql"|settings.database.db_type = "mysql"|' ~web2py/applications/eden/models/000_config.py
sed -i "s|#settings.database.password = \"password\"|settings.database.password = \"$password\"|" ~web2py/applications/eden/models/000_config.py

# On some systems need to set the PYTHONPATH
#/etc/profile
#PYTHONPATH=/home/web2py/site-packages:/home/web2py:/opt/rh/python27/root/usr/lib64/python27.zip:/opt/rh/python27/root/usr/lib64/python2.7:/opt/rh/python27/root/usr/lib64/python2.7/plat-linux2:/opt/rh/python27/root/usr/lib64/python2.7/lib-tk:/opt/rh/python27/root/usr/lib64/python2.7/lib-old:/opt/rh/python27/root/usr/lib64/python2.7/lib-dynload:/opt/rh/python27/root/usr/lib64/python2.7/site-packages:/opt/rh/python27/root/usr/lib64/python2.7/site-packages/psycopg2-2.7.6-py2.7-linux-x86_64.egg:/opt/rh/python27/root/usr/lib/python2.7/site-packages:/home/web2py/gluon/packages/dal
#export PYTHONPATH

# Create the Tables & Populate with base data
sed -i 's|settings.base.migrate = False|settings.base.migrate = True|' ~web2py/applications/eden/models/000_config.py
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py

# Configure for Production
sed -i 's|#settings.base.prepopulate = 0|settings.base.prepopulate = 0|' ~web2py/applications/eden/models/000_config.py
sed -i 's|settings.base.migrate = True|settings.base.migrate = False|' ~web2py/applications/eden/models/000_config.py
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py

# Schedule backups for 02:01 daily
echo "1 2   * * * root    /usr/local/bin/backup" >> "/etc/crontab"

#read -p "Press any key to Reboot..."
echo "Now rebooting.."
reboot

# END
