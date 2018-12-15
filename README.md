Deployment of Eden with Manual Scripts
--------------------------------------

http://eden.sahanafoundation.org/wiki/InstallationGuidelines/Linux/Server

These scripts can be used to deploy Eden on a single, usually virtual, machine.

There are 3 alternative stacks:
* Cherokee + PostGIS (on Debian Linux versions 7, 8 or 9)
    install-eden-cherokee-postgis.sh
    configure-eden-cherokee-postgis.sh
    
* Apache + MySQL (on Debian Linux versions 7, 8 or 9)
    install-eden-apache-mysql.sh
    configure-eden-apache-mysql.sh

* nginx + PostGIS (on CentOS version 6.9/7)
    install-eden-nginx-postgis-centos-1.sh
    install-eden-nginx-postgis-centos-2.sh
    configure-eden-nginx-postgis-centos.sh
    After installation, be sure to change the FQDN at the nginx configuration at /etc/nginx/nginx.conf and restart nginx by `/etc/init.d/nginx start`

Alternative possibilities exist, but these scripts cannot be used as-is for that:
* Apache + PostGIS on a single, usually virtual, machine
* Cherokee + MySQL on a single, usually virtual, machine
* Cherokee + Eden on one machine + PostGIS on a second machine


Additional scripts (Debian-only):

* Add a Test instance to the same box as Production
    add_test_site.sh

* Add a Demo instance to the same box as Production/Test
    add_demo_site.sh

* Upgrade Web2Py from 2.14.6 to 2.16.1
    upgrade_web2py.sh
    fieldnames.py

