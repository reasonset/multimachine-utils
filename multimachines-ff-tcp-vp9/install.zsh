#!/bin/zsh

if [[ -z "$1" ]] || [[ ! -d "$1" ]]
then
  print "Usage: install.zsh <dir_on_path>" >&2
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}"

if [[ ! -e "$config_dir/reaonset" ]]
then
  mkdir -pv "$config_dir/reaonset"
fi

if [[ ! -e "$state_dir/reaonset/mmfft9" ]]
then
  mkdir -pv "$state_dir/reaonset/mmfft9"
fi