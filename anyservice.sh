#!/bin/bash

RETVAL=1

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

	if [ ! -n $User ] && [ getent passwd $User ] ; then
		my_exit "Dir non exist: $WorkingDirectory "
	fi

}

RUNDIR="/usr/bin/"
RUNFILE="$RUNDIR/$SERVNAME"
LOGDIR="/var/log/$SERVNAME/"
create_run(){

mkdir -p $LOGDIR
mkdir -p $RUNDIR

if [ ! -e $RUNFILE ] ; then
cat <<EOF > "$RUNFILE"
#!/bin/sh
cd $WorkingDirectory
chown $User $LOGDIR/$SERVNAME.log $PIDFile &> /dev/null
sudo su - -c "$ExecStart" $User >> $LOGDIR/$SERVNAME.log 2>&1 & echo "\$!" > $PIDFile
EOF
#TODO move echo on next line
chmod 755 $RUNFILE
else
my_exit_file $RUNFILE
fi
}

STOPFILE="$RUNDIR/$SERVNAME"-stop
create_stop(){
if [ ! -e $STOPFILE ] ; then
cat <<EOF > "$STOPFILE"
#!/bin/sh
/bin/kill `cat $PIDFile`
EOF
chmod 755 $STOPFILE
else
my_exit_file $STOPFILE
fi

}

MONITDIR="/etc/monit.d/"
MONITFILE="$MONITDIR/$SERVNAME"
create_monit(){
mkdir -p $MONITDIR

if [ ! -e $MONITFILE ] ; then
cat <<EOF >"$MONITFILE"
check process $SERVNAME with pidfile $PIDFile
        group daemons
        start program = "$RUNFILE"
        stop  program = "$STOPFILE"
        $MyRestart
EOF
else
my_exit_file $MONITFILE
fi
}

remove_service(){
    rm -f "$MONITFILE" "$RUNFILE" "$STOPFILE"
    RETVAL="$?"
    my_exit "Files removed $MONITFILE $RUNFILE $STOPFILE"
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
    if [ -e $MONITFILE ] && [ -e $RUNFILE ] && [ -e $STOPFILE ] ; then
	RETVAL=0
        my_exit "All done, now you may run monit: monit status $SERVNAME"
    else 
	exit $RETVAL
    fi
}

monit_install(){
    epmi -y monit
}

start_service(){
    echo "monit start $SERVNAME"
    monit monitor $SERVNAME
    monit start $SERVNAME
    RETVAL="$?"
    my_exit
}

stop_service(){
    echo "monit stop $SERVNAME"
    monit stop $SERVNAME
    RETVAL="$?"
    my_exit
}

status_service(){
    echo "monit status $SERVNAME"
#TODO close monit bug: show status of all monitored service
    monit status $SERVNAME
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
	create_run
	create_monit
	create_stop
	mydone
#TODO need test it:
	monit_install
	start_service
}

run $1 $2