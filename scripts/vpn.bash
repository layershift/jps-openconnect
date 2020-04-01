#!/bin/bash

VPN_SERVER=""
VPN_USER=""
VPN_PASSWORD=''
VPN_GROUP=""
VPN_GROUP_PASSWORD=""
VPN_SERVER_CERT=''
VPN_OPTIONS=""

OPENCONNECT_PID_FILE="/var/run/vpn_OPENCONNECT"
PID_FILE="/var/run/vpn"

VERBOSE=0

OPENCONNECT_PID=""
RUNNING=""
NAME=${0##*/}

LOGFILE=/dev/null
exec > >(tee -a $LOGFILE)
exec 2>&1

# dependency check 
which openconnect 2>/dev/null 1>/dev/null
if [ $? -gt 0 ]; then
    echo "Error: openconnect not installed";
    exit 1;
fi

#check if disabled
if [ -f /usr/local/bin/vpn_disabled ]; then
    exit 0;
fi

function checkOpenConnectPID {
    if [ ! -f $OPENCONNECT_PID_FILE ]; then
        RUNNING=1
    else
        PID_ON_FILE=$(tail -n 1 $OPENCONNECT_PID_FILE);
        ps -p $PID_ON_FILE &> /dev/null
        RUNNING=$?
    fi
}

function checkOpenConnect {
    ps -p $OPENCONNECT_PID &> /dev/null
    RUNNING=$?

#    echo $RUNNING &>> reconnect.log
}

function findServerCert {
    echo "$VPN_PASSWORD" | openconnect $VPN_OPTIONS --authgroup=$VPN_GROUP --non-inter -u $VPN_USER --passwd-on-stdin --authenticate $VPN_SERVER 2>&1 | grep "\-\-servercert" | sed "s#.*--servercert ##g"
}

function startOpenConnect {
    #cp -f /etc/resolv.conf /etc/resolv.conf.bak
    # start here open connect with your params and grab its pid
    echo "$VPN_PASSWORD" | openconnect $VPN_OPTIONS --authgroup=$VPN_GROUP --servercert $VPN_SERVER_CERT -u $VPN_USER --passwd-on-stdin $VPN_SERVER & OPENCONNECT_PID=$!
    echo $OPENCONNECT_PID > $OPENCONNECT_PID_FILE;
}
function stopOpenConnect {
    #cp -f /etc/resolv.conf.bak /etc/resolv.conf
    for pid in $(cat $OPENCONNECT_PID_FILE); do
        kill -s USR1 $pid;
        sleep 2;
    done;
    [ ! -z  $OPENCONNECT_PID ] && kill -s USR1 $OPENCONNECT_PID;
    rm -f $OPENCONNECT_PID_FILE 2>&1 1>/dev/null
    rm -f $PID_FILE 2>&1 1>/dev/null
    echo "$(date) Bye";
    killall -s USR1 openconnect 2>&1 1>/dev/null
    killall -s USR1 $NAME 2>&1 1>/dev/null
    exit 0;
}

while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
            -h|--help)
                script_usage
                exit 0
            ;;
            stop|kill)
                stopOpenConnect
                exit 0
            ;;
            -v|--verbose)
                VERBOSE=1;
                VPN_OPTIONS=$VPN_OPTIONS" -v";
            ;;
            --debug)
                set -x
            ;;
            findServerCert)
                findServerCert
                exit 0
            ;;
            status)
                checkOpenConnectPID
                echo -n "$0 .. "
                if [ $RUNNING -eq 0 ]; then
                    echo "running"
                else
                    echo "stopped"
                fi
                if [ $VERBOSE -gt 0 ]; then
                    pstree $(tail -n 1 $PID_FILE) -hla
                fi
                exit 0
            ;;
    esac
done;

checkOpenConnectPID
if [ $RUNNING -eq 0 ]; then
    if [ $VERBOSE -gt 0 ]; then
        echo "Debug: Already running";
    fi;
    exit 5;
else
    echo "$(date) Starting..."
    startOpenConnect
    echo $$ > $PID_FILE
fi;

while true
do
    # sleep a bit of time
    sleep 10
    checkOpenConnect
    [ $RUNNING -ne 0 ] && startOpenConnect
done
