#!/bin/bash

action="$1"
baseUrl="$2"
server="$3"
user="$4"
password="$5"
group="$6"
grouppassword="$7"
hosts="$8"

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

#/etc/hosts

hostsFileCleanup

echo "#openconnect mark" >> $hostsFile 
printf "$hosts\n" >> $hostsFile
echo "#openconnect mark" >> $hostsFile 