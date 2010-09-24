#!/bin/zsh
typeset -a CONFIG
typeset -a CACHE
USER="ask"
LOCK="/var/run/conf2ram_lock"
CONFIG=(/home/$USER/.config /home/$USER/.config.hdd)
CACHE=(/home/$USER/.cache /home/$USER/.cache.hdd)

# run command $2 throm su as user $1
run_as () { /bin/su $1 -c "$2" }
#mount to ram using ramfs
mount_it () { mount -t ramfs -o defaults,noatime,mode=1777 ramfs $1 }
# recursivly rsync 2 dirs
sync_it () { run_as $USER "cp -afu $1/* $2/" }
# mkdir if not exist
maybe_mkdir () { [ ! -e $1 ] && run_as $USER "mkdir $1" }
# wrapper aroung mount --bind
bind_to_hdd () { maybe_mkdir $2; mount --bind $1 $2 }
# umount both volumes
umount_all () { umount $1; umount $2 }
# rm if exists
maybe_rm () { [ -e $1 ] && run_as $USER "rm -r $1" }
# check if lock exists
chk_state () { if [ -e $LOCK ] && echo 1 || echo 0 }

# Show error msgs
already_running() { echo "Alerady started" }
not_running() { echo "not started yet" }

#acepts array of real and backup dirs
start() { typeset -a args;args=($1 $2);
          bind_to_hdd $args; mount_it $args[1]; sync_it ${(Oa)args} } # (Oa) - Reverse order

stop() { typeset -a args;args=($1 $2);
         sync_it $args; umount_all $args; maybe_rm $args[2]}

case $1 in 
    start) [ $(chk_state) -eq 0 ] && (touch $LOCK; start $CONFIG; start $CACHE) || already_running
        ;;
    stop) [ $(chk_state) -eq 1 ] && (rm $LOCK; stop $CONFIG; stop $CACHE) || not_running
        ;;
    *) exit 1
esac
