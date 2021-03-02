#!/bin/bash

OPENCONNECT_PID_FILE="/var/run/vpn_OPENCONNECT"
PID_FILE="/var/run/vpn"
CONF_DIR="/etc/vpn-conf"

VERBOSE=0

RUNNING=""
SCRIPT_RUNNING=""
NAME=${0##*/}

LOGFILE=/var/log/nginx/vpn.log
exec 3>&1 &> $LOGFILE

# dependency check
if ! which openconnect &> /dev/null; then
    echo "Error: openconnect not installed";
    exit 1;
fi

# check if disabled
if [ -f /usr/local/bin/vpn_disabled ]; then
    exit 0;
fi

function checkScriptRunning() {
    if [ ! -f $PID_FILE ]; then
        SCRIPT_RUNNING=1
    else
        PID_ON_FILE=$(tail -n 1 $PID_FILE);
        ps -p $PID_ON_FILE &> /dev/null
        SCRIPT_RUNNING=$?
    fi
}

function checkOpenConnect {
    RUNNING=0
    for f in "$CONF_DIR"/*.conf; do
        f_base=$(basename -- "$f")
        if ! ([ -f $OPENCONNECT_PID_FILE ] && grep "$f_base" $OPENCONNECT_PID_FILE | awk '{ print $1 }' |  xargs ps -p &> /dev/null); then
            RUNNING=1
        fi
    done
}

function startWithConf {
    VPN_PASSWORD=$(awk '/^password/{print $3;exit}' "$1")
    VPN_USER=$(awk '/^user/{print $3;exit}' "$1")
    VPN_SERVER=$(awk '/^server/{print $3;exit}' "$1")
    VPN_GROUP=$(awk '/^group/{print $3;exit}' "$1")
    VPN_SERVER_CERT=$(awk '/^servercert/{print $3;exit}' "$1")
    echo "$VPN_PASSWORD" | openconnect --authgroup=$VPN_GROUP --servercert $VPN_SERVER_CERT -u $VPN_USER --passwd-on-stdin $VPN_SERVER & OPENCONNECT_PID=$!
    sed -i -e "/$2/d" $OPENCONNECT_PID_FILE
    echo $OPENCONNECT_PID $2 >> $OPENCONNECT_PID_FILE
}

function startOpenConnect {
    for f in "$CONF_DIR"/*.conf; do
        f_base=$(basename -- "$f")
        if ! ([ -f $OPENCONNECT_PID_FILE ] && grep "$f_base" $OPENCONNECT_PID_FILE | awk '{ print $1 }' |  xargs ps -p &> /dev/null); then
            startWithConf "$f" "$f_base";
        fi
    done
}

function stopOpenConnect {
    #cp -f /etc/resolv.conf.bak /etc/resolv.conf
    for pid in $(awk '{ print $1 }' $OPENCONNECT_PID_FILE); do
        kill -s INT $pid;
        sleep 2;
    done;
    [ ! -z $OPENCONNECT_PID ] && kill -s INT $OPENCONNECT_PID;
    rm -f $OPENCONNECT_PID_FILE &> /dev/null
    rm -f $PID_FILE &> /dev/null
    echo "$(date) Bye";
    killall -s INT openconnect &> /dev/null
    killall -s INT $NAME &> /dev/null
    exit 0;
}

function updateServerCert {
    VPN_PASSWORD=$(awk '/^password/{print $3;exit}' "$1")
    VPN_USER=$(awk '/^user/{print $3;exit}' "$1")
    VPN_SERVER=$(awk '/^server/{print $3;exit}' "$1")
    VPN_GROUP=$(awk '/^group/{print $3;exit}' "$1")

    if [ $VERBOSE -gt 0 ]; then
        echo "servercert=\$(echo $VPN_PASSWORD | openconnect --non-inter --authenticate --authgroup=$VPN_GROUP -u $VPN_USER --passwd-on-stdin $VPN_SERVER 2>&1 | egrep \"\-\-servercert|FINGERPRINT\" | sed \"s#.*--servercert ##g\" | sed \"s#FINGERPRINT=##g\" | xargs)" 1>&3
    fi
    servercert=$(echo $VPN_PASSWORD | openconnect --non-inter --authenticate --authgroup=$VPN_GROUP -u $VPN_USER --passwd-on-stdin $VPN_SERVER 2>&1 | egrep "\-\-servercert|FINGERPRINT" | sed "s#.*--servercert ##g" | sed "s#FINGERPRINT=##g" | xargs)

    if grep -q servercert $1; then
        sed -i -e "s#^servercert.*#servercert = $servercert#" "$1"
    else
        echo "servercert = $servercert" >> "$1"
    fi

    echo "Updated server certificate hash for $1 | $servercert" 1>&3
}

function scriptUsage {
    echo "usage: vpn [-dv] [action] <args>" 1>&3
    echo "  -d | --debug     display debug info" 1>&3
    echo "  -v | --verbose   display full output" 1>&3
    echo "  ----------------------------------------------------------------------------------" 1>&3
    echo "  help | -h | --help                  display this help" 1>&3
    echo "  stop                                stop the VPN" 1>&3
    echo "  status                              display VPN status" 1>&3
    echo "  update-server-cert <config_file>    update the server certificate for given config" 1>&3
}

while [[ $# -gt 0 ]]; do
    param="$1"
    shift
    case $param in
            update-server-cert)
                for conf in `find /etc/vpn-conf -name "*.conf" -type f`; do
                    updateServerCert "$conf"
                done;
                exit 0
            ;;
            help|-h|--help)
                scriptUsage
                exit 0
            ;;
            stop)
                stopOpenConnect
                exit 0
            ;;
            -v|--verbose)
                VERBOSE=1;
                VPN_OPTIONS=$VPN_OPTIONS" -v";
            ;;
            -d|--debug)
                set -x
            ;;
            status)
                checkOpenConnect
                echo -n "$0 .. "
                if [ $RUNNING -eq 0 ]; then
                    echo "running" 1>&3
                else
                    echo "stopped" 1>&3
                fi
                if [ $VERBOSE -gt 0 ]; then
                    pstree $(tail -n 1 $PID_FILE) -hla 1>&3
                fi
                exit 0
            ;;
    esac
done;

checkScriptRunning
if [ $SCRIPT_RUNNING -eq 0 ]; then
    if [ $VERBOSE -gt 0 ]; then
        echo "Debug: Script already running";
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
