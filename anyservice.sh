#!/bin/bash

SERVDIR="/lib/systemd/system"


init_serv(){
    cd $WorkingDirectory

if [ -n "$1" ] ; then
        SERVFILE="$1"
    else
	help
fi

}

#init_serv $1

read_config(){
#    . ./$SERVFILE
    cat $SERVDIR/$SERVFILE | grep = | while IFS='=' read varname var ; do
        case "$varname" in
	    User)   User="$var" ;;
	    WorkingDirectory)   WorkingDirectory="$var" ;;
	    ExecStart)      ExecStart="$var" ;;
	    Restart)        Restart="$var" ;;
	    *)      echo "Unsuported systemd option $varname $var";;
	esac
    done

}

check_conf(){
#1) Проверить переменные что они заданы
#2) Что они осмыленные
# -Restart
# -dir exist and writable 
# -execstart

}


create_pid(){
    
    echo "$!" >
}

example_serv(){
Type=simple
User=lav
WorkingDirectory=/home/lav/odoo/
ExecStart=/home/lav/odoo/odoo.py -c openerp-server.conf
Restart=always

[Install]
WantedBy=multi-user.target

}

help(){
    echo "anyservice.sh <service file name> [PATH]"
    echo "example: \$ anyservice.sh odoo.service"
    exit 1
}

