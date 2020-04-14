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
config="/etc/vpn-conf/server.conf"
hostsFile="/etc/hosts"

function hostsFileCleanup {
    if grep -q "#openconnect mark" $hostsFile; then
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

if [ ! -f $script ]; then
    curl -fsSL "${baseUrl}/scripts/vpn.bash" -o $script;
    chmod +x $script;
fi

if [ ! -f $config ]; then
    curl -fsSL --create-dirs "${baseUrl}/scripts/server.conf" -o $config;
    chmod 600 $config
fi

# find server cert
servercert=$(echo "$password" | openconnect --authgroup="$group" --non-inter -u "$user" --passwd-on-stdin --authenticate "$server" 2>&1 | grep "\-\-servercert" | sed "s#.*--servercert ##g")

sed -i -e "s/vserver/$server/" $config
sed -i -e "s/vuser/$user/" $config
sed -i -e "s/vpassword/$password/" $config
sed -i -e "s/vgroup/$group/" $config
sed -i -e "s/vservercert/$servercert/" $config

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