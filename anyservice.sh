#!/bin/bash

DIR

if [ -n "$1" ] ; then
        SERVFILE="$1"
    else
	help()
fi

read_config(){
    ./$SERVFILE
}

init_serv(){
    cd $WorkingDirectory

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

check_conf(){
#1) Проверить переменные что они заданы
#2) Что они осмыленные
# -Restart
# -dir exist and writable 
# -execstart

}

help(){
    echo "apk-pub <git/repo> [project_name]"
    echo "example: \$ apk-pub https://github.com/Danyboy/SpaceInvader.git SpaceInvader"
    exit 1
}

