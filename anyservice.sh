#!/bin/bash

RETVAL=1

init_serv(){
    SERVDIR="/etc/systemd-lite"

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
		my_exit "Dir non exist: $WorkingDirectory "
	fi

	if [ ! -n $User ] && [ getent passwd $User ] ; then
		my_exit "Dir non exist: $WorkingDirectory "
	fi

}

create_run(){
RUNDIR="/usr/bin/"
RUNFILE="$RUNDIR/$SERVNAME"

if [ ! -e $RUNFILE ] ; then
cat <<EOF > "$RUNFILE"
#!/bin/sh
cd $WorkingDirectory
sudo su - -c "$ExecStart" $User && echo "\$!" > $PIDFile
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
check process python with pidfile $PIDFile
        group daemons
        start program = "$RUNFILE"
        stop  program = "kill \`cat $PIDFile\`"
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
    echo "example: put service file to $SERVDIR and run \$ anyservice.sh odoo"
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
}

run $1 $2
