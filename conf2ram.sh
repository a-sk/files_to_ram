#!/bin/zsh
#TODO"
# refactor in order to correctly handle state if $2 is presented
USER="ask"
UHOME="/home/$USER"
RAMDIR="$UHOME/.ramdir"
LOCK="/var/run/conf2ram_lock"
TMPFS_OPTS="noauto,user,exec,uid=1000,gid=1000"

if [ -n $2 ]; then
    DIRS_TO_MOUNT=$2
else
    DIRS_TO_MOUNT=($UHOME/.config/google-chrome $UHOME/.cache/google-chrome $UHOME/.opera)
fi

# helpers

# check if ramdir is already mounted
ramdr_is_mounted () { $(mount | grep "tmpfs on ${RAMDIR}" > /dev/null) }
# run command $2 throm su as user $1
run_as () { /bin/su "$1" -c "$2" }
# create dir in tmpfs if not already exists
maybe_create_ramdir () { ramdr_is_mounted || ( maybe_mkdir $RAMDIR; mount -t tmpfs -o $TMPFS_OPTS tmpfs $RAMDIR ) }
# fill ramdir with data
copy_to_ramdir () { run_as $USER "cp -r $1 $RAMDIR" }
# recursivly rsync 2 dirs
sync_it () { run_as $USER "cp -au $1/* $2/" }
# mkdir if not exist
maybe_mkdir () { [ ! -e $1 ] && run_as $USER "mkdir $1"}
# wrapper aroung mount --bind
bind_to_hdd () { maybe_mkdir $2; mount --bind $1 $2 }
# just a sematnic wrapper
unbind () { umount $1 &>dev/null }
# rm if exists
maybe_rm () { [ -e $1 ] && rm -r $1 }
# check if lock exists
chk_state () { if [ -e $LOCK ] && exit 1 }
# show error msgs; and break
err() { echo $@; exit 1 }

# main logic

start() { maybe_create_ramdir; 
          for dir in $DIRS_TO_MOUNT
              (copy_to_ramdir $dir
              bind_to_hdd $RAMDIR/$(basename $dir) $dir) && touch $LOCK }

stop() { for dir in $DIRS_TO_MOUNT
            (unbind $RAMDIR/$(basename $dir) && 
             sync_it $RAMDIR/$(basename $dir) $dir ||
             err "$dir is already in use") && (umount $RAMDIR; rm $LOCK) }

case $1 in 
    start) 
        if [ chk_state ];then start; else err "already_running";fi
        ;;
    stop) 
        if [ chk_state ];then stop;  else err "not_running";fi
        ;;
    *) exit 1
esac
