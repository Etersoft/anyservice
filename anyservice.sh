#!/bin/bash

MYSCRIPTDIR="$(pwd)"
RETVAL=1
MYNAMEIS="$0"
SCRIPTNAME="$(basename $0)"
MYMONIT="monit"
VERBOSE=true
SERVDIR="/etc/systemd-lite/"
RUNDIR="/var/run/$SCRIPTNAME/"
DEFAULTLOGDIR="/var/log/$SCRIPTNAME/"
AUTOSTRING="#The file has been created automatically with $MYNAMEIS"

init_serv(){
    mkdir -p $SERVDIR
    mkdir -p $DEFAULTLOGDIR
    mkdir -p $RUNDIR

    SERVNAME="$1"
    SERVFILE="$SERVDIR/${SERVNAME}.service"
    NEWSERVNAME="${SERVNAME}"

    if [ list = "$SERVNAME" ] ; then
	list_service
    fi

    if [ --help = "$SERVNAME" ] || [ -h = "$SERVNAME" ] || [ help = "$SERVNAME" ]; then
	help
    fi

    if [ -z "$SERVNAME" ] ; then
	help
    fi

    if ! [ -e "$SERVFILE" ] ; then
        RETVAL=1
	my_exit_echo "Config file $SERVFILE has not been found"
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
	    *)     $VERBOSE && echo "Found an unsupported systemd option: $varname $var" ;;
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
        start program = "$MYNAMEIS $NEWSERVNAME startd"
        stop  program = "$MYNAMEIS $NEWSERVNAME stopd"
        $MyRestart

$AUTOSTRING
EOF

serv monit start
serv monit reload
my_return "White while monit is restarting"
else
RETVAL=1
my_return
fi
}

need_update_file(){ 
    #return 0 if file non exist or $2 older that $1
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
    RETVAL="$?"
}

is_monit_installed(){
    epmq $MYMONIT || my_return "Monit not installed. Trying to install..."
    monit_install || my_exit "Monit not installed."
}

#=============== stop and start section ==========================
# *d command really start serv, without d run command over monit

serv_startd(){
    LOGDIR="$DEFAULTLOGDIR/$NEWSERVNAME/"
    mkdir -p $LOGDIR
    /sbin/start-stop-daemon --start --exec /bin/su --pidfile $PIDFile --make-pidfile --user $User \
	 -- -s /bin/sh -l $User -c "cd $WorkingDirectory ; exec $ExecStart &" &> $LOGDIR/$NEWSERVNAME.log
    
    ps aux | grep -m1 "^${User}.*${ExecStart}" | awk '{print $2}' > $PIDFile
}

write_non_empty(){
    if [ -n "$1" ] ; then
        echo $1 > $2
    fi
}

serv_stopd(){
    if [ -s "$PIDFile" ] ; then
        /sbin/start-stop-daemon --stop --pidfile $PIDFile
    else
        RETVAL="$?"
	my_exit "No $PIDFile"
    fi
}

start_service(){
    echo "$MYMONIT start $NEWSERVNAME"
    $MYMONIT monitor $NEWSERVNAME
    sleep 2
    $MYMONIT start $NEWSERVNAME
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

summary_service(){
    echo "$MYMONIT summary $NEWSERVNAME"
    $MYMONIT summary | grep $NEWSERVNAME
    RETVAL="$?"
    my_return
}

status_service(){
    echo "$MYMONIT status $NEWSERVNAME"
    #TODO check
    $MYMONIT status | grep -A20 $NEWSERVNAME|grep -B20 'data collected' -m1
    RETVAL="$?"
    my_return
}

#TODO need refactor, rewrite
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
	 summary)
            summary_service
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
	 list)
	    list_service
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
    serv monit reload
}

list_service(){
    RETVAL=0
    description_string="Description="
    
#    echo ""
    echo "List of $SCRIPTNAME service files in $SERVDIR"
    echo ""

    for i in ${SERVDIR}/* ; do
	echo "$(basename $i)" 
	cat "$i" | grep "$description_string" | sed "s/$description_string/ /g"
        echo ""
    done

    my_exit "List"
}
my_return(){
    $VERBOSE && echo "$1"
    return $RETVAL
}

my_exit(){
    $VERBOSE && echo "$1"
    exit $RETVAL
}

my_exit_echo(){
    echo "$1"
    exit $RETVAL
}


my_return_file(){
    RETVAL=1 
    my_return "The file ${1} exists"
}

my_exit_file(){
    RETVAL=1 
    my_exit "The file $1 exists"
}

help(){
    echo "$SCRIPTNAME <service file name> [start|stop|restart|status|summary|remove|list]"
    echo "example: put service file to $SERVDIR/odoo.service and run # $SCRIPTNAME odoo"
    echo "example: $SCRIPTNAME <list|--help> #List of services or help"
    my_exit
}

run(){
    #TODO rewrite for start from my_getopts $2
    init_serv $1 || help
    read_config
    is_monit_installed
    #monit_install || my_exit "Monit $WorkingDirectory does not exist."
    check_conf || my_exit "Dirеctory $WorkingDirectory does not exist."
    create_monit || my_return_file $MONITFILE
    my_getopts $2
}

run $1 $2