#!/bin/bash

RETVAL=1
MYMONIT="monit"

init_serv(){
    SERVDIR="/etc/systemd-lite"
    mkdir -p $SERVDIR

    SERVNAME="$1"
    SERVFILE="$SERVDIR/${SERVNAME}.service"
    NEWSERVNAME="anyservice-${SERVNAME}"

    if ! [ -n "$SERVNAME" ] ; then
        help
    fi

    servfile_non_exist && my_exit "File $SERVNAME non exist, please create."
}

servfile_non_exist(){
    file_non_exist $SERVFILE
}

file_non_exist(){
    return `! [ -e "$1" ]`
}

#TODO rewrite to run function #HACK for my_get_ops
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
    done < $SERVFILE
    #TODO grep -v ^# | grep =
    #No need this, because no match in case for unsuported var
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
	#my_exit "Dir non exist: $WorkingDirectory "
    fi

#TODO check whis
#	if [ -n $User ] && [ getent passwd $User ] ; then
#		my_exit "User non exist: $User "
#	fi

}

create_monit(){
MONITDIR="/etc/monit.d/"
MONITFILE="$MONITDIR/$NEWSERVNAME"
mkdir -p $MONITDIR

#TODO write $MONITFILE if non exist or older that $SERVFILE
#DONE need check

if [ compare_file "$SERVFILE" "$MONITFILE" ] ; then
cat <<EOF >"$MONITFILE"
check process $NEWSERVNAME with pidfile $PIDFile
        group daemons
        start program = "$0 $NEWSERVNAME start"
        stop  program = "$0 $NEWSERVNAME stop"
        $MyRestart
EOF
else
my_exit_file $MONITFILE
fi
}

compare_file(){ #return 0 if file non exist or $2 older that $1
    #servfile_non_exist
    #example: compare_file serv monit #if monit older that serv return 0
    if [ ! -e $2 ] ; then
	return 0
    else if [ $1 -ot $2 ] ; then
	return 0
    else
	return 1
    fi
}


monit_install(){
    #TODO change $MYMONIT to $MONITPACKAGE
    epmq $MYMONIT || epmi -y $MYMONIT
}

#=============== stop and start section ==========================

serv_run(){
    LOGDIR="/var/log/$NEWSERVNAME/"
    mkdir -p $LOGDIR

    #TODO rewrite with /sbin/start-stop-daemon
    cd $WorkingDirectory
    /sbin/start-stop-daemon --start --chuid $User --pidfile $PIDFile --background --make-pidfile --exec $ExecStart >> $LOGDIR/$NEWSERVNAME.log
    cd -
}

serv_stop(){
    /sbin/start-stop-daemon --stop --pidfile $PIDFile
}

start_service(){
    #TODO make monit file if start run before init
    #create_monit

    echo "$MYMONIT start $NEWSERVNAME"
    $MYMONIT monitor $NEWSERVNAME
    #TODO is need start after monitor?
    $MYMONIT start $NEWSERVNAME
    RETVAL="$?"
    my_exit
}

stop_service(){
    echo "$MYMONIT stop $NEWSERVNAME"
    $MYMONIT stop $NEWSERVNAME
    RETVAL="$?"
    my_exit
}

status_service(){
    echo "$MYMONIT status $NEWSERVNAME"
#TODO close monit bug: show status of all monitored service
    $MYMONIT status $NEWSERVNAME
    RETVAL="$?"
    my_exit
}

my_getopts(){
if ! [ -n "$1" ] ; then 
    return 1
    #my_exit
fi

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
        my_exit "All done, now you may run monit: monit status $NEWSERVNAME"
    else 
	exit $RETVAL
    fi
}


run(){
    #	init_serv $1
    my_getopts $2
    read_config
    check_conf
    create_monit

    #TODO need test it:
    monit_install
    start_service
    mydone
}

run $1 $2