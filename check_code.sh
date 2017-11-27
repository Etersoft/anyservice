#!/bin/sh

EXCL=-eSC2086,SC2039,SC2034,SC2068,SC2155

EXCL=$EXCL,SC1091,SC1090

checkbashisms -f anyservice.sh
shellcheck $EXCL anyservice.sh
