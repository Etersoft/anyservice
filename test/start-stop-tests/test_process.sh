#/bin/sh

echo $USER > my.user
echo $! > my.pid
echo $(pwd) > my.dir
exec sleep 100