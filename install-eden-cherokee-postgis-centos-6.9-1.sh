#!/bin/bash

# To activate network
#ip addr show
#ifup <network>
#vi /etc/sysconfig/network-scripts/ifcfg-<network>
#edit autostart to yes

# Another app is currently using the yum lock
#ps aux | grep yum
#kill <PID number>

yum -y update

yum install -y lrzsz gcc zlib-devel bzip2-devel libxslt-devel ncurses ncurses-devel libtool gettext rrdtool
yum install -y redhat-lsb-core unixODBC unixODBC-devel libtool-ltdl-devel libtool wget
yum install -y mlocate
updatedb

# enable EPEL
#wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
#rpm -ivh epel-release-6-8.noarch.rpm
yum install -y epel-release centos-release-scl

yum install -y python27

cat << EOF >> "/etc/ld.so.conf"
/opt/rh/python27/root/usr/lib64
EOF
ldconfig

#enable it as bash
scl enable python27 bash
