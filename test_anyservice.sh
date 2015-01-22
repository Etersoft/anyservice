#!/bin/bash

. ./anyservice.sh 

SERVDIR="./"
SERVFILE="any.service"

cat $SERVDIR/$SERVFILE | grep =

read_config 