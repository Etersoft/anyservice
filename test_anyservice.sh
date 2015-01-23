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

}