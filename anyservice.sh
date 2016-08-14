#!/bin/bash
MYNAMEIS="anyservice"
MYMONIT="monit"
MONITDIR="/etc/monit.d/"
SERVDIR="/etc/systemd-lite"
SYSTEMDDIR="/lib/systemd/system"
SCRIPTNAME="$(basename $0)"
RUNDIR="/var/run/$MYNAMEIS/"
DEFAULTLOGDIR="/var/log/$MYNAMEIS/"

# TODO: allow change it
VERBOSE=false

MYSCRIPTDIR=$(dirname "$0")
[ "$MYSCRIPTDIR" = "." ] && MYSCRIPTDIR="$(pwd)"

# FIXME: drop it
RETVAL=1

FULLSCRIPTPATH=$MYSCRIPTDIR/$SCRIPTNAME
AUTOSTRING="#The file has been created automatically with $FULLSCRIPTPATH"

# Read params from .service file
read_config(){

    #TODO check it. Test remove file, run function
    exist_file $SERVFILE || my_exit_echo "Config file $SERVFILE has not been found"

    #TODO check that last file line is empty or add line !!!

    while IFS='=' read varname var ; do
        case "$varname" in
	    User) User="$var" ;;
	    WorkingDirectory) WorkingDirectory="$var" ;;
	    EnvironmentFile) EnvironmentFile="$var" ;;
	    Environment) Environment="$var" ;;
	    ExecStart) ExecStart="$var" ;;
	    Restart) Restart="$var" ;;
	    PIDFile) PIDFile="$var" ;;
	    *)     my_return "Found an unsupported systemd option: $varname $var" ;;
	esac
    done < "$SERVFILE"
    #TODO grep -v ^# | grep =
    #No need this, because no match in case for unsuported var
}

# Improve params
check_conf(){
    if [ -z "$PIDFile" ] ; then
	#TODO check permission for $User
        PIDFile=$RUNDIR/"${SERVNAME}.pid"
        #PIDFile=/tmp/"${SERVNAME}.pid"
    fi

    #TODO it needed or restart monit always?
    #if exist restart var enable monit restart 
    if [ -n "$Restart" ] ; then
        MyRestart="if 5 restarts with 5 cycles then timeout"
    else
  	MyRestart=""
    fi

    if [ -z "$WorkingDirectory" ] || [ ! -d "$WorkingDirectory" ] ; then
        RETVAL=1
        #TODO chane dir
        WorkingDirectory="/tmp"
        my_echo "Directory $WorkingDirectory does not exist. Using $WorkingDirectory"
    fi

#TODO check whis && [ getent passwd "$User" ]
    if [ -z "$User" ] ; then
    	my_return "User not passed, uses root"
    	User=root
    fi
}

read_service_info()
{
    read_config
    check_conf
}

# TODO check this
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

create_monit(){
monit_assure
if need_update_file "$SERVFILE" "$MONITFILE" ; then
echo "Create $MONITFILE ..."
cat <<EOF >"$MONITFILE"
check process $NEWSERVNAME with pidfile $PIDFile
        group daemons
        start program = "$FULLSCRIPTPATH $NEWSERVNAME startd"
        stop  program = "$FULLSCRIPTPATH $NEWSERVNAME stopd"
        $MyRestart

$AUTOSTRING
EOF
monit_reload
my_return "Monit is restarting"
else
RETVAL=1
my_return
fi
}


# FIXME: это пишется в начале файла, а не в конце
is_auto_created(){
    [ "`tail -n 1 $1`" = "$AUTOSTRING" ]
}

get_home_dir(){ #Get home dir path by User name
    getent passwd "$1" | cut -d: -f6
}

#=============== stop and start section ==========================
# *d command really start serv, without d run command over monit

prestartd_service(){ #Change dir to $1 and really run programm from $2
    #umask 0002
    mkdir -p $1 || my_exit "Can't create dir $1"
    cd $1 || my_exit "Can't change dir $1"
    #export HOME=$2
    shift

    exec "$@"
}

serv_startd(){
    LOGDIR="$DEFAULTLOGDIR/$NEWSERVNAME/"
    mkdir -p $LOGDIR

    read_service_info

    touch $PIDFile
    chown $User $PIDFile

    /sbin/start-stop-daemon --start --pidfile $PIDFile --background \
        --make-pidfile -c $User --exec $FULLSCRIPTPATH --startas $FULLSCRIPTPATH \
        -- $NEWSERVNAME prestartd $WorkingDirectory $ExecStart &> $LOGDIR/$NEWSERVNAME.log
    
    #ps aux | grep -m1 "^${User}.*${ExecStart}" | awk '{print $2}' > $PIDFile
}

serv_stopd(){
    read_service_info

    if [ -s "$PIDFile" ] ; then
        /sbin/start-stop-daemon --stop --pidfile $PIDFile
    else
        RETVAL="$?"
	my_exit "No $PIDFile"
    fi
}

###################################################################################

start_service(){
    monit_assure
    monit_wrap monitor
    monit_wrap start
}

stop_service(){
    monit_assure
    monit_wrap stop
}

restart_service(){
    monit_assure
    monit_wrap restart
}

summary_service(){
    monit_assure

    echo "$MYMONIT summary $NEWSERVNAME"
    $MYMONIT summary | grep $NEWSERVNAME
    RETVAL="$?"
    my_return
}

status_service(){
    monit_assure

    echo "$MYMONIT status $NEWSERVNAME"
    #TODO check
    $MYMONIT status | grep -A20 $NEWSERVNAME|grep -B20 'data collected' -m1
    RETVAL="$?"
    my_return
}

remove_service(){
    rm -f "$MONITFILE"
    RETVAL="$?"
    my_return "Files removed $MONITFILE"
    # FIXME: some other reread?
    serv --quiet monit reload
}

on_service(){
    #TODO check that non exist .off file
    #TODO check that file already exist
    ln -s "$SYSTEMDDIR/${SERVNAME}.service" $SERVDIR || my_exit "Can't enable $SYSTEMDDIR/$1"
    full_init
    start_service
}

off_service(){
    mv -v $SERVFILE ${SERVFILE}.off || my_exit "Can't disable $SERVFILE"
    remove_service
}

monit_wrap(){
    echo "$MYMONIT $1 $NEWSERVNAME"
    $MYMONIT $1 $NEWSERVNAME
}

monit_assure(){
    #TODO change $MYMONIT to $MONITPACKAGE
    epm assure $MYMONIT || exit
    exist_file $MONITFILE && return
    read_service_info
    create_monit
}

monit_reload()
{
    # TODO: всё время reload
    $MYMONIT reload
    sleep 2
}


exist_file(){
    # FIXME: страшный сон
    if ! [ -e "$1" ] ; then
        RETVAL=1
        my_return "Config file $1 has not been found"
    else
	RETVAL=0
        my_return "Config file $1 has been found"
    fi
}


#TODO need refactor, rewrite
my_getopts(){
    if ! [ -n "$1" ] ; then 
	help
	return 1
        #my_return
    fi

    case $1 in
         prestartd)
            shift
	    prestartd_service $@
	    ;;
         on)
	    on_service
	    ;;
         off)
	    off_service
	    ;;
         start)
	    start_service
	    ;;
         stop)
	    stop_service
            ;;
         restart)
	    restart_service
            ;;
         reload)
	    echo "TODO: add support ExecReload=/bin/kill -USR1 $MAINPID"
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


list_service(){
    RETVAL=0
    description_string="Description="
    
#    echo ""
    echo "List of $MYNAMEIS service files in $SERVDIR"
    echo ""

    for i in ${SERVDIR}/* ; do
	echo "$(basename $i)" 
	cat "$i" | grep "$description_string" | sed "s/$description_string/ /g"
        echo ""
    done

    my_exit "List"
}

# TODO: no global RETVAL!
my_return(){
    $VERBOSE && echo "$1"
    return $RETVAL
}

my_echo(){
    $VERBOSE && echo "$1"
}

my_exit(){
    $VERBOSE && echo "$1"
    exit $RETVAL
}

my_exit_echo(){
    echo "$1"
    exit $RETVAL
}

write_non_empty(){
    if [ -n "$1" ] ; then
        echo $1 > $2
    fi
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
    echo "$SCRIPTNAME <service file name> [start|stop|restart|status|summary|remove|list|on|off]"
    echo "Create service from program and control their procces"
    echo ""
    echo "example: put service file to ${SERVDIR}/example.service and run # $SCRIPTNAME example start"
    echo "example: put service file to $SYSTEMDDIR/example.service and run # $SCRIPTNAME example on"
    echo "example: $SCRIPTNAME <list|--help> #List of services or help"
    echo ""
    my_exit
}

init_serv()
{
    mkdir -vp $SERVDIR $DEFAULTLOGDIR $RUNDIR &> /dev/null

    SERVNAME="$1"
    SERVFILE="$SERVDIR/${SERVNAME}.service"
    NEWSERVNAME="${SERVNAME}"
    MONITFILE="$MONITDIR/$NEWSERVNAME"

    #TODO remove hack for some operation 
    if [ "list" = "$SERVNAME" ] ; then
	list_service
	exit
    fi

    if [ --help = "$SERVNAME" ] || [ -h = "$SERVNAME" ] || [ help = "$SERVNAME" ] || [ -z "$SERVNAME" ]; then
	help
	exit
    fi
}

#TODO rewrite for start from my_getopts $2
init_serv "$1"
shift
my_getopts "$@"
