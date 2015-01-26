#!/bin/bash

RETVAL=1
MYMONIT="monit"

init_serv(){
    SERVDIR="/etc/systemd-lite"
    mkdir -p $SERVDIR

    SERVNAME="$1"
    SERVFILE="${SERVNAME}.service"

    if ! [ -n "$SERVNAME" ] && ! [ -e "$SERVFILE" ] ; then
        help
    fi

}
init_serv $1

read_config(){
    while IFS='=' read varname var ; do
        case "$varname" in
	    User) User="$var" ;;
	    WorkingDirectory) WorkingDirectory="$var" ;;
	    ExecStart) ExecStart="$var" ;;
	    Restart) Restart="$var" ;;
	    PIDFile) PIDFile="$var" ;;
	    *)     false && echo "Unsuported systemd option $varname $var" ;;
	esac
    done < $SERVDIR/$SERVFILE
#No need this, because no match in case
#TODO grep -v ^# | grep =

}

check_conf(){

	if [ -n $PIDFile ] ; then
	        PIDFile=/var/run/"${SERVNAME}.pid"
	fi

	#TODO it needed or restart monit always?
	#if exist restart var enable monit restart 
	if [ -n $Restart ] ; then
		    MyRestart="if 5 restarts with 5 cycles then timeout"
		else
  		MyRestart=""
	fi

	if [ ! -d $WorkingDirectory ] ; then
		mkdir -p $WorkingDirectory #TODO this is good turn?
#		my_exit "Dir non exist: $WorkingDirectory "
	fi

	if [ -n $User ] && [ getent passwd $User ] ; then
		my_exit "User non exist: $User "
	fi

}

create_monit(){
MONITDIR="/etc/monit.d/"
MONITFILE="$MONITDIR/$SERVNAME"
mkdir -p $MONITDIR

if [ ! -e $MONITFILE ] ; then
cat <<EOF >"$MONITFILE"
check process $SERVNAME with pidfile $PIDFile
        group daemons
        start program = "$0 $SERVNAME start"
        stop  program = "$0 $SERVNAME stop"
        $MyRestart
EOF
else
my_exit_file $MONITFILE
fi
}

remove_service(){
    rm -f "$MONITFILE"
    RETVAL="$?"
    my_exit "Files removed $MONITFILE"
}

my_exit(){
    echo "$1"
    exit $RETVAL
}

my_exit_file(){
    my_exit "File already exist $1"
}

help(){
    echo "anyservice.sh <service file name> [start|stop|status]"
    echo "example: put service file to $SERVDIR and run # anyservice.sh odoo"
    my_exit
}

mydone(){
    if [ -e $MONITFILE ] ; then
	RETVAL=0
        my_exit "All done, now you may run monit: monit status $SERVNAME"
    else 
	exit $RETVAL
    fi
}

monit_install(){
    #TODO change $MYMONIT to $MONITPACKAGE
    epmq $MYMONIT || epmi -y $MYMONIT
}

serv_run(){
    LOGDIR="/var/log/$SERVNAME/"
    mkdir -p $LOGDIR

    #TODO rewrite with /sbin/start-stop-daemon
    cd $WorkingDirectory
    /sbin/start-stop-daemon --start --chuid $User --pidfile $PIDFile --background --make-pidfile --exec $ExecStart >> $LOGDIR/$SERVNAME.log
    cd -
}

serv_stop(){
    /sbin/start-stop-daemon --stop --pidfile $PIDFile
}

start_service(){
    echo "$MYMONIT start $SERVNAME"
    $MYMONIT monitor $SERVNAME
#TODO is need start after monitor?
    $MYMONIT start $SERVNAME
    RETVAL="$?"
    my_exit
}

stop_service(){
    echo "$MYMONIT stop $SERVNAME"
    $MYMONIT stop $SERVNAME
    RETVAL="$?"
    my_exit
}

status_service(){
    echo "$MYMONIT status $SERVNAME"
#TODO close monit bug: show status of all monitored service
    $MYMONIT status $SERVNAME
    RETVAL="$?"
    my_exit
}

my_getopts(){
if ! [ -n "$1" ] ; then 
    return 1
    #my_exit
fi

#TODO test
     case $1 in
         start)
	    start_service
	    ;;
         stop)
	    stop_service
            ;;
         startd)
	    serv_start
	    ;;
         stopd)
	    serv_stop
            ;;
	 status)
            status_service
            ;;
	 remove)
            remove_service
            ;;
         *)
            help
            ;;
     esac
}

run(){
#	init_serv $1
	my_getopts $2
	read_config
	check_conf
#TODO need test it:
	monit_install
	start_service
	mydone
}

run $1 $2