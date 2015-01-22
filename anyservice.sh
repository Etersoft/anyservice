#!/bin/bash

init_serv(){
    SERVDIR="/lib/systemd/system/"

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
    while IFS='=' read varname var ; do
        case "$varname" in
	    User) User="$var"
	    echo var $var ;;
	    WorkingDirectory) WorkingDirectory="$var" ;;
	    ExecStart) ExecStart="$var" ;;
	    Restart) Restart="$var" ;;
	    PIDFile) PIDFile="$var" ;;
	    *)      echo "Unsuported systemd option $varname $var" ;;
	esac
    done < $SERVDIR/$SERVFILE
}

check_conf(){

	if [ ! -r $PIDFile ] ; then
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

#TODO check if exist run and monit file

create_run(){
RUNDIR="/usr/bin/"
RUNFILE="$RUNDIR/$SERVNAME"

if [ ! -e $RUNFILE ] ; then
cat <<EOF > "$RUNFILE"
#!/bin/sh
cd $WorkingDirectory
sudo su - -c "$ExecStart" $User && echo "$!" > $PIDFile
EOF
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
        stop  program = "kill `cat $PIDFile`"
        $MyRestart
EOF
else
my_exit_file $MONITFILE
fi
}

my_exit(){
    echo "$1"
    exit 1
}

my_exit_file(){
    my_exit "File already exist $1"
}

help(){
    echo "anyservice.sh <service file name> [PATH]"
    echo "example: \$ anyservice.sh odoo"
    my_exit
}

run(){
	init_serv $1
	read_config
	check_conf
	create_run
	create_monit
}

run $1
