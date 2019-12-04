#!/bin/bash

# Script to configure an Eden server
# - assumes that install-eden-nginx-postgis.sh has been run

# =============================================================================
# Check Debian version
#
read -d . DEBIAN < /etc/debian_version

case $DEBIAN in
    10)
        PYVERSION='3'
        ;;
    9 | 8)
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
echo -e "What domain name should we use? : \c "
read DOMAIN

echo -e "What host name should we use? : \c "
read HOSTNAME
SITENAME=$HOSTNAME".$DOMAIN"

echo -e "What template should we use? [default] : \c "
read TEMPLATE
if [[ ! "$TEMPLATE" ]]; then
    TEMPLATE="default"
fi

# Generate a random password
DBPASSWD=`pwgen -1 -A -n 16 -s`
echo "Note that web2py will not work with passwords with an @ in them"
echo -e "What is the new PostgreSQL password? [$DBPASSWD] \c "
read password
if [[ "$password" ]]; then
    DBPASSWD=$password
fi
echo "Using $DBPASSWD as password for PostgreSQL"

WEB2PY_HOME=/home/web2py
APPS_HOME=$WEB2PY_HOME/applications
EDEN_HOME=$APPS_HOME/eden

# =============================================================================
# Configure hostname
#
echo -n "Reconfigure system to use the hostname: $HOSTNAME..."

cd /etc
filename="hosts"
sed -i "s|localhost.localdomain localhost|$SITENAME $HOSTNAME localhost.localdomain localhost|" $filename

cd /etc
filename="hostname"
echo $HOSTNAME > $filename

cd /etc
filename="mailname"
echo $SITENAME > $filename

echo "Done"

# =============================================================================
# Update system (in case run at a much later time than the install script)
#
apt-get update
apt-get upgrade -y

# Disabled to ensure we keep Stable version from Install
#cd $WEB2PY_HOME
#git pull

cd $EDEN_HOME
git pull

# =============================================================================
# Configure MDA
#
echo "Configure MDA for internet mail delivery"
dpkg-reconfigure "exim4-config"

# =============================================================================
# Install and run certbot
#
case $DEBIAN in
    10)
        apt-get -y install "certbot" "python3-certbot-nginx"
        ;;
    9)
        cat <<EOF | sudo tee /etc/apt/sources.list.d/stretch-backports.list
deb http://http.debian.net/debian stretch-backports main contrib non-free
EOF
        apt-get update
        apt-get install "certbot" "python-certbot-nginx" -t stretch-backports
        ;;
    *)
        wget https://dl.eff.org/certbot-auto
        mv certbot-auto /usr/local/bin/certbot
        chmod 0755 /usr/local/bin/certbot
        cat << EOF > "/etc/cron.d/certbot"
0 0,12 * * * python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew
EOF
        ;;
esac
certbot --nginx

# =============================================================================
# Configure Nginx
#
echo "Configure Nginx web server"
NGINX_CONF=/etc/nginx/nginx.conf
sed -i "s|# gzip_vary on;|gzip_vary on;|" $NGINX_CONF
sed -i "s|# gzip_proxied any;|gzip_proxied expired no-cache no-store private auth;|" $NGINX_CONF
sed -i "s|# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;|gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;|" $NGINX_CONF
sed -i "s|#gzip_vary on;|gzip_vary on;|" $NGINX_CONF
sed -i "/gzip_vary on;/ a gzip_min_length 10240;" $NGINX_CONF
sed -i "s|gzip_min_length|\tgzip_min_length|" $NGINX_CONF

rm -f /etc/nginx/sites-enabled/default
cat << EOF > "/etc/nginx/sites-enabled/prod.conf"
server {
    listen      80;
    server_name $SITENAME;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen          443 ssl;
    server_name     $SITENAME;
    ssl_certificate /etc/letsencrypt/live/$SITENAME/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$SITENAME/privkey.pem; # managed by Certbot
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    location /crossdomain.xml {
        alias $EDEN_HOME/static/crossdomain.xml;
        expires max;
    }
    location /favicon.ico {
        alias $EDEN_HOME/static/favicon.ico;
        expires max;
    }
    location /robots.txt {
        alias $EDEN_HOME/static/robots.txt;
        expires max;
    }
    location /eden/static/ {
        alias $EDEN_HOME/static/;
        expires max;
    }
    location /eden/static/img/ {
        alias $EDEN_HOME/static/img/;
        gzip off;
        expires max;
    }
    # to enable correct use of response.static_version?
    location /static/ {
        alias $EDEN_HOME/static/;
        expires max;
    }
    location / {
        uwsgi_pass      127.0.0.1:59025;
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
EOF

service nginx restart

# =============================================================================
# Configure Sahana Eden
#
echo -n "Create Sahana config file from template..."
rm -rf $EDEN_HOME/databases/*
rm -rf $EDEN_HOME/errors/*
rm -rf $EDEN_HOME/sessions/*
cp $EDEN_HOME/modules/templates/000_config.py $EDEN_HOME/models

CONFIG=$EDEN_HOME/models/000_config.py

sed -i "s|settings.base.template = \"default\"|settings.base.template = \"$TEMPLATE\"|" $CONFIG
sed -i 's|EDITING_CONFIG_FILE = False|EDITING_CONFIG_FILE = True|' $CONFIG

# Create a unique HMAC key for password encryption
UUID=`python -c $'import uuid\nprint(uuid.uuid4())'`
sed -i "s|akeytochange|$UUID|" $CONFIG
sed -i "s|#settings.base.public_url = \"http://127.0.0.1:8000\"|settings.base.public_url = \"http://$SITENAME\"|" $CONFIG
sed -i 's|#settings.base.cdn = True|settings.base.cdn = True|' $CONFIG
echo "Done"

# =============================================================================
# Configure PostgreSQL
#
echo "Create Sahana database"
echo "CREATE USER sahana WITH PASSWORD '$DBPASSWD';" > /tmp/pgpass.sql
su -c - postgres "psql -q -d template1 -f /tmp/pgpass.sql"
rm -f /tmp/pgpass.sql
su -c - postgres "createdb -O sahana -E UTF8 sahana -T template0"
#su -c - postgres "createlang plpgsql -d sahana"

# =============================================================================
# Set up PostGIS
#
echo "Setting up PostGIS"
su -c - postgres "psql -q -d sahana -c 'CREATE EXTENSION postgis;'"
su -c - postgres "psql -q -d sahana -c 'GRANT ALL ON geometry_columns TO sahana;'"
su -c - postgres "psql -q -d sahana -c 'GRANT ALL ON spatial_ref_sys TO sahana;'"

# =============================================================================
# Update DB settings in Eden config
#
echo -n "Update Eden config for database..."
sed -i 's|#settings.database.db_type = "postgres"|settings.database.db_type = "postgres"|' $CONFIG
sed -i "s|#settings.database.password = \"password\"|settings.database.password = \"$DBPASSWD\"|" $CONFIG
sed -i 's|#settings.gis.spatialdb = True|settings.gis.spatialdb = True|' $CONFIG
echo "Done"

# =============================================================================
# Create the Tables & Populate with base data (=first run)
#
sed -i 's|settings.base.migrate = False|settings.base.migrate = True|' $CONFIG
cd $WEB2PY_HOME
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py

# =============================================================================
# Re-configure for production
#
echo -n "Re-configure Eden for production mode..."
sed -i 's|#settings.base.prepopulate = 0|settings.base.prepopulate = 0|' $CONFIG
sed -i 's|settings.base.migrate = True|settings.base.migrate = False|' $CONFIG
echo "Done"

# =============================================================================
# Compile application
#
echo "Compile Eden"
cd $WEB2PY_HOME
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py

# =============================================================================
# Configure nightly backups (use cron.d rather than modifying main crontab)
#
echo -n "Schedule nightly backups..."
# Schedule backups for 02:01 daily
if [ ! -e /etc/cron.d/sahana ]; then
    cat << EOF > "/etc/cron.d/sahana"
1 2   * * *   root   /usr/local/bin/backup >/dev/null 2>&1
EOF
    echo "Done"
else
    echo "backup already configured [SKIP]"
fi

# =============================================================================
# Reboot
#
#read -p "Press any key to Reboot..."
echo "Now rebooting.."
reboot

# END
