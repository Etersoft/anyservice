#!/bin/bash
# 
# The MIT License (MIT)
#  Copyright (c) 2015-2017 Etersoft
#  Copyright (c) 2015-2016 Daniil Mikhailov <danil@etersoft.ru>
#  Copyright (c) 2016-2017 Vitaly Lipatov <lav@etersoft.ru>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

MYNAMEIS="anyservice"
MONITDIR="/etc/monit.d"
MONITEXT=""
if [ ! -L "$MONITDIR" ] && [ -d "/etc/monitrc.d" ] ; then
    MONITDIR=/etc/monitrc.d
    MONITEXT=".conf"
fi
SERVDIR="/etc/$MYNAMEIS"
INITDIR=/etc/init.d
ETCSYSTEMDDIR="/etc/systemd/system"
SYSTEMDDIR="/lib/systemd/system"
# for Fedora based
[ -d "$SYSTEMDDIR" ] || SYSTEMDDIR="/usr/lib/systemd/system"
RUNDIR="/var/run/$MYNAMEIS"
LOGDIR="/var/log/$MYNAMEIS"

STARTMETHOD=''
if [ -x /sbin/start-stop-daemon ] ; then
    STARTMETHOD="/sbin/start-stop-daemon"
else
    if grep -q "^daemon()" "/etc/init.d/functions" && [ -s /etc/init.d/functions ]; then
        # We believe it is RHEL/CentOS/Fedora
        STARTMETHOD="functions-daemon"
    fi
fi

# TODO: allow change it
VERBOSE=false

MYSCRIPTDIR=$(dirname "$0")
[ "$MYSCRIPTDIR" = "." ] && MYSCRIPTDIR="$(pwd)"

SCRIPTNAME="$(basename $0)"
FULLSCRIPTPATH=$MYSCRIPTDIR/$SCRIPTNAME

AUTOSTRING="#The file has been created automatically with $FULLSCRIPTPATH"

fatal()
{
    echo "$1" >&2
    exit 1
}

info()
{
    $VERBOSE && echo "$1"
}

# Read params from .service file
read_config()
{

    [ -s "$SERVFILE" ] || fatal "Can't read $SERVFILE. Service is not prepared for start. Use 'on' command."

    #TODO check that last file line is empty or add line !!!

    while IFS='=' read varname var ; do
        case "$varname" in
            User) User="$var" ;;
            WorkingDirectory) WorkingDirectory="$var" ;;
            EnvironmentFile) EnvironmentFile="$var" ;;
            Environment) Environment="$var" ;;
            ExecStart) ExecStart="$var" ;;
            ExecReload) ExecReload="$var" ;;
            Restart) Restart="$var" ;;
            PIDFile) PIDFile="$var" ;;
        esac
    done < "$SERVFILE"
    #TODO grep -v ^# | grep =
    #No need this, because no match in case for unsuported var
}

# Improve params
check_conf()
{
    if [ -z "$PIDFile" ] ; then
        #TODO check permission for $User
        # TODO: put in /var/run/ by default
        PIDFile=$RUNDIR/"${SERVNAME}.pid"
        #PIDFile=/tmp/"${SERVNAME}.pid"
    fi

    #TODO it needed or restart monit always?
    #if exist restart var enable monit restart 
    if [ -n "$Restart" ] ; then
        MyRestart="if 5 restarts with 5 cycles then timeout"
    else
        MyRestart=""
    fi

    if [ -z "$WorkingDirectory" ] || [ ! -d "$WorkingDirectory" ] ; then
        #TODO change dir
        info "Directory $WorkingDirectory does not exist. Using /tmp"
        WorkingDirectory="/tmp"
    fi

#TODO check whis && [ getent passwd "$User" ]
    if [ -z "$User" ] ; then
        info "User is not passed, uses root"
        User=root
    fi

    if [ ! -s "$PIDFile" ] ; then
        #info "PID file $PIDFile is not exists"
        # just skip, it is possible we before first run
        return
    fi

    MAINPID=$(cat $PIDFile)
    if [ -z "$ExecReload" ] && [ -n "$MAINPID" ] ; then
        ExecReload="/bin/kill -HUP $MAINPID"
    fi

}

read_service_info()
{
    read_config || return
    check_conf
}

# TODO check this
need_update_file()
{
    #return 0 if file non exist or $2 older that $1
    #servfile_non_exist
    #example: need_update_file serv monit #if monit older that serv return 0
    if [ ! -s "$2" ] ; then
        return 0
    elif [ "$1" -nt "$2" ] && is_auto_created $2 ; then
        return 0
    else
        is_auto_created $2 || fatal "File $2 changed by human. Please, remove it manually"
        return 1
    fi
}

create_monit_file()
{
    epm assure monit || exit
    need_update_file "$SERVFILE" "$MONITFILE" || return 0

    echo "Create $MONITFILE ..."
    [ -n "$PIDFile" ] || fatal "PIDFile is missed"
    [ -n "$SERVNAME" ] || fatal "SERVNAME is missed"
    [ -n "$MONITSERVNAME" ] || fatal "MONITSERVNAME is missed"
    touch $MONITFILE || exit

cat <<EOF >"$MONITFILE"
check process $MONITSERVNAME with pidfile $PIDFile
        group $MYNAMEIS
        start program = "$FULLSCRIPTPATH $SERVNAME startd"
        stop  program = "$FULLSCRIPTPATH $SERVNAME stopd"
        $MyRestart

$AUTOSTRING
EOF

monit_reload

}

remove_monit_file()
{
    # remove from monit
    rm -fv "$MONITFILE" || return
    # FIXME: some other reread?
    #serv --quiet monit reload
    monit_reload
}

# FIXME: обычно это пишется в начале файла, а не в конце
is_auto_created()
{
    grep -q "$AUTOSTRING" "$1"
}

# Get home dir path by User name
get_home_dir()
{
    getent passwd "$1" | cut -d: -f6
}

#=============== stop and start section ==========================
# *d command really start serv, without d run command over monit

# Change dir to $1 and really run programm from $2
prestartd_service()
{
    #umask 0002
    mkdir -p "$1" || fatal "Can't create dir $1"
    cd "$1" || fatal "Can't change dir $1"
    #export HOME=$2
    shift

    exec "$@"
}

serv_startd()
{
    read_service_info || exit

    # FIXME: need we use chown for pid if we under root?
    touch $PIDFile
    chown $User $PIDFile

    # TODO: make it better?
    TMPDIR=/tmp
    HOME=$(get_home_dir $User)
    # Is we use that?

    # Expand all variables
    if [ -n "$EnvironmentFile" ] ; then
        # execute something like /etc/sysconfig/service
        if echo "$EnvironmentFile" | grep -q "^-" ; then
            EnvironmentFile=$(echo "$EnvironmentFile" | sed -e "s|^-||")
            # ignore missing file
            [ -s "$EnvironmentFile" ] && . "$EnvironmentFile"
        else
            . "$EnvironmentFile"
        fi
    fi
    # TODO: eval only last line
    [ -n "$Environment" ] && eval "$Environment"

    # HACK: due strange problem with vars evaluation
    local EXECSTART=$(eval echo "$ExecStart")


    # TODO: write all stdout/stderr to log file, not start-stop-daemon output
    # run via ourself script as wrapper

    if [ "$STARTMETHOD" = "/sbin/start-stop-daemon" ] ; then

    # --help for /sbin/start-stop-daemon
    #  -b|--background               force the process to detach
    #  -c|--chuid <name|uid[:group|gid]> change to this user/group before starting process
    #  -m|--make-pidfile             create the pidfile before starting

    # Note: run with prestartd for change working dir
    /sbin/start-stop-daemon --start --pidfile $PIDFile --background \
        --make-pidfile --chuid $User \
        --exec $FULLSCRIPTPATH --startas $FULLSCRIPTPATH -- \
        $SERVNAME prestartd $WorkingDirectory $EXECSTART 2>&1 | tee -a $LOGDIR/$SERVNAME.log

    elif [ "$STARTMETHOD" = "functions-daemon" ] ; then
        . /etc/init.d/functions
        # [--group=GROUP]
        daemon --user=$User --pidfile=$PIDFile --detach \
            $FULLSCRIPTPATH prestartd $WorkingDirectory $EXECSTART 2>&1 | tee -a $LOGDIR/$SERVNAME.log
    else
        fatal "Unsupported system"
    fi
    #ps aux | grep -m1 "^${User}.*${ExecStart}" | awk '{print $2}' > $PIDFile
}

serv_stopd()
{
    read_service_info || exit

    if [ -s "$PIDFile" ] ; then

        if [ "$STARTMETHOD" = "/sbin/start-stop-daemon" ] ; then
            /sbin/start-stop-daemon --stop --pidfile $PIDFile \
               --user "$User"
        elif [ "$STARTMETHOD" = "functions-daemon" ] ; then
            . /etc/init.d/functions
            killproc -p $PIDFile $SERVNAME
        else
            fatal "Unsupported system"
        fi
    else
        fatal "No PID file '$PIDFile'"
    fi
}

serv_statusd()
{
    read_service_info || exit

    if [ ! -s "$PIDFile" ] ; then
        fatal "No PID file '$PIDFile'"
    fi

    if [ "$STARTMETHOD" = "/sbin/start-stop-daemon" ] ; then
        /sbin/start-stop-daemon --stop --test --pidfile $PIDFile \
            --user $User >/dev/null
        #    --exec $FULLSCRIPTPATH --name
        if [ $? -eq 0 ]; then
            echo "service $SERVNAME is running"
            return 0
        fi
    elif [ "$STARTMETHOD" = "functions-daemon" ] ; then
            . /etc/init.d/functions
            status -p $PIDFile $SERVNAME
    fi

    if [ -n "$PIDFILE" -a -f "$PIDFILE" ]; then
        fatal "service $SERVNAME is dead, but stale PID file $PIDFILE exists"
    fi
}

# print out full path to the service file
get_systemd_service_file()
{
    local SERVNAME="$1"
    local SERVFILE=$SYSTEMDDIR/$SERVNAME.service
    [ -r "$SERVFILE" ] && echo "$SERVFILE" && return
    SERVFILE=$ETCSYSTEMDDIR/$SERVNAME.service
    [ -r "$SERVFILE" ] && echo "$SERVFILE" && return
    return 1
}

# NOTE: false positive on systems with systemd
# check if the service is handled by anyservice
serv_checkd()
{
    # not, if there is regular service with the name
    [ -r "$INITDIR/$SERVNAME" ] && return 1

    # yes, the service is anyservice driven
    [ -r "$SERVFILE" ] && return 0

    # yes, the service is anyservice driven (just disabled)
    [ -r "$SERVFILE.off" ] && return 0

    # yes, the service can be anyservice driven
    get_systemd_service_file $SERVNAME >/dev/null && return 0

    return 1
}

serv_isautostarted()
{
    serv_checkd || return
    # will autostarted!
    [ -r "$SERVFILE" ]
}

###################################################################################

monit_wrap()
{
    echo "monit $1 $MONITSERVNAME"
    monit $1 $MONITSERVNAME
}

monit_reload()
{
    monit reload
    # TODO: add real wait for end of reload
    sleep 3
}

is_monited()
{
    [ -s "$MONITFILE" ] || return
    monit_wrap status >/dev/null 2>/dev/null
}

start_service()
{
    create_monit_file
    monit_wrap start
    sleep 1
    monit_wrap monitor
}

stop_service()
{
    monit_wrap stop
}

restart_service()
{
    is_monited || fatal "Service $SERVNAME is stopped, skipping"
    create_monit_file
    monit_wrap restart
    # without pause here will ignores prev. command restart (see eterbug #11688)
    sleep 2
    monit_wrap monitor
}

reload_service()
{
    echo "Reload service with $(eval echo "$ExecReload")"
    eval $ExecReload
}

summary_service()
{
    echo "monit summary $MONITSERVNAME"
    monit summary | grep $MONITSERVNAME
}

status_service()
{
    #echo "service $SERVNAME status"
    serv_statusd
    echo
    echo "monit status $MONITSERVNAME"
    # TODO: add status (depends on type of system)
    [ -s "$MONITFILE" ] || fatal "Service $SERVNAME is not scheduled"
    monit status | grep -A20 $MONITSERVNAME|grep -B20 'data collected' -m1
}

on_service()
{
    #TODO check that non exist .off file
    #TODO check that file already exist
    if [ ! -e "$SERVFILE" ] ; then
        if [ -e ${SERVFILE}.off ] ; then
            mv -v ${SERVFILE}.off ${SERVFILE}
        else
            local SF="$(get_systemd_service_file $SERVNAME)" || fatal "Can't find system service file for $SERVNAME service"
            ln -s "$SF" "$SERVFILE" || fatal "Can't enable $SERVNAME"
        fi
    fi

    read_service_info
    start_service
}

off_service()
{
    is_monited && stop_service

    serv_isautostarted && mv -v $SERVFILE ${SERVFILE}.off

    remove_monit_file
}


check_user_command()
{

    if [ "$1" = "on" ] ; then
        on_service
        return
    fi

    read_service_info

    # next check for user calls
    case "$1" in
        # on)
        #    on_service
        #    ;;
         off)
            off_service
            ;;
         start)
            start_service
            ;;
         stop)
            stop_service
            ;;
         restart)
            restart_service
            ;;
         reload)
            reload_service
            ;;
         summary)
            summary_service
            ;;
         status)
            status_service
            ;;
         *)
            echo "Unknown command: $1"
            help
            exit 1
            ;;
    esac

}

check_internal_command()
{
    # first check for internal calls
    case "$1" in
         prestartd)
            shift
            prestartd_service "$@"
            ;;
         startd)
            serv_startd
            ;;
         stopd)
            serv_stopd
            ;;
         statusd)
            serv_statusd
            ;;
         checkd)
            serv_checkd
            ;;
         isautostarted)
            serv_isautostarted
            ;;
         *)
            check_user_command "$@"
            ;;
    esac
}


list_services()
{
    description_string="Description="

    if [ -z "$QUIET" ] ; then
        echo "List of $MYNAMEIS files in $SERVDIR:"
        echo ""
    fi

    for i in ${SERVDIR}/*.service ; do
        [ -s "$i" ] || continue
        echo "$(basename $i .service)"
        [ -n "$QUIET" ] && continue
        cat "$i" | grep "$description_string" | sed "s/$description_string/ /g"
        echo ""
    done
}


help()
{
    echo "$SCRIPTNAME <service file name> [start|stop|restart|status|summary|list|on|off]"
    echo "Create service from program and control their process"
    echo ""
    echo "example: put service file to ${SERVDIR}/example.service and run # $SCRIPTNAME example start"
    echo "example: put service file to $ETCSYSTEMDDIR/example.service and run # $SCRIPTNAME example on"
    echo "example: $SCRIPTNAME <list> - list of services"
    echo "example: $SCRIPTNAME --help - print this help"
    echo ""
}

init_serv()
{
    SERVNAME="$1"

    mkdir -vp $SERVDIR $LOGDIR $RUNDIR &> /dev/null

    SERVFILE="$SERVDIR/${SERVNAME}.service"
    MONITSERVNAME="$MYNAMEIS-${SERVNAME}"
    MONITFILE="$MONITDIR/$MONITSERVNAME$MONITEXT"

}

QUIET=
if [ "$1" = "--quiet" ] ; then
    QUIET=1
    shift
fi

if [ -z "$1" ]; then
    help
    exit 1
fi

case "$1" in
    --help|-h|help)
        help
        exit
esac

# hack for list
if [ "list" = "$1" ] ; then
    list_services
    exit
fi

#TODO rewrite for start from my_getopts $2
init_serv "$1"
shift

check_internal_command "$@"
