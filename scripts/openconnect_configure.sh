#!/bin/bash

action="$1"
baseUrl="$2"
server="$3"
user="$4"
password="$5"
group="$6"
grouppassword="$7"
hosts="$8"
nodetype="$9"

script="/usr/local/bin/vpn"
hostsFile="/etc/hosts"

function hostsFileCleanup {
    grep "#openconnect mark" $hostsFile 2>1 >/dev/null
    if [ $? -eq 0 ]; then
        blockStart=$(grep -n "#openconnect mark" $hostsFile | awk -F ":" '{print $1}' | head -n 1)
        blockEnd=$(grep -n "#openconnect mark" $hostsFile | awk -F ":" '{print $1}' | tail -n 1)
        sed "$blockStart,$blockEnd d" -i $hostsFile
    fi

    sed -i '/^$/d' $hostsFile
    echo "" >> $hostsFile
}

if [ "$action" == "uninstall" ]; then
    hostsFileCleanup;

    exit 0;
fi

stat $script  2>1 >/dev/null
if [ $? -gt 0 ]; then
    curl -fsSL "${baseUrl}/scripts/vpn.bash" -o $script;
    chmod +x $script;
fi

sed "s#VPN_SERVER=.*#VPN_SERVER='$server'#" -i $script
sed "s#VPN_USER=.*#VPN_USER='$user'#" -i $script
sed "s#VPN_PASSWORD=.*#VPN_PASSWORD='$password'#" -i $script
sed "s#VPN_GROUP=.*#VPN_GROUP='$group'#" -i $script
sed "s#VPN_GROUP_PASSWORD=.*#VPN_GROUP_PASSWORD='$grouppassword'#" -i $script

# find server cert
servercert=$(/usr/local/bin/vpn findServerCert)
sed "s#VPN_SERVER_CERT=.*#VPN_SERVER_CERT='$servercert'#" -i $script

LOGFILE=/dev/null
case $nodetype in 
    tomcat|tomcat7|tomcat85|tomcat9)
        LOGFILE=$LOGFILE
    ;;
    tomee-dockerized|tomee)
        LOGFILE=$LOGFILE    
    ;;
    glassfish|glassfish3|glassfish4)
        LOGFILE=$LOGFILE    
    ;;
    jetty|jetty9|jetty6|jetty8)
        LOGFILE=$LOGFILE    
    ;; 
    smartfox-server)
        LOGFILE=$LOGFILE
    ;;
    powerdns)
        LOGFILE=$LOGFILE    
    ;;
    railo4)
        LOGFILE=$LOGFILE    
    ;;
    wildfly|wildfly10|wildfly11|wildfly12|wildfly13|wildfly14|wildfly15|wildfly16|wildfly17)
        LOGFILE=$LOGFILE    
    ;;
    springboot)
        LOGFILE=$LOGFILE
    ;; 
    apache|apache2)
        LOGFILE=/var/log/httpd/vpn.log  
    ;;
    nginxphp-dockerized|nginxphp)
        LOGFILE=/var/log/nginx/vpn.log    
    ;;
    apache-python|apache2-python)
        LOGFILE=$LOGFILE    
    ;;
    apache-ruby|apache2-ruby)
        LOGFILE=$LOGFILE    
    ;;
    nginxruby|nginx-ruby)
        LOGFILE=$LOGFILE    
    ;;
    nginxphp-redis)
        LOGFILE=$LOGFILE    
    ;;
    nodejs)
        LOGFILE=$LOGFILE    
    ;;
    iis8)
        LOGFILE=$LOGFILE    
    ;;
    litespeedphp)
        LOGFILE=$LOGFILE
    ;;
esac

sed "s#LOGFILE=.*#LOGFILE='$LOGFILE'#" -i $script


#/etc/hosts

hostsFileCleanup

echo "#openconnect mark" >> $hostsFile 
printf "$hosts\n" >> $hostsFile
echo "#openconnect mark" >> $hostsFile 