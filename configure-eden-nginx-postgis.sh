#!/bin/bash

# Script to configure an Eden server
# - assumes that install-eden-nginx-postgis.sh has been run

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
echo -e "What is the new PostgreSQL password: \c "
read password

echo "Now reconfiguring system to use the hostname: $hostname"

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
apt-get update
apt-get upgrade -y
# Disabled to ensure we keep Stable version from Install
#cd ~web2py
#git pull
cd ~web2py/applications/eden
git pull
# -----------------------------------------------------------------------------
# Email
# -----------------------------------------------------------------------------
echo configure for Internet mail delivery
dpkg-reconfigure exim4-config

# Certbot
# Which OS are we running?
read -d . DEBIAN < /etc/debian_version

if [[ $DEBIAN == '9' ]]; then
    cat <<EOF | sudo tee /etc/apt/sources.list.d/stretch-backports.list
deb http://http.debian.net/debian stretch-backports main contrib non-free
EOF
    apt-get update
    apt-get install certbot python-certbot-nginx -t stretch-backports
else
    # 7 or 8
    wget https://dl.eff.org/certbot-auto
    mv certbot-auto /usr/local/bin/certbot
    chmod 0755 /usr/local/bin/certbot
    cat << EOF > "/etc/cron.d/certbot"
0 0,12 * * * python -c 'import random; import time; time.sleep(random.random() * 3600)' && /usr/local/bin/certbot-auto renew 
EOF
fi
certbot --nginx

# Configure Nginx
sed -i "s|# gzip_vary on;|gzip_vary on;|" /etc/nginx/nginx.conf
sed -i "s|# gzip_proxied any;|gzip_proxied expired no-cache no-store private auth;|" /etc/nginx/nginx.conf
sed -i "s|# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;|gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;|" /etc/nginx/nginx.conf
sed -i "s|#gzip_vary on;|gzip_vary on;|" /etc/nginx/nginx.conf
sed -i "/gzip_vary on;/ a gzip_min_length 10240;" /etc/nginx/nginx.conf
sed -i "s|gzip_min_length|\tgzip_min_length|" /etc/nginx/nginx.conf

rm /etc/nginx/sites-enabled/default
cat << EOF > "/etc/nginx/sites-enabled/prod.conf"
server {
    listen      80;
    server_name $sitename;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen          443 ssl;
    server_name     $sitename;
    ssl_certificate /etc/letsencrypt/live/$sitename/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/$sitename/privkey.pem; # managed by Certbot
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    location /crossdomain.xml {
        alias /home/web2py/applications/eden/static/crossdomain.xml;
        expires max;
    }
    location /favicon.ico {
        alias /home/web2py/applications/eden/static/favicon.ico;
        expires max;
    }
    location /robots.txt {
        alias /home/web2py/applications/eden/static/robots.txt;
        expires max;
    }
    location /eden/static/ {
        alias /home/web2py/applications/eden/static/;
        expires max;
    }
    location /eden/static/img/ {
        alias /home/web2py/applications/eden/static/img/;
        gzip off;
        expires max;
    }
    # to enable correct use of response.static_version?
    location /static/ {
        alias /home/web2py/applications/eden/static/;
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

# -----------------------------------------------------------------------------
# Sahana Eden
# -----------------------------------------------------------------------------
echo "Setting up Sahana"

# Copy Templates
cp ~web2py/applications/eden/modules/templates/000_config.py ~web2py/applications/eden/models

sed -i "s|settings.base.template = \"default\"|settings.base.template = \"$template\"|" ~web2py/applications/eden/models/000_config.py
sed -i 's|EDITING_CONFIG_FILE = False|EDITING_CONFIG_FILE = True|' ~web2py/applications/eden/models/000_config.py
sed -i "s|akeytochange|$sitename$password|" ~web2py/applications/eden/models/000_config.py
sed -i "s|#settings.base.public_url = \"http://127.0.0.1:8000\"|settings.base.public_url = \"http://$sitename\"|" ~web2py/applications/eden/models/000_config.py
sed -i 's|#settings.base.cdn = True|settings.base.cdn = True|' ~web2py/applications/eden/models/000_config.py

# PostgreSQL
echo "CREATE USER sahana WITH PASSWORD '$password';" > /tmp/pgpass.sql
su -c - postgres "psql -q -d template1 -f /tmp/pgpass.sql"
rm -f /tmp/pgpass.sql
su -c - postgres "createdb -O sahana -E UTF8 sahana -T template0"
#su -c - postgres "createlang plpgsql -d sahana"

# PostGIS
#su -c - postgres "psql -q -d sahana -f /usr/share/postgresql/9.6/extension/postgis--2.3.0.sql"
su -c - postgres "psql -q -d sahana -c 'CREATE EXTENSION postgis;'"
su -c - postgres "psql -q -d sahana -c 'GRANT ALL ON geometry_columns TO sahana;'"
su -c - postgres "psql -q -d sahana -c 'GRANT ALL ON spatial_ref_sys TO sahana;'"

# Configure Database
sed -i 's|#settings.database.db_type = "postgres"|settings.database.db_type = "postgres"|' ~web2py/applications/eden/models/000_config.py
sed -i "s|#settings.database.password = \"password\"|settings.database.password = \"$password\"|" ~web2py/applications/eden/models/000_config.py
sed -i 's|#settings.gis.spatialdb = True|settings.gis.spatialdb = True|' ~web2py/applications/eden/models/000_config.py

# Create the Tables & Populate with base data
sed -i 's|settings.base.migrate = False|settings.base.migrate = True|' ~web2py/applications/eden/models/000_config.py
cd ~web2py
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/noop.py

# Configure for Production
sed -i 's|#settings.base.prepopulate = 0|settings.base.prepopulate = 0|' ~web2py/applications/eden/models/000_config.py
sed -i 's|settings.base.migrate = True|settings.base.migrate = False|' ~web2py/applications/eden/models/000_config.py
cd ~web2py
sudo -H -u web2py python web2py.py -S eden -M -R applications/eden/static/scripts/tools/compile.py

# Schedule backups for 02:01 daily
echo "1 2   * * * root    /usr/local/bin/backup" >> "/etc/crontab"

#read -p "Press any key to Reboot..."
echo "Now rebooting.."
reboot

# END
