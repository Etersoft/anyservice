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

create_run(){
RUNDIR="/usr/bin/"
LOGDIR="/var/log/$SERVNAME/"
RUNFILE="$RUNDIR/$SERVNAME"

mkdir -p $LOGDIR
mkdir -p $RUNDIR

#TODO
#sudo su - -c "$ExecStart" $User >> $LOGDIR/$SERVNAME.log 2>1& && echo "\$!" > $PIDFile


if [ ! -e $RUNFILE ] ; then
cat <<EOF > "$RUNFILE"
#!/bin/sh
cd $WorkingDirectory
chown $User $LOGDIR/$SERVNAME.log $PIDFile &> /dev/null
sudo su - -c "$ExecStart" $User >> $LOGDIR/$SERVNAME.log 2>&1 & echo "\$!" > $PIDFile
EOF
chmod 755 $RUNFILE
else
my_exit_file $RUNFILE
fi

#TODO check creating pid
}

create_monit(){
MONITDIR="/etc/monit.d/"
MONITFILE="$MONITDIR/$SERVNAME"
mkdir -p $MONITDIR

if [ ! -e $MONITFILE ] ; then
cat <<EOF >"$MONITFILE"
check process $SERVNAME with pidfile $PIDFile
        group daemons
        start program = "$RUNFILE"
        stop  program = "/bin/kill \`cat $PIDFile\`"
        $MyRestart
EOF
else
my_exit_file $MONITFILE
fi
}

my_exit(){
    echo "$1"
    exit $RETVAL
}

my_exit_file(){
    my_exit "File already exist $1"
}

help(){
    echo "anyservice.sh <service file name>"
    echo "example: put service file to $SERVDIR and run # anyservice.sh odoo"
    my_exit
}

mydone(){
    if [ -e $MONITFILE ] && [ -e $RUNFILE ] ; then
	RETVAL=0
        my_exit "All done, now you may run monit: monit start $SERVNAME"
    else 
	exit $RETVAL
    fi
}

monit_install(){
    epmi -y monit
}

start_service(){
    monit start $SERVNAME
}

stop_service(){
    monit stop $SERVNAME
}

my_getopts(){
while getopts “start:stop:” OPTION
do
     case $OPTION in
         start)
	    start_service
	    ;;
         stop)
	    stop_service
            ;;
         ?)
             help
             ;;
     esac
done
}

run(){
	init_serv $1
#	my_getopts $2
	read_config
	check_conf
	create_run
	create_monit
	mydone
#TODO need test it:
	monit_install
	start_service
}

run $1 $2
