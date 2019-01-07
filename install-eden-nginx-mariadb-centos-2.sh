#!/bin/bash

# Determine CentOS version (script supports 6 & 7)
CENTOS=$(cat /etc/centos-release | tr -dc '0-9.'|cut -d \. -f1)

# Enable software collection in bash:
# https://access.redhat.com/solutions/527703
#scl enable python27 bash

pip2.7 install --upgrade pip

pip2.7 install Image
pip2.7 install lxml
pip2.7 install python-dateutil
pip2.7 install pyserial
pip2.7 install matplotlib
pip2.7 install requests
pip2.7 install xlwt
pip2.7 install reportlab
pip2.7 install ipython

yum groupinstall -y 'Development Tools'

yum install -y geos-devel
pip2.7 install shapely
pip2.7 install xlrd
#yum install -y mod_wsgi

#########
# Web2Py
#########
adduser --system web2py
#groupadd web2py
cd /home
env GIT_SSL_NO_VERIFY=true git clone --recursive https://github.com/web2py/web2py.git
cd web2py
# 2.16.1
#git reset --hard 7035398
# 2.17.1
git reset --hard 285013a
git submodule update --init --recursive
# Fix for 2.16.1
#sed -i "s|credential_decoder = lambda cred: urllib.unquote(cred)|credential_decoder = lambda cred: unquote(cred)|" /home/web2py/gluon/packages/dal/pydal/base.py
ln -s /home/web2py ~
cp -f /home/web2py/handlers/wsgihandler.py /home/web2py

cat << EOF > "/home/web2py/routes.py"
#!/opt/rh/python27/root/usr/bin/python
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
# @ToDo: fix this
#sed -i 's|TkAgg|Agg|' /etc/matplotlibrc

##############
# Sahana Eden
##############
# Install Sahana Eden
cd /home/web2py
cd applications
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
yum install -y nginx

##########
# uwsgi
##########
cd /tmp
curl -L -O http://projects.unbit.it/downloads/uwsgi-1.9.18.2.tar.gz
tar zxvf uwsgi-1.9.18.2.tar.gz
cd uwsgi-1.9.18.2
/opt/rh/python27/root/usr/bin/python uwsgiconfig.py --build pyonly.ini
cp uwsgi /usr/local/bin

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
#!/opt/rh/python27/root/usr/bin/python
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
chdir = /home/web2py/
module = wsgihandler
mule = run_scheduler.py
pythonpath = /home/web2py/site-packages
pythonpath = /home/web2py
pythonpath = /opt/rh/python27/root/usr/lib64/python27.zip
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7/plat-linux2
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7/lib-tk
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7/lib-old
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7/lib-dynload
pythonpath = /opt/rh/python27/root/usr/lib64/python2.7/site-packages
pythonpath = /opt/rh/python27/root/usr/lib/python2.7/site-packages
pythonpath = /home/web2py/gluon/packages/dal
workers = 4
cheap = true
idle = 1000
harakiri = 1000
pidfile = /tmp/uwsgi-prod.pid
daemonize = /var/log/uwsgi/prod.log
socket = 127.0.0.1:9001
master = true
chmod-socket = 666
chown-socket = web2py:nginx
EOF

touch /tmp/uwsgi-prod.pid
chown web2py:nginx /tmp/uwsgi-prod.pid

mkdir -p /var/log/uwsgi
chown web2py:nginx /var/log/uwsgi

# Init script for uwsgi

cat << EOF > "/etc/init.d/uwsgi-prod"
#!/bin/bash
#
# chkconfig: 235 95 05
#

# Source function library
. /etc/rc.d/init.d/functions

uwsgi=/usr/local/bin/uwsgi
prog=uwsgi
lockfile=/var/lock/subsys/uwsgi
pid=/tmp/uwsgi-prod.pid
args="/home/web2py/uwsgi.ini"
RETVAL=0

start() {
    echo -n $"Starting \$prog: "
    daemon \$uwsgi --pidfile \$pid -- \$args
    RETVAL=$?
    echo
    [ \$RETVAL = 0 ] && touch \$lockfile
    return \$RETVAL
}

stop() {
    echo -n $"Stopping \$prog: "
    killproc -p \$pid \$prog
    RETVAL=$?
    echo
    [ \$RETVAL = 0 ] && rm -rf \$lockfile \$pid
}

reload() {
    echo -n $"Reloading \$prog" 
    killproc -p \$pid \$prog -HUP
    RETVAL=$?
    echo
}

rh_status() {
    status -p \$pid \$uwsgi
}

case \$1 in
  start)
	start
	;;
  stop)
    stop
    ;;
  reload)
    reload
    ;;
  restart)
	stop
    start
    ;;
  status)  
    rh_status
    RETVAL=$?
    ;;
  *)  
        echo $"Usage: \$prog {start|stop|restart|reload|status}"
        RETVAL=2
esac
exit 0
EOF

chmod a+x /etc/init.d/uwsgi-prod
/etc/init.d/uwsgi-prod start
chkconfig --levels 235 uwsgi-prod on


# Setting for nginx
cat << EOF > "/etc/nginx/nginx.conf"
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /var/run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections  1024;
}


http {
    server_names_hash_bucket_size 128;
    access_log  /var/log/nginx/access.log;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen          80;
        server_name     <your-FQDN>;
        #to enable correct use of response.static_version
        location /static/ {
            alias /home/web2py/applications/eden/static/;
            expires max;
        }
        location / {
            uwsgi_pass      127.0.0.1:9001;
            #uwsgi_pass      unix:///var/www/web2py/logs/web2py.socket;
            include         /etc/nginx/uwsgi_params;
            uwsgi_param     UWSGI_SCHEME \$scheme;
            uwsgi_param     SERVER_SOFTWARE    nginx/\$nginx_version;
            ### remove the comments if you use uploads (max 10 MB)
            client_max_body_size 10m;
            ###
	    port_in_redirect off;
	    proxy_redirect off;
        }
    }
}
EOF

service iptables stop
chkconfig --del iptables

chkconfig --levels 235 nginx on

# manage permissions
chmod 755 /usr/local/bin/uwsgi
#chmod 710 /home/web2py/
usermod -a -G web2py nginx
chmod -R u+wx /home/web2py/applications

# SELinux: Allow nginx to access uwsgi
# https://stackoverflow.com/questions/23948527/13-permission-denied-while-connecting-to-upstreamnginx
setsebool -P httpd_can_network_connect 1
#setsebool -P httpd_can_network_connect_db 1

service nginx start

#########
# MariaDB
#########
yum install mariadb-server python-mysqldb

# Tune for smaller RAM setups
sed -i 's|query_cache_size        = 16M|query_cache_size = 1M|' /etc/mysql/my.cnf
sed -i 's|key_buffer              = 16M|key_buffer = 1M|' /etc/mysql/my.cnf
sed -i 's|max_allowed_packet      = 16M|max_allowed_packet = 1M|' /etc/mysql/my.cnf

systemctl start mariadb
systemctl enable mariadb

echo 'Answer Yes to all questions asked by MySQL Secure Installation'
mysql_secure_installation

#####################
# Management scripts
#####################
cat << EOF > "/usr/local/bin/backup"
#!/bin/sh
mkdir /var/backups/eden
NOW=\$(date +"%Y-%m-%d")
mysqldump sahana > /var/backups/eden/backup-\$NOW.sql
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
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
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
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
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
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
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
/opt/rh/python27/root/usr/bin/python web2py.py -S eden -M
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
mysqladmin -f drop sahana
mysqladmin create sahana
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py
cd ~web2py/applications/eden
sed -i 's/settings.base.migrate = True/settings.base.migrate = False/g' models/000_config.py
sed -i 's/#settings.base.prepopulate = 0/settings.base.prepopulate = 0/g' models/000_config.py
cd ~web2py
sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py
/etc/init.d/uwsgi-prod start
if [ -e /home/data/import.py ]; then
    sudo -H -u web2py /opt/rh/python27/root/usr/bin/python web2py.py -S eden -M -R /home/data/import.py
fi
EOF2
chmod +x /usr/local/bin/clean
