#!/bin/zsh

if [[ ${0:t} == repos-treat-git.zsh ]]
then
  export I_LIKE_GIT_NOT_MERCURIAL=YES
fi

open_encfs.zsh "$@" && repos-checker.bash
