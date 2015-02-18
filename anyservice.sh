#!/bin/bash

MYSCRIPTDIR="$(pwd)"
RETVAL=1
MYNAMEIS="$0"
MYMONIT="monit"
VERBOSE=false
SERVDIR="/etc/systemd-lite"
RUNDIR="/var/run/"
DEFAULTLOGDIR="/var/log/"
AUTOSTRING="# File created automatic by $MYSCRIPTDIR/$MYNAMEIS"

init_serv(){
    mkdir -p $SERVDIR

    SERVNAME="$1"
    SERVFILE="$SERVDIR/${SERVNAME}.service"
    NEWSERVNAME="${SERVNAME}"

    if ! [ -n "$SERVNAME" ] && ! [ -e "$SERVFILE" ] ; then
        RETVAL=1
	my_return
    fi

}

read_config(){
    while IFS='=' read varname var ; do
        case "$varname" in
	    User) User="$var" ;;
	    WorkingDirectory) WorkingDirectory="$var" ;;
	    ExecStart) ExecStart="$var" ;;
	    Restart) Restart="$var" ;;
	    PIDFile) PIDFile="$var" ;;
	    *)     $VERBOSE && echo "Unsuported systemd option $varname $var" ;;
	esac
    done < $SERVFILE
    #TODO grep -v ^# | grep =
    #No need this, because no match in case for unsuported var
}

check_conf(){

    if [ -z "$PIDFile" ] ; then
        PIDFile=$RUNDIR"${SERVNAME}.pid"
    fi

    #TODO it needed or restart monit always?
    #if exist restart var enable monit restart 
    if [ -n "$Restart" ] ; then
        MyRestart="if 5 restarts with 5 cycles then timeout"
    else
  	MyRestart=""
    fi

    if [ ! -d $WorkingDirectory ] ; then
        RETVAL=1
        my_return
    fi

#TODO check whis
#	if [ -n "$User" ] && [ getent passwd "$User" ] ; then
#		my_return "User non exist: $User "
#	fi

}

create_monit(){
MONITDIR="/etc/monit.d/"
MONITFILE="$MONITDIR/$NEWSERVNAME"
mkdir -p $MONITDIR

if need_update_file "$SERVFILE" "$MONITFILE" ; then
cat <<EOF >"$MONITFILE"
check process $NEWSERVNAME with pidfile $PIDFile
        group daemons
        start program = "$MYNAMEIS $NEWSERVNAME start"
        stop  program = "$MYNAMEIS $NEWSERVNAME stop"
        $MyRestart

$AUTOSTRING
EOF

#TODO check Need monit restart for read new file #bug
serv monit restart
my_return "White while monit is restarting"
sleep 10 #monit start 10 seconds how wait this time?
else
RETVAL=1
my_return
fi
}

need_update_file(){ #return 0 if file non exist or $2 older that $1
    #servfile_non_exist
    #example: need_update_file serv monit #if monit older that serv return 0
    if [ ! -e "$2" ] ; then
	return 0
    elif [ "$1" -nt "$2" ] && is_auto_created $2 ; then
	return 0
    else
	return 1
    fi
}

is_auto_created(){
    [ "`tail -n 1 $1`" = "$AUTOSTRING" ] 
}

monit_install(){
    #TODO change $MYMONIT to $MONITPACKAGE
    epmq $MYMONIT || epmi -y $MYMONIT
    serv monit start #TODO check it and add depends on epm
}

#=============== stop and start section ==========================
# *d command really start serv, without d run d command over monit

serv_startd(){
    LOGDIR="$DEFAULTLOGDIR/$NEWSERVNAME/"
    mkdir -p $LOGDIR
    #TODO chech it
    cd $WorkingDirectory
    /sbin/start-stop-daemon --start --chuid $User --pidfile $PIDFile --background --make-pidfile --exec $ExecStart >> $LOGDIR/$NEWSERVNAME.log
    cd -
}

serv_stopd(){
    /sbin/start-stop-daemon --stop --pidfile $PIDFile
}

start_service(){
    echo "$MYMONIT start $NEWSERVNAME"
    $MYMONIT monitor $NEWSERVNAME
    #TODO is need start after monitor?
    #$MYMONIT start $NEWSERVNAME
    RETVAL="$?"
    my_return
}

stop_service(){
    echo "$MYMONIT stop $NEWSERVNAME"
    $MYMONIT stop $NEWSERVNAME
    RETVAL="$?"
    my_return
}

restart_service(){
    echo "$MYMONIT restart $NEWSERVNAME"
    $MYMONIT restart $NEWSERVNAME
    RETVAL="$?"
    my_return
}

status_service(){
    echo "$MYMONIT status $NEWSERVNAME"
    #TODO close monit bug: show status of all monitored service
    $MYMONIT status $NEWSERVNAME
    RETVAL="$?"
    my_return
}

my_getopts(){
    if ! [ -n "$1" ] ; then 
	return 1
        #my_return
    fi

    case $1 in
         start)
	    start_service
	    ;;
         stop)
	    stop_service
            ;;
         restart)
	    restart_service
            ;;
	 status)
            status_service
            ;;
         startd)
	    serv_startd
	    ;;
         stopd)
	    serv_stopd
            ;;
	 remove)
            remove_service
            ;;
         *)
            help
            ;;
    esac
}

remove_service(){
    rm -f "$MONITFILE"
    RETVAL="$?"
    my_return "Files removed $MONITFILE"
}

my_return(){
    $VERBOSE && echo "$1"
    return $RETVAL
}

my_exit(){
    $VERBOSE && echo "$1"
    exit $RETVAL
}

my_return_file(){
    RETVAL=1 
    my_return "File already exist $1"
}

my_exit_file(){
    RETVAL=1 
    my_exit "File already exist $1"
}

help(){
    echo "anyservice.sh <service file name> [start|stop|restart|status]"
    echo "example: put service file to $SERVDIR and run # anyservice.sh odoo"
    my_return
}

run(){
    init_serv $1 || help
    read_config
    check_conf || my_exit "Dir non exist: $WorkingDirectory "
    create_monit || my_return_file $MONITFILE
    my_getopts $2
}

run $1 $2