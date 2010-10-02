#!/bin/zsh
USER="ask"
UHOME="/home/$USER"
RAMDIR="$UHOME/.ramdir"
LOCK="/var/run/conf2ram_lock"
DIRS_TO_MOUNT=($UHOME/.local/share $UHOME/.config $UHOME/.cache)

# helpers

# run command $2 throm su as user $1
run_as () { /bin/su "$1" -c "$2" }
# create dir in tmpfs
create_ramdir () { maybe_mkdir $RAMDIR; mount -t tmpfs -o defaults,noatime,mode=177 tmpfs $RAMDIR }
# fill ramdir with data
copy_to_ramdir () { run_as $USER "cp -r $1 $RAMDIR" }
# recursivly rsync 2 dirs
sync_it () { run_as $USER "cp -au $1/* $2/" }
# mkdir if not exist
maybe_mkdir () { [ ! -e $1 ] && run_as $USER "mkdir $1"}
# wrapper aroung mount --bind
bind_to_hdd () { maybe_mkdir $2; mount --bind $1 $2 }
# just a sematnic wrapper
unbind () { umount $1 }
# rm if exists
maybe_rm () { [ -e $1 ] && rm -r $1 }
# check if lock exists
chk_state () { if [ -e $LOCK ] && echo 1 || echo 0 }
# show error msgs
err() { echo $@ }

# main logic

start() { create_ramdir
        for dir in $DIRS_TO_MOUNT
            ( copy_to_ramdir $dir 
              bind_to_hdd $RAMDIR/$(basename $dir) $dir )
        touch $LOCK 
    }

stop() { for dir in $DIRS_TO_MOUNT
            ( unbind $RAMDIR/$(basename $dir)
              if [ ! $? -eq 0 ]; then
                  err "$dir is already in use" && exit 1
              else
                  sync_it $RAMDIR/$(basename $dir) $dir
              fi )
        umount $RAMDIR
        rm $LOCK
     }

case $1 in 
    start) 
        if [ $(chk_state) -eq 0 ] && start || err "already_running"
        ;;
    stop) 
        if [ $(chk_state) -eq 1 ] && stop || err "not_running"
        ;;
    *) exit 1
esac
