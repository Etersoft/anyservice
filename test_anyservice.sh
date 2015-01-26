#!/bin/bash

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

my_test_service="mysleep"

./anyservice.sh $my_test_service

cat /usr/bin/"$my_test_service"*

cat /etc/monit.d/"$my_test_service"*

monit status "$my_test_service"
}

