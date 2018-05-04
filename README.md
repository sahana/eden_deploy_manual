Deployment of Eden with Manual Scripts
--------------------------------------

http://eden.sahanafoundation.org/wiki/InstallationGuidelines/Linux/Server

These scripts can be used to deploy Eden on a single, usually virtual, machine running Debian Linux versions 7, 8 or 9

There are 2 alternative stacks:
* Cherokee + PostGIS
    install-eden-cherokee-postgis.sh
    configure-eden-cherokee-postgis.sh
    * There are installation scripts available for CentOS 6.9 as well. Run [install-eden-cherokee-postgis-centos-6.9-1.sh](https://github.com/sahana/eden_deploy_manual/blob/master/install-eden-cherokee-postgis-centos-6.9-1.sh "install-eden-cherokee-postgis-centos-6.9-1.sh"), [install-eden-cherokee-postgis-centos-6.9-2.sh](https://github.com/sahana/eden_deploy_manual/blob/master/install-eden-cherokee-postgis-centos-6.9-2.sh "install-eden-cherokee-postgis-centos-6.9-2.sh") and [configure-eden-cherokee-postgis-centos-6.9.sh](https://github.com/sahana/eden_deploy_manual/blob/master/configure-eden-cherokee-postgis-centos-6.9.sh "configure-eden-cherokee-postgis-centos-6.9.sh") in order. After installation, be sure to change the FQDN at the nginx configuration at /etc/nginx/nginx.conf and restart nginx by `/etc/init.d/nginx start`
    
* Apache + MySQL
    install-eden-apache-mysql.sh
    configure-eden-apache-mysql.sh

Alternative possibilities exist, but these scripts cannot be used as-is for that:
* Apache + PostGIS on a single, usually virtual, machine
* Cherokee + MySQL on a single, usually virtual, machine
* Cherokee + Eden on one machine + PostGIS on a second machine


Additional scripts:

* Add a Test instance to the same box as Production
    add_test_site.sh

* Add a Demo instance to the same box as Production/Test
    add_demo_site.sh

* Upgrade Web2Py from 2.14.6 to 2.16.1
    upgrade_web2py.sh
    fieldnames.py

