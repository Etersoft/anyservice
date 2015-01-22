#!/bin/bash

. ./anyservice.sh any

SERVDIR="./"
SERVFILE="any.service"

cat $SERVDIR/$SERVFILE | grep =

read_config 

echo myWorkingDirectory $WorkingDirectory