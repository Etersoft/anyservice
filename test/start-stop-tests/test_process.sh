#!/bin/sh

myuser="my.user"
mypid="my.pid"
mydir="my.dir"
myhome="my.home"

echo "Started"

echo $USER > $myuser
echo $$ > $mypid
echo $(pwd) > $mydir
echo $HOME > $myhome
exec sleep 10 &

#rm -f $myuser $mypid $mydir $myhome