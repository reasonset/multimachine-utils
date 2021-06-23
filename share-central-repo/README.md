# Share central repo

"Share central repo" for self distributed writing support.

It is intended to be used in the following ways:

The central Mercurial/Git repository is stored in EncFS on a cloud drive (e.g. Dropbox), and each computer works on a local repository that it clones and reflects in the central repository.

# Requirement

* Bash
* Zsh
* EncFS
* keyring(1) (e.g. pyhthon-keyring)
* notify-send(1)
* Yad
* Ruby >= 2.1.0
* Perl >= 5.4.0

# Usage

## Install

Copy on your PATH every executable file.

## Setup

1. Set password to your keyring. `keyring set localencfs Document` set `Document`'s key.
2. Copy `encfs-sample.desktop` to your `~/.local/share/applications/` directory and rename.
3. Edit `Exec` line. `open_encfs.zsh` takes arguments key name, EncFS encrypted directory and mount point.
4. If the directory is a repository farm, use `repos-treat.zsh` instead of `open_encfs.zsh`

`repos-treat.zsh` requires `~/.config/reasonset/workrepos.yaml`.
It have key as "name" and value as "repository working root".

# Tips

## If you like Git not Mercurial

Set `YES` to `$I_LIKE_GIT_NOT_MERCURIAL` environment variable.

Or create link `repos-treat-git.zsh` to `repos-treat.zsh` and execute `repos-treat-git.zsh`.