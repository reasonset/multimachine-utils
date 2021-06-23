#!/bin/bash

function build_repoliststr {
  ruby -ryaml -e 'print YAML.load(ARGF).map {|k,v| [k, v.sub(%r:^\$HOME/:, ENV["HOME"] + "/").sub(%r@^\$DOC(?:UMENTS)?/@, `xdg-user-dir DOCUMENTS`.chomp + "/").sub(%r:^(?=[^/]):, ENV["HOME"] + "/")] }.map{|i| i.join(":::") }.join("%%%")' ${XDG_CONFIG_HOME:-$HOME/.config}/reasonset/workrepos.yaml
}

export repoliststr="$(build_repoliststr)"

function splitrepos {
  echo $repoliststr | sed 's:%%%:\n:g'
}
export -f splitrepos

repolist=($(splitrepos))

function getchanges {
  if [[ "$I_LIKE_GIT_NOT_MERCURIAL" == "YES" ]]
  then
    (
      cd $(getpath $1)
      echo -n "2:"
      git status | perl -pe 's/\n/\\n/'
    )
  else
    (
      cd $(getpath $1)
      echo -n "2:"
      hg status | perl -pe 's/\n/\\n/'
    )
  fi
}
export -f getchanges

function getdiff {
  if [[ "$I_LIKE_GIT_NOT_MERCURIAL" == "YES" ]]
  then
    (
      cd $(getpath $1)
      echo -n "2:"
      git diff | perl -pe 's/\n/\\n/'
    )
  else
    (
      cd $(getpath $1)
      echo -n "2:"
      hg diff | perl -pe 's/\n/\\n/'
    )
  fi
}
export -f getdiff


function commit {
  if [[ "$I_LIKE_GIT_NOT_MERCURIAL" == "YES" ]]
  then
    (
      cd $(getpath $1)
      declare commitmsg="$2"
      if [[ -z $commitmsg ]]
      then
        commitmsg="Working snapshot from widget."
      fi
      echo -n "2:"
      if (gitt add -A && git commit -m "$commitmsg")
      then
        echo COMMITED.
      fi
    ) | perl -pe 's/\n/\\n/'
  else
    (
      cd $(getpath $1)
      declare commitmsg="$2"
      if [[ -z $commitmsg ]]
      then
        commitmsg="Working snapshot from widget."
      fi
      echo -n "2:"
      if hg commit -A -m "$commitmsg"
      then
        echo COMMITED.
      fi
    ) | perl -pe 's/\n/\\n/'
  fi
}
export -f commit

function getpath {
  declare -A repoaa
  for i in $(splitrepos)
  do
    declare -a r=(${i/:::/ })
    repoaa[${r[0]}]="${r[1]}"
  done
  echo ${repoaa[$1]}
}
export -f getpath

repos="$(for i in ${repolist[*]}
do
  declare repoentry=(${i/:::/ })
  (
    cd ${repoentry[1]}
    if [[ -n "$(hg status)" ]]
    then
      echo ${repoentry[0]}
    fi
  )
done | perl -pe 's/\n/!/' | sed 's/!$//' )"

if [[ -z $repos ]]
then
  exit
fi

yad --width=1000 --height=600 --title="Repository Checker" --form --field='Repositories:CB' "$repos" --field="Changes:TXT" ""  --field="CHECK:FBTN" '@bash -c "getchanges %1"' --field="DIFF:FBTN" '@bash -c "getdiff %1"' --field="Commit Message" "" --field="COMMIT:FBTN" '@bash -c "commit %1 %4"' > /dev/null
