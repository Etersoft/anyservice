#!/bin/bash

SERVDIR="/lib/systemd/system"


init_serv(){
    SERVDIR="/lib/systemd/system"

	if [ -n "$1" ] ; then
		    SERVNAME="$1"
		SERVFILE="${SERVNAME}.service"
		else
		help
	fi

}

#init_serv $1

read_config(){
#    . ./$SERVFILE #not work because run file
    cat $SERVDIR/$SERVFILE | grep = | while IFS='=' read varname var ; do
        case "$varname" in
	    User)   User="$var" ;;
	    WorkingDirectory)   WorkingDirectory="$var" ;;
	    ExecStart)      ExecStart="$var" ;;
	    Restart)        Restart="$var" ;;
	    PIDFile)        PIDFile="$var" ;;
	    *)      echo "Unsuported systemd option $varname $var";;
	esac
    done

}

check_conf(){

	if [ -r $PIDFile ] ; then
		else
		    PIDFile=/var/run/"${SERVNAME}.pid"
	fi

	#TODO it needed or restart monit always?
	#if exist restart var enable monit restart 
	if [ -n $Restart ] ; then
		    MyRestart="if 5 restarts with 5 cycles then timeout"
		else
		MyRestart=""
	fi

	if [ -d $WorkingDirectory ] ; then
		    
		else
		my_exit "Dir non exist: $WorkingDirectory "
	fi

	if [ -n $User ] && [ getent passwd $User ] ; then
		    
		else
		my_exit "Dir non exist: $WorkingDirectory "
	fi

}

#TODO check if exist run and monit file

create_run(){
RUNDIR="/usr/bin/"
RUNFILE="$RUNDIR/$SERVNAME"

cat <<EOF >./$RUNFILE
#!/bin/sh
cd $WorkingDirectory
sudo su - -c "$ExecStart" $User && echo "$!" > $PIDFile
EOF

#TODO check creating pid
}

create_monit(){
MONITFILE="/etc/monit.d/$SERVNAME"

cat <<EOF >./$MONITFILE
check process python with pidfile $PIDFile
        group daemons
        start program = "$RUNFILE"
        stop  program = "kill `cat $PIDFile`"
        $MyRestart
EOF
}

my_exit(){
    echo "$1"
    exit 1
}

help(){
    echo "anyservice.sh <service file name> [PATH]"
    echo "example: \$ anyservice.sh odoo"
    my_exit
}

run(){
	init_serv
	read_config
	check_conf
	create_run
	create_monit
}

run
