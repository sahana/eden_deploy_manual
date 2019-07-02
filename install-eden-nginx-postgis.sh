#!/bin/bash

# Script to turn a generic Debian Wheezy or Jessie box into an Eden server
# with Nginx & PostgreSQL
# - tunes PostgreSQL for 512Mb RAM (e.g. Amazon Micro (free tier))
# - run pg1024 to tune for 1Gb RAM (e.g. Amazon Small or greater)

# Which OS are we running?
read -d . DEBIAN < /etc/debian_version

if [ $DEBIAN == '9' ]; then
    DEBIAN_NAME='stretch'
elif [ $DEBIAN == '8' ]; then
    DEBIAN_NAME='jessie'
else
    DEBIAN_NAME='wheezy'
fi

# Update system
apt-get update
apt-get -y upgrade
apt-get clean

# Install Admin Tools
apt-get -y install unzip psmisc mlocate telnet lrzsz vim rcconf htop sudo p7zip dos2unix curl
if [ $DEBIAN == '9' ]; then
    apt-get -y install elinks net-tools
else
    apt-get -y install elinks-lite
fi
apt-get clean
# Git
apt-get -y install git-core
apt-get clean
# Email
apt-get -y install exim4-config exim4-daemon-light
apt-get clean

#########
# Python
#########
# Install Libraries
if [ $DEBIAN == '9' ]; then
    apt-get -y install libgeos-c1v5
else
    apt-get -y install libgeos-c1
fi

# Install Python
#apt-get -y install python2.7
apt-get -y install python-dev
# 100 Mb of diskspace due to deps, so only if you want an advanced shell
#apt-get -y install ipython
apt-get clean
apt-get -y install python-lxml python-setuptools python-dateutil
apt-get clean
apt-get -y install python-serial
#apt-get -y install python-imaging python-reportlab
apt-get -y install python-imaging
apt-get -y install python-matplotlib
apt-get -y install python-pip
apt-get -y install python-requests
apt-get -y install python-xlwt
apt-get -y install build-essential
apt-get clean

pip install geopy

# Upgrade ReportLab for Percentage support
#apt-get remove -y python-reportlab
#wget --no-check-certificate http://pypi.python.org/packages/source/r/reportlab/reportlab-3.3.0.tar.gz
#tar zxvf reportlab-3.3.0.tar.gz
#cd reportlab-3.3.0
#python setup.py install
#cd ..
pip install reportlab

# Upgrade Shapely for Simplify enhancements
#apt-get remove -y python-shapely
apt-get -y install libgeos-dev
#wget --no-check-certificate https://pypi.python.org/packages/e6/23/03ea2c965fe5ded97c0dd97c2cd659f1afb5c21f388ec68012d6d981cb7c/Shapely-1.5.17.tar.gz
#tar zxvf Shapely-1.5.17.tar.gz
#cd Shapely-1.5.17
#python setup.py install
#cd ..
pip install shapely

# Upgrade XLRD for XLS import support
#apt-get remove -y python-xlrd
#wget --no-check-certificate http://pypi.python.org/packages/source/x/xlrd/xlrd-0.9.4.tar.gz
#tar zxvf xlrd-0.9.4.tar.gz
#cd xlrd-0.9.4
#python setup.py install
#cd ..
pip install xlrd

#########
# Web2Py
#########
apt-get -y install libodbc1
# Install Web2Py
adduser --system --disabled-password web2py
addgroup web2py
cd /home
env GIT_SSL_NO_VERIFY=true git clone --recursive https://github.com/web2py/web2py.git
cd web2py
# 2.14.6
#git reset --hard cda35fd
# 2.16.1
#git reset --hard 7035398
# 2.17.1
#git reset --hard 285013a
# 2.18.3
git reset --hard 6128d03
git submodule update --init --recursive
# Fix for 2.16.1
#sed -i "s|credential_decoder = lambda cred: urllib.unquote(cred)|credential_decoder = lambda cred: unquote(cred)|" /home/web2py/gluon/packages/dal/pydal/base.py
# Fix for 2.18.3
sed -i "s|from urllib import FancyURLopener, urlencode, urlopen|from urllib import FancyURLopener, urlencode|" /home/web2py/gluon/packages/dal/pydal/_compat.py
sed -i "/urllib_quote_plus/ a \ \ \ \ from urllib2 import urlopen" /home/web2py/gluon/packages/dal/pydal/_compat.py
ln -s /home/web2py ~
cp -f /home/web2py/handlers/wsgihandler.py /home/web2py
cat << EOF > "/home/web2py/routes.py"
#!/usr/bin/python
default_application = 'eden'
default_controller = 'default'
default_function = 'index'
routes_onerror = [
        ('eden/400', '!'),
        ('eden/401', '!'),
        ('eden/509', '!'),
        ('eden/*', '/eden/errors/index'),
        ('*/*', '/eden/errors/index'),
    ]
EOF

# Configure Matplotlib
mkdir /home/web2py/.matplotlib
chown web2py /home/web2py/.matplotlib
echo "os.environ['MPLCONFIGDIR'] = '/home/web2py/.matplotlib'" >> /home/web2py/wsgihandler.py
sed -i 's|TkAgg|Agg|' /etc/matplotlibrc

##############
# Sahana Eden
##############
# Install Sahana Eden
cd /home/web2py
cd applications
# @ToDo: Stable branch
env GIT_SSL_NO_VERIFY=true git clone https://github.com/sahana/eden.git
# Fix permissions
chown web2py ~web2py
chown web2py ~web2py/applications/admin/cache
chown web2py ~web2py/applications/admin/cron
chown web2py ~web2py/applications/admin/databases
chown web2py ~web2py/applications/admin/errors
chown web2py ~web2py/applications/admin/sessions
chown web2py ~web2py/applications/eden
chown web2py ~web2py/applications/eden/cache
chown web2py ~web2py/applications/eden/cron
mkdir -p ~web2py/applications/eden/databases
chown web2py ~web2py/applications/eden/databases
mkdir -p ~web2py/applications/eden/errors
chown web2py ~web2py/applications/eden/errors
chown web2py ~web2py/applications/eden/models
mkdir -p ~web2py/applications/eden/sessions
chown web2py ~web2py/applications/eden/sessions
chown web2py ~web2py/applications/eden/static/fonts
chown web2py ~web2py/applications/eden/static/img/markers
mkdir -p ~web2py/applications/eden/static/cache/chart
chown web2py -R ~web2py/applications/eden/static/cache
mkdir -p ~web2py/applications/eden/uploads/gis_cache
mkdir -p ~web2py/applications/eden/uploads/images
mkdir -p ~web2py/applications/eden/uploads/tracks
chown web2py ~web2py/applications/eden/uploads
chown web2py ~web2py/applications/eden/uploads/gis_cache
chown web2py ~web2py/applications/eden/uploads/images
chown web2py ~web2py/applications/eden/uploads/tracks
ln -s /home/web2py/applications/eden /home/web2py
ln -s /home/web2py/applications/eden ~

##########
# Nginx
##########
apt-get install nginx

mkdir /var/log/cherokee
chown www-data:www-data /var/log/cherokee
mkdir -p /var/lib/cherokee/graphs
chown www-data:www-data -R /var/lib/cherokee

# Install uWSGI
#apt-get install -y libxml2-dev
cd /tmp
wget http://projects.unbit.it/downloads/uwsgi-1.9.18.2.tar.gz
tar zxvf uwsgi-1.9.18.2.tar.gz
cd uwsgi-1.9.18.2
#cd uwsgi-1.2.6/buildconf
#wget http://eden.sahanafoundation.org/downloads/uwsgi_build.ini
#cd ..
#sed -i "s|, '-Werror'||" uwsgiconfig.py
#python uwsgiconfig.py --build uwsgi_build
python uwsgiconfig.py --build pyonly.ini
cp uwsgi /usr/local/bin

# Configure uwsgi

## Log rotation
cat << EOF > "/etc/logrotate.d/uwsgi"
/var/log/uwsgi/*.log {
       weekly
       rotate 10
       copytruncate
       delaycompress
       compress
       notifempty
       missingok
}
EOF

## Add Scheduler config

cat << EOF > "/home/web2py/run_scheduler.py"
#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys

if '__file__' in globals():
    path = os.path.dirname(os.path.abspath(__file__))
    os.chdir(path)
else:
    path = os.getcwd() # Seems necessary for py2exe

sys.path = [path]+[p for p in sys.path if not p==path]

# import gluon.import_all ##### This should be uncommented for py2exe.py
import gluon.widget
from gluon.shell import run

# Start Web2py Scheduler -- Note the app name is hardcoded!
if __name__ == '__main__':
    run('eden',True,True,None,False,"from gluon import current; current._scheduler.loop()")
EOF


cat << EOF > "/home/web2py/uwsgi.ini"
[uwsgi]
uid = web2py
gid = web2py
chdir = /home/web2py/
module = wsgihandler
mule = run_scheduler.py
workers = 4
cheap = true
idle = 1000
harakiri = 1000
pidfile = /tmp/uwsgi-prod.pid
daemonize = /var/log/uwsgi/prod.log
socket = 127.0.0.1:59025
master = true
chmod-socket = 666
chown-socket = web2py:nginx
EOF

touch /tmp/uwsgi-prod.pid
chown web2py:www-data /tmp/uwsgi-prod.pid

mkdir -p /var/log/uwsgi
chown web2py:www-data /var/log/uwsgi

# Init script for uwsgi

cat << EOF > "/etc/init.d/uwsgi-prod"
#! /bin/bash
# /etc/init.d/uwsgi-prod
#

daemon=/usr/local/bin/uwsgi
pid=/tmp/uwsgi-prod.pid
args="/home/web2py/uwsgi.ini"

# Carry out specific functions when asked to by the system
case "\$1" in
    start)
        echo "Starting uwsgi"
        start-stop-daemon -p \$pid --start --exec \$daemon -- \$args
        ;;
    stop)
        echo "Stopping script uwsgi"
        start-stop-daemon --signal INT -p \$pid --stop \$daemon -- \$args
        ;;
    restart)
        \$0 stop
        sleep 1
        \$0 start
        ;;
    reload)
        echo "Reloading conf"
        kill -HUP \`cat \$pid\`
        ;;
    *)
        echo "Usage: /etc/init.d/uwsgi {start|stop|restart|reload}"
        exit 1
    ;;
esac
exit 0
EOF

chmod a+x /etc/init.d/uwsgi-prod
update-rc.d uwsgi-prod defaults

############
# PostgreSQL
############
cat << EOF > "/etc/apt/sources.list.d/pgdg.list"
deb http://apt.postgresql.org/pub/repos/apt/ $DEBIAN_NAME-pgdg main
EOF

wget --no-check-certificate https://www.postgresql.org/media/keys/ACCC4CF8.asc
apt-key add ACCC4CF8.asc
apt-get update

apt-get -y install postgresql-9.6 python-psycopg2 ptop pgtop
apt-get -y install postgresql-9.6-postgis-2.3

# Tune PostgreSQL
cat << EOF >> "/etc/sysctl.conf"
## Increase Shared Memory available for PostgreSQL
# 512Mb
#kernel.shmmax = 279134208
# 1024Mb (may need more)
kernel.shmmax = 552992768
kernel.shmall = 2097152
EOF
#sysctl -w kernel.shmmax=279134208 # For 512 MB RAM
sysctl -w kernel.shmmax=552992768 # For 1024 MB RAM
sysctl -w kernel.shmall=2097152

sed -i 's|#track_counts = on|track_counts = on|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|#autovacuum = on|autovacuum = on|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|max_connections = 100|max_connections = 20|' /etc/postgresql/9.6/main/postgresql.conf
# 1024Mb RAM: (e.g. t2.micro)
sed -i 's|#effective_cache_size = 4GB|effective_cache_size = 512MB|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|#work_mem = 4MB|work_mem = 8MB|' /etc/postgresql/9.6/main/postgresql.conf
# If only 512 RAM, activate post-install via pg512 script

#####################
# Management scripts
#####################
cat << EOF > "/usr/local/bin/backup"
#!/bin/sh
mkdir /var/backups/eden
chown postgres /var/backups/eden
NOW=\$(date +"%Y-%m-%d")
su -c - postgres "pg_dump -c sahana > /var/backups/eden/sahana-\$NOW.sql"
#su -c - postgres "pg_dump -Fc gis > /var/backups/eden/gis.dmp"
OLD=\$(date --date='7 day ago' +"%Y-%m-%d")
rm -f /var/backups/eden/sahana-\$OLD.sql
mkdir /var/backups/eden/uploads
tar -cf /var/backups/eden/uploads/uploadsprod-\$NOW.tar -C /home/web2py/applications/eden  ./uploads
bzip2 /var/backups/eden/uploads/uploadsprod-\$NOW.tar
rm -f /var/backups/eden/uploads/uploadsprod-\$OLD.tar.bz2
EOF
chmod +x /usr/local/bin/backup

cat << EOF > "/usr/local/bin/compile"
#!/bin/bash
/etc/init.d/uwsgi-prod stop
cd ~web2py
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
EOF
chmod +x /usr/local/bin/compile

cat << EOF > "/usr/local/bin/pull"
#!/bin/sh

/etc/init.d/uwsgi-prod stop
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = False/settings.base.migrate = True/g' models/000_config.py
git reset --hard HEAD
git pull
rm -rf compiled
cd ~web2py
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd ~web2py
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
EOF
chmod +x /usr/local/bin/pull

cat << EOF > "/usr/local/bin/migrate"
#!/bin/sh
/etc/init.d/uwsgi-prod stop
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = False/settings.base.migrate = True/g' models/000_config.py
rm -rf compiled
cd ~web2py
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd ~web2py
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
EOF
chmod +x /usr/local/bin/migrate

cat << EOF > "/usr/local/bin/revert"
#!/bin/sh
git reset --hard HEAD
EOF
chmod +x /usr/local/bin/revert

cat << EOF > "/usr/local/bin/w2p"
#!/bin/sh
cd ~web2py
python web2py.py -S eden -M
EOF
chmod +x /usr/local/bin/w2p

cat << EOF2 > "/usr/local/bin/clean"
#!/bin/sh
/etc/init.d/uwsgi-prod stop
cd ~web2py/applications/eden
rm -rf databases/*
rm -f errors/*
rm -rf sessions/*
rm -rf uploads/*
pkill -f 'postgres: sahana sahana'
sudo -H -u postgres dropdb sahana
sed -i 's/settings.base.migrate = False/settings.base.migrate = True/g' models/000_config.py
sed -i 's/settings.base.prepopulate = 0/#settings.base.prepopulate = 0/g' models/000_config.py
rm -rf compiled
su -c - postgres "createdb -O sahana -E UTF8 sahana -T template0"
#su -c - postgres "createlang plpgsql -d sahana"
#su -c - postgres "psql -q -d sahana -f /usr/share/postgresql/9.6/extension/postgis--2.3.0.sql"
su -c - postgres "psql -q -d sahana -c 'CREATE EXTENSION postgis;'"
su -c - postgres "psql -q -d sahana -c 'grant all on geometry_columns to sahana;'"
su -c - postgres "psql -q -d sahana -c 'grant all on spatial_ref_sys to sahana;'"
cd ~web2py
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
sed -i 's/#settings.base.prepopulate = 0/settings.base.prepopulate = 0/g' models/000_config.py
cd ~web2py
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
if [ -e /home/data/import.py ]; then
    sudo -H -u web2py python web2py.py -S eden -M -R /home/data/import.py
fi
EOF2
chmod +x /usr/local/bin/clean

cat << EOF > "/usr/local/bin/pg1024"
#!/bin/sh
sed -i 's|kernel.shmmax = 279134208|#kernel.shmmax = 279134208|' /etc/sysctl.conf
sed -i 's|#kernel.shmmax = 552992768|kernel.shmmax = 552992768|' /etc/sysctl.conf
sysctl -w kernel.shmmax=552992768
sed -i 's|shared_buffers = 128MB|shared_buffers = 256MB|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|effective_cache_size = 256MB|effective_cache_size = 512MB|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|work_mem = 4MB|work_mem = 8MB|' /etc/postgresql/9.6/main/postgresql.conf
/etc/init.d/postgresql restart
EOF
chmod +x /usr/local/bin/pg1024

cat << EOF > "/usr/local/bin/pg512"
#!/bin/sh
sed -i 's|#kernel.shmmax = 279134208|kernel.shmmax = 279134208|' /etc/sysctl.conf
sed -i 's|kernel.shmmax = 552992768|#kernel.shmmax = 552992768|' /etc/sysctl.conf
sysctl -w kernel.shmmax=279134208
sed -i 's|shared_buffers = 256MB|shared_buffers = 128MB|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|effective_cache_size = 512MB|effective_cache_size = 256MB|' /etc/postgresql/9.6/main/postgresql.conf
sed -i 's|work_mem = 8MB|work_mem = 4MB|' /etc/postgresql/9.6/main/postgresql.conf
/etc/init.d/postgresql restart
EOF
chmod +x /usr/local/bin/pg512

apt-get clean

# END
