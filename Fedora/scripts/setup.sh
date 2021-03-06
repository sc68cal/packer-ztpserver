#!/bin/sh -x

# enable delta RPM's to make yum faster
yum -y install deltarpm

# grab updates and cleanup
yum -y update yum
yum -y update

# install ztps-related related packages
yum -y install python-pip
yum -y install mod_wsgi
yum -y install tar
yum -y install wget
yum -y install libyaml libyaml-devel
yum -y install screen
yum -y install git
yum -y install net-tools
yum -y install tcpdump
yum -y install lldpad
yum -y install httpd
yum -y install dhcp
yum -y install bind bind-utils
yum -y install ejabberd
yum -y install rsyslog
yum -y install ntp


######################################
# Configure tty
######################################
#enable serial console:
# enable serial console
systemctl start serial-getty@ttyS0.service
# systemctl enable serial-getty@ttyS0.service
ln -s /usr/lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@ttyS0.service

#enable boot logging to console:
sed -i '/append/ s/$/ console=tty0 console=ttyS0,9600 net.ifnames=0/' /etc/extlinux.conf
sed -i '/append/ s/$/ console=tty0 console=ttyS0,9600 net.ifnames=0/' /boot/extlinux/extlinux.conf

#enable login on serial console
echo 'ttyS0' >> /etc/securetty

######################################
# CONFIGURE FIREWALLd
######################################
# disable firewalld
systemctl disable firewalld.service
systemctl stop firewalld.service
firewall-cmd --state
ifconfig

######################################
# CONFIGURE LLDP
######################################
systemctl start lldpad
systemctl enable lldpad
lldptool -L -i eth1 adminStatus=rxtx
lldptool -T -i eth1 -V sysName enableTx=yes
lldptool -T -i eth1 -V sysDesc enableTx=yes

######################################
# CONFIGURE SCREEN
######################################
cp /tmp/packer/screenrc /home/ztpsadmin/.screenrc
cp /tmp/packer/screenrc /root/.screenrc

######################################
# CONFIGURE rsyslog
######################################
mv /etc/rsyslog.conf /etc/rsyslog.conf.bak
cp /tmp/packer/rsyslog.conf /etc/rsyslog.conf
systemctl restart rsyslog.service
netstat -tuplen | grep syslog

######################################
# CONFIGURE ntp
######################################
cp /tmp/packer/ntp.conf /etc/ntp.conf
echo -e "#Generated by packer (EOS+) to limit ntp to eth1\nOPTIONS=\"-g -I eth1\"" > /etc/sysconfig/ntpd
systemctl restart ntpd.service
systemctl enable ntpd.service

######################################
# CONFIGURE eJabberd
######################################
mv /etc/ejabberd/ejabberd.cfg /etc/ejabberd/ejabberd.cfg.bak
cp /tmp/packer/ejabberd.cfg /etc/ejabberd/ejabberd.cfg
echo -e "127.0.0.1 ztps ztps.ztps-test.com" >> /etc/hosts
ejabberdctl start
sleep 2
ejabberdctl status
systemctl enable ejabberd.service
ejabberdctl register cvx im.ztps-test.com eosplus
ejabberdctl register ztpsadmin im.ztps-test.com eosplus
ejabberdctl register bootstrap im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor1 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor2 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor3 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor4 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor5 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-tor6 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-spine1 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-spine2 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-spine3 im.ztps-test.com eosplus
ejabberdctl register veos-dc1-pod1-spine4 im.ztps-test.com eosplus
ejabberdctl restart
sleep 6
ejabberdctl status

######################################
# CONFIGURE APACHE
######################################
mv /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
cp /tmp/packer/httpd.conf /etc/httpd/conf/httpd.conf

######################################
# CONFIGURE BIND
######################################
mv /etc/named.conf /etc/named.conf.bak
cp /tmp/packer/named.conf /etc/named.conf
cp /tmp/packer/ztps-test.com.zone /var/named/
service named restart
systemctl enable named.service
systemctl status named.service

######################################
# CONFIGURE DHCP
######################################
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
cp /tmp/packer/dhcpd.conf /etc/dhcp/dhcpd.conf
systemctl restart dhcpd.service
systemctl enable dhcpd.service
systemctl status dhcpd.service

######################################
# INSTALL ZTPSERVER
######################################
cd /home/ztpsadmin

# clone from GitHub
git clone https://github.com/arista-eosplus/ztpserver.git
cd ztpserver
git checkout v1.4

# build/install
python setup.py build
python setup.py install

mkdir /home/ztpsadmin/ztps-sampleconfig
cd /home/ztpsadmin/ztps-sampleconfig
git clone https://github.com/arista-eosplus/ztpserver-demo.git

cd ztpserver-demo/
cp -R ./definitions /usr/share/ztpserver/
cp -R ./files /usr/share/ztpserver/
cp -R ./nodes /usr/share/ztpserver/
cp -R ./resources /usr/share/ztpserver/
cp -R ./neighbordb /usr/share/ztpserver/
cp ztpserver.conf /etc/ztpserver/ztpserver.conf
cp bootstrap.conf /usr/share/ztpserver/bootstrap/bootstrap.conf


cd /usr/share/ztpserver/files
mkdir images
cp -R /tmp/packer/files/images .
mkdir puppet
cp -R /tmp/packer/files/puppet .

######################################
# Prepare ZTPServer for WSGI
######################################
chown -R ztpsadmin:ztpsadmin /usr/share/ztpserver
chmod -R ug+rw /usr/share/ztpserver
chcon -Rv --type=httpd_sys_script_rw_t /usr/share/ztpserver
