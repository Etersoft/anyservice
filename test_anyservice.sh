#!/bin/bash

MYANYSERVICE=./anyservice.sh

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
	SERVDIR="/etc/systemd-lite"
	my_test_service="top"
	MYTIMETOSLEEP=45

	cp ./${my_test_service}.service $SERVDIR/

	$MYANYSERVICE $my_test_service
	$MYANYSERVICE $my_test_service start

	cat /etc/monit.d/"$my_test_service"*

	sleep $MYTIMETOSLEEP
	$MYANYSERVICE "$my_test_service" status

	#Test
	test_monit_status Running
	mupid="$(monit status | grep -A 3 glu | grep pid | awk '{print $2}')"
	echo $mupid

	#Test pid
	ps aux | grep -m1 "$mupid" | grep "$my_test_service" && echo_correct Pid || echo_incorrect Pid

	#Test user
	[ "$(ps aux | grep -m1 "$mupid" | awk '{print $1}') " = "root" ] && echo_correct User || echo_incorrect User

	sleep $MYTIMETOSLEEP
	$MYANYSERVICE "$my_test_service" stop

	sleep $MYTIMETOSLEEP
	$MYANYSERVICE "$my_test_service" status

	#Test pid
	kill $mypid &> /dev/null || echo Killed
}

echo_correct(){
echo "$1 is correct"
return 0
}

echo_incorrect(){
echo "$1 is INCORRECT"
return 1
}

test_monit_status(){
monit status "$my_test_service" | grep -A 3 $MYTIMETOSLEEP | grep "$1" && echo "$1"
}

test_work
