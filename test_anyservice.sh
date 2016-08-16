#!/bin/bash

MYANYSERVICE=anyservice
VERBOSE="false"


update_anyservice(){
    cp -u "./${MYANYSERVICE}.sh" /usr/bin/$MYANYSERVICE
}

test_var_init(){
. ./anyservice.sh any

SERVDIR="./"
SERVFILE="any.service"

cat $SERVDIR/$SERVFILE | grep =

read_config 

echo myWorkingDirectory $WorkingDirectory

! [ -n "$WorkingDirectory" ] && echo "test var init FAIL"
}

test_work(){
	SERVDIR="/etc/anyservice"
	my_test_service="top"
	MYTIMETOSLEEP=65
	MYPID="/var/run/${my_test_service}.pid"
	
	#Initilisation	
	cp ./${my_test_service}.service $SERVDIR/
	my_run $MYANYSERVICE $my_test_service
	my_run $MYANYSERVICE $my_test_service start

	#Check monit
	$VERBOSE && cat /etc/monit.d/"$my_test_service"*
	sleep $MYTIMETOSLEEP
	my_run $MYANYSERVICE "$my_test_service" status

	#Tests
	test_monit_status Running

	#Test pid
	#TODO need sleep while monit updates status
	mupid="$(monit status | grep -A 3 $my_test_service | grep pid | awk '{print $2}')"
	echo $mupid
	ps aux | grep -m1 "$mupid" | grep "$my_test_service" && echo_correct Pid || echo_incorrect Pid
	cat $MYPID
	[ "$(ps aux | grep -m1 "^root.*${my_test_service}" | awk '{print $2}')" = "$(cat $MYPID)" ] && echo_correct Pid || echo_incorrect Pid

	#Test user
	[ "$(ps aux | grep -m1 "$mupid" | awk '{print $1}') " = "root" ] && echo_correct User || echo_incorrect User

	sleep $MYTIMETOSLEEP
	my_run $MYANYSERVICE "$my_test_service" stop

	sleep $MYTIMETOSLEEP
	my_run $MYANYSERVICE "$my_test_service" status

	#Test pid
	kill $mypid &> /dev/null || echo Killed
}

my_run(){
    if [ "$VERBOSE" = true ] ; then 
        $1 $2 $3 
    else 
	$1 $2 $3 &> /dev/null
    fi
}

echo_correct(){
    echo "$1 is correct"
    RETVAL="0"
    return $RETVAL
}

echo_incorrect(){
    echo "$1 is INCORRECT"
    RETVAL="1"
    return $RETVAL
}

test_monit_status(){
    my_run monit status "$my_test_service" | grep -A 3 $MYTIMETOSLEEP | grep "$1" && echo "$1"
}

test_result(){
    echo ""
    [ "$RETVAL" = 0 ] && echo "Tests DONE" || echo "Tests FAIL"
}

update_anyservice
test_work
test_result