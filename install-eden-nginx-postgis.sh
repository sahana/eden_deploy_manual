#!/bin/bash

# Script to turn a generic Debian 8, 9 or 10 box into an Eden server
# - with Nginx & PostgreSQL
# - tunes PostgreSQL for 1Gb RAM (e.g. Amazon Small or greater)
# - run pg512 to tune for 512Mb RAM (e.g. Amazon Micro (free tier))

# =============================================================================
# Check Debian version
#
read -d . DEBIAN < /etc/debian_version

case $DEBIAN in
    10)
        DEBIAN_NAME='buster'
        PYVERSION='3'
        ;;
    9)
        DEBIAN_NAME='stretch'
        PYVERSION='2'
        ;;
    8)
        DEBIAN_NAME='jessie'
        PYVERSION='2'
        ;;
    *)
        echo "Unsupported Debian version"
        exit 1
        ;;
esac

# =============================================================================
# Global variables
#
echo -e "Which Sahana Eden repository should we clone? [sahana/eden-stable] : \c "
read EDEN_REPO
if [[ ! "$EDEN_REPO" ]]; then
    # Default to stable
    EDEN_REPO=sahana/eden-stable
fi

WEB2PY_HOME=/home/web2py
APPS_HOME=$WEB2PY_HOME/applications
EDEN_HOME=$APPS_HOME/eden

# =============================================================================
# Update system
#
apt-get update
apt-get -y upgrade
apt-get clean

# =============================================================================
# Install Admin Tools
#
apt-get -y install "curl" "dos2unix" "htop" "lrzsz" "mlocate" "p7zip" "psmisc" "pwgen" "rcconf" "sudo" "telnet" "unzip" "vim"
case $DEBIAN in
    10 | 9)
        apt-get -y install "elinks" "net-tools"
        ;;
    *)
        apt-get -y install "elinks-lite"
        ;;
esac
apt-get clean

# =============================================================================
# Install Git
#
apt-get -y install "git-core"
apt-get clean

# =============================================================================
# Install MDA
#
apt-get -y install "exim4-config" "exim4-daemon-light"
apt-get clean

# =============================================================================
# Install Libraries
#

## C Libraries
case $DEBIAN in
    10 | 9)
        apt-get -y install "libgeos-c1v5"
        ;;
    *)
        apt-get -y install "libgeos-c1"
        ;;
esac
apt-get install "libgeos-dev" "libodbc1"
apt-get clean

## Python Libraries
if [ $PYVERSION == '2' ]; then
    apt-get -y install "python-dev" "python-pip" "python-setuptools"
    PIP=pip
    #apt-get -y install "python-lxml" "python-dateutil"
    apt-get -y install "python-serial"
    #apt-get -y install "python-imaging"
    #apt-get -y install "python-matplotlib"
    #apt-get -y install "python-requests"
    #apt-get -y install "python-xlwt"
else
    apt-get -y install "python3-dev" "python3-pip" "python3-setuptools"
    PIP=pip3
    #apt-get -y install "python3-lxml" "python3-dateutil"
    apt-get -y install "python3-serial"
    #apt-get -y install "python3-pil"
    #apt-get -y install "python3-matplotlib"
    #apt-get -y install "python3-requests"
    #apt-get -y install "python3-xlwt"
fi
apt-get clean

apt-get -y install "build-essential"
apt-get clean

$PIP install lxml
$PIP install python-dateutil
$PIP install pillow
$PIP install requests
$PIP install xlwt

$PIP install geopy
$PIP install reportlab
$PIP install shapely
$PIP install xlrd

# =============================================================================
# Install web2py
#
# TODO catch existing installation

## Set up web2py user+group
adduser --system --disabled-password web2py
addgroup web2py

## Clone web2py from trunk
cd /home
env GIT_SSL_NO_VERIFY=true git clone --recursive https://github.com/web2py/web2py.git
cd web2py

## Reset to stable
# 2.18.3
# git reset --hard 6128d03
# 2.18.5
git reset --hard 59700b8
git submodule update --init --recursive

## Patch web2py/PyDAL/YATL
# Fix for 2.18.3
# sed -i "s|from urllib import FancyURLopener, urlencode, urlopen|from urllib import FancyURLopener, urlencode|" $WEB2PY_HOME/gluon/packages/dal/pydal/_compat.py
# sed -i "/urllib_quote_plus/ a \ \ \ \ from urllib2 import urlopen" $WEB2PY_HOME/gluon/packages/dal/pydal/_compat.py

# Fix for 2.18.5
sed -i "s|if getattr(func, 'validate', None) is Validator.validate:|if getattr(func, 'validate', None) is not Validator.validate:|" $WEB2PY_HOME/gluon/packages/dal/pydal/validators.py

## Create symbolic link in /root
ln -s $WEB2PY_HOME ~

## Copy WSGI handler to web2py home
cp -f $WEB2PY_HOME/handlers/wsgihandler.py $WEB2PY_HOME

# =============================================================================
# Post-install web2py
#

## Error routes
cat << EOF > "$WEB2PY_HOME/routes.py"
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

## Scheduler start script
cat << EOF > "$WEB2PY_HOME/run_scheduler.py"
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

# =============================================================================
# Configure Matplotlib
#
mkdir $WEB2PY_HOME/.matplotlib
chown web2py $WEB2PY_HOME/.matplotlib
echo "os.environ['MPLCONFIGDIR'] = '$WEB2PY_HOME/.matplotlib'" >> $WEB2PY_HOME/wsgihandler.py
sed -i 's|TkAgg|Agg|' /etc/matplotlibrc

# =============================================================================
# Install Sahana Eden
#
# TODO catch existing installation

## Install Sahana Eden
cd $APPS_HOME
env GIT_SSL_NO_VERIFY=true git clone https://github.com/$EDEN_REPO.git eden

# Create missing directories and fix permissions
chown web2py $WEB2PY_HOME
declare -a ADMINDIRS=("cache"
                      "cron"
                      "databases"
                      "errors"
                      "sessions"
                      "uploads"
                      )
for i in "${ADMINDIRS[@]}"
do
    if [ ! -d "$i" ]; then
        mkdir -p $APPS_HOME/admin/$i
    fi
    chown web2py $APPS_HOME/admin/$i
done

chown web2py $EDEN_HOME
declare -a EDENDIRS=("cache"
                     "cron"
                     "databases"
                     "models"
                     "errors"
                     "sessions"
                     "static/fonts"
                     "static/img/markers"
                     "static/cache/chart"
                     "uploads"
                     "uploads/gis_cache"
                     "uploads/images"
                     "uploads/tracks"
                     )
for i in "${EDENDIRS[@]}"
do
    if [ ! -d "$i" ]; then
        mkdir -p $EDEN_HOME/$i
    fi
    chown -R web2py $EDEN_HOME/$i
done

# Create symbolic links
ln -s $EDEN_HOME $WEB2PY_HOME
ln -s $EDEN_HOME ~

# =============================================================================
# Install Nginx web server
#
apt-get -y install nginx
apt-get clean

# =============================================================================
# Install uWSGI
#
cd /tmp
wget https://projects.unbit.it/downloads/uwsgi-2.0.18.tar.gz
tar zxvf uwsgi-2.0.18.tar.gz
cd uwsgi-2.0.18
python uwsgiconfig.py --build pyonly
cp uwsgi /usr/local/bin

# =============================================================================
# Post-install uWSGI
#

## Configure logrotate for uWSGI
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

## UWSGI parameter file
cat << EOF > "$WEB2PY_HOME/uwsgi.ini"
[uwsgi]
uid = web2py
gid = web2py
chdir = $WEB2PY_HOME/
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

## PID file and log file directory
touch /tmp/uwsgi-prod.pid
chown web2py:www-data /tmp/uwsgi-prod.pid

mkdir -p /var/log/uwsgi
chown web2py:www-data /var/log/uwsgi

## Init script for uwsgi
# TODO Proper LSB tags
cat << EOF > "/etc/init.d/uwsgi-prod"
#! /bin/bash
# /etc/init.d/uwsgi-prod
#

daemon=/usr/local/bin/uwsgi
pid=/tmp/uwsgi-prod.pid
args="$WEB2PY_HOME/uwsgi.ini"

# Carry out specific functions when asked to by the system
case "\$1" in
    start)
        echo "Starting uwsgi"
        start-stop-daemon -p \$pid --start --exec \$daemon --user web2py -- \$args
        ;;
    stop)
        echo "Stopping script uwsgi"
        start-stop-daemon --signal INT -p \$pid --stop \$daemon --user web2py -- \$args
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

# =============================================================================
# Install PostgreSQL
#
cat << EOF > "/etc/apt/sources.list.d/pgdg.list"
deb http://apt.postgresql.org/pub/repos/apt/ $DEBIAN_NAME-pgdg main
EOF

wget --no-check-certificate https://www.postgresql.org/media/keys/ACCC4CF8.asc
apt-key add ACCC4CF8.asc
apt-get update

case $DEBIAN in
    10)
        apt-get -y install "postgresql-11" "pgtop"
        apt-get -y install "postgresql-11-postgis-2.5"
        PGHOME=/etc/postgresql/11
        ;;
    *)
        # Psycopg2 versions in stretch/jessie can have problems with PG10+
        apt-get -y install "postgresql-9.6" "ptop" "pgtop"
        apt-get -y install "postgresql-9.6-postgis-2.3"
        PGHOME=/etc/postgresql/9.6
        ;;
esac

if [ $PYVERSION == '2' ]; then
    apt-get -y install "python-psycopg2"
else
    apt-get -y install "python3-psycopg2"
fi

# =============================================================================
# Tune PostgreSQL
#
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

PGCONFIG=$PGHOME/main/postgresql.conf

sed -i 's|#track_counts = on|track_counts = on|' $PGCONFIG
sed -i 's|#autovacuum = on|autovacuum = on|' $PGCONFIG
sed -i 's|max_connections = 100|max_connections = 20|' $PGCONFIG
# 1024Mb RAM: (e.g. t2.micro)
sed -i 's|#effective_cache_size = 4GB|effective_cache_size = 512MB|' $PGCONFIG
sed -i 's|#work_mem = 4MB|work_mem = 8MB|' $PGCONFIG
# If only 512 RAM, activate post-install via pg512 script

service postgresql restart

# =============================================================================
# Service scripts
#
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
tar -cf /var/backups/eden/uploads/uploadsprod-\$NOW.tar -C $EDEN_HOME  ./uploads
bzip2 /var/backups/eden/uploads/uploadsprod-\$NOW.tar
rm -f /var/backups/eden/uploads/uploadsprod-\$OLD.tar.bz2
EOF
chmod +x /usr/local/bin/backup

cat << EOF > "/usr/local/bin/compile"
#!/bin/bash
/etc/init.d/uwsgi-prod stop
cd $WEB2PY_HOME
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
EOF
chmod +x /usr/local/bin/compile

cat << EOF > "/usr/local/bin/pull"
#!/bin/sh

/etc/init.d/uwsgi-prod stop
cd $EDEN_HOME
sed -i 's/settings.base.migrate = False/settings.base.migrate = True/g' models/000_config.py
git reset --hard HEAD
git pull
rm -rf compiled
cd $WEB2PY_HOME
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd $EDEN_HOME
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd $WEB2PY_HOME
python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
EOF
chmod +x /usr/local/bin/pull

cat << EOF > "/usr/local/bin/migrate"
#!/bin/sh
/etc/init.d/uwsgi-prod stop
cd $EDEN_HOME
sed -i 's/settings.base.migrate = False/settings.base.migrate = True/g' models/000_config.py
rm -rf compiled
cd $WEB2PY_HOME
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd $EDEN_HOME
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd $WEB2PY_HOME
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
cd $WEB2PY_HOME
python web2py.py -S eden -M
EOF
chmod +x /usr/local/bin/w2p

cat << EOF2 > "/usr/local/bin/clean"
#!/bin/sh
/etc/init.d/uwsgi-prod stop
cd $EDEN_HOME
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
cd $WEB2PY_HOME
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd $EDEN_HOME
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
sed -i 's/#settings.base.prepopulate = 0/settings.base.prepopulate = 0/g' models/000_config.py
cd $WEB2PY_HOME
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
sed -i 's|shared_buffers = 128MB|shared_buffers = 256MB|' $PGHOME/main/postgresql.conf
sed -i 's|effective_cache_size = 256MB|effective_cache_size = 512MB|' $PGHOME/main/postgresql.conf
sed -i 's|work_mem = 4MB|work_mem = 8MB|' $PGHOME/main/postgresql.conf
/etc/init.d/postgresql restart
EOF
chmod +x /usr/local/bin/pg1024

cat << EOF > "/usr/local/bin/pg512"
#!/bin/sh
sed -i 's|#kernel.shmmax = 279134208|kernel.shmmax = 279134208|' /etc/sysctl.conf
sed -i 's|kernel.shmmax = 552992768|#kernel.shmmax = 552992768|' /etc/sysctl.conf
sysctl -w kernel.shmmax=279134208
sed -i 's|shared_buffers = 256MB|shared_buffers = 128MB|' $PGHOME/main/postgresql.conf
sed -i 's|effective_cache_size = 512MB|effective_cache_size = 256MB|' $PGHOME/main/postgresql.conf
sed -i 's|work_mem = 8MB|work_mem = 4MB|' $PGHOME/main/postgresql.conf
/etc/init.d/postgresql restart
EOF
chmod +x /usr/local/bin/pg512

# =============================================================================
apt-get clean

# END
