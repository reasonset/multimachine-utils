#!/bin/zsh

typeset -i retry=3

typeset ename="$1"
shift

mount_path="${@[-1]}"

if mount | grep -qF "$mount_path"
then
  notify-send -a openEncfs -t 5 -i lock "$mount_path is already mounted."
  exit 0
fi

if ! keyring get localencfs $ename > /dev/null
then
  notify-send -a openEncfs -t 5 -i lock "$ename doesn't exist in keyring."
  exit 1
fi

while (( retry >= 0 ))
do
  if encfs --extpass="keyring get localencfs $ename" -S "$@" >>| $HOME/.open_encfs.$ename.log 2>&1
  then
    notify-send -a openEncfs -t 5 -i lock "$mount_path is now avilable."
    exit
  fi
  notify-send -a openEncfs -t 5 -i lock "Failed to mount $mount_path, waiting for retry..."
  (( retry-- ))
  sleep 10
done

notify-send -a openEncfs -t 5 -i lock "Failed to mount $ename"
