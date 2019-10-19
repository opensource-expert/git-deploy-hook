#!/usr/bin/env bash
#
# git-deploy-hook.sh
#
# git post-receive hook to check out branches to a rsync destination.
#
# Copyright 2012 K and H Research Company.
# License: GNU General Public License, version 3+
# Original Author: Eugene E. Kashpureff Jr
# Author:          Sylvain Viart 2019
#

# bash strict mode
set -euo pipefail

##
## Documentation
##

## Installation
#
# To install git-deploy, copy this file to the hooks/ directory of a repository
# as "post-receive". Note that there is NO extension!
#
# You will need to set the git config variable deploy.$FOO.uri in order for this
# script to do anything. See the 'Configuration' section for more information.
#
# In order to function properly you must have rsync and the git-core suite on
# your system. If these are in non-standard locations or not within PATH you
# should set the RSYNC and GIT vars below. Other common utilities such as mkdir,
# cp, find, rm, umask, and tar are also required, but if you don't already have
# these you should probably see a psychiatrist.
#

## Configuration
#
# Several configuration options are supported by git-deploy, only one of which
# is mandatory(deploy.$FOO.uri). These options are all set via git-config.
# Several constants(see below) may be changed in the script itself, but you
# should not need to do so on a sane system. In all of the following, $FOO is
# the name of the branch which you wish to have automagically deployed.
#
# deploy.$FOO.opts
# Set of options to pass to rsync. git-deploy defaults to "-rt --delete",
# which will work (r)ecursively, attempt to maintain (t)imestamps, and
# (delete) files which do not exist in the source. You will likely want to
# add the --exclude=foo/ option to guard agaisnt deletion of ephermeral
# data directories used by your application. Please note that no injection
# checking is done against this option(patches welcome).
#
# deploy.$FOO.timestamps
# Whether or not to attempt to maintain timestamps on the work-tree which
# is checked-out. If true git-log is used to find the last commit which
# affected each path in the worktre, and then 'touch -m' is used to set
# the modification time to this date.
#
# deploy.$FOO.uri
# rsync URI which should be deployed to for branch $FOO. This can be any
# scheme which is known to 'rsync', including a local filesystem path, or
# a remote host(via SSH)
#

## Usage
#
# To use git-deploy simply push into your repo and git's hook system will take
# care of the rest. Errors and information will be shown to you as the script
# works its magic. If you wish to manually deploy you can do so by piping, on
# stdin, the same data that is fed to any git pre-receive hook.
#
# The script also accepts an overriding argument URI to replace deploy.$FOO.uri

## Todo
#
# 1) Split out the "meat" to a git-deploy script which can be invoked via the
# 'git' binary in a non-bare repository
#
# 2) Improve documentation wording - find an English teacher to run it by or
# something.
#

##
## functions
##

log() {
    if [[ $# -gt 1 && $1 == '-e' ]] ; then
        shift
        echo "$*"
    fi
    if [[ -n $LOGFILE ]] ; then
        echo "$(date "+%Y-%m-%d_%H:%M:%S") $*" >> $LOGFILE
    fi
}

# a rsync wrapper:
# Usage: do_rsync VAR_NAME_STATUS "$RSYNC_RSH" "$opts" "$SRC" "$DEST"
do_rsync() {
  local var_name_status=$1
  log "do_rsync: $RSYNC $*"
  RSYNC_RSH=$2
  export RSYNC_RSH
  log "do_rsync: RSYNC_RSH='$RSYNC_RSH'"
  opts_list=( $3 )
  local res
  # catching exit code
  set +e
  $RSYNC "${opts_list[@]}" "$4" "$5"
  res=$?
  set -e
  # print inside the var
  printf -v $var_name_status "$res"
}

# wrapper to get ENV Var or git_key from git config
get_git_config() {
  local env_var=$1
  local git_key=$2
  local value
  # read the given variable name value in a local var
  eval "value=\$$env_var"
  if [[ -n $value ]] ; then
    >&2 echo "$env_var forced over $git_key: '$value'"
    echo "$value"
  else
    # empty value is OK for strict mode
    git config --get "$git_key" || true
  fi
}

##
## Constants
##

# Path to the git binary
GIT=$(which git)

# Path to the rsync binary
RSYNC=$(which rsync)

# Temporary directory
TMP="/tmp"

# path to a writable log file (empty for no logging)
LOGFILE=/home/preprod/deploy.log

# Repo directory
export GIT_DIR=$(pwd)
log "cwd: $PWD"

# environment override value from exported ENV
URI="${RSYNC_URI:-}"
RSYNC_OPTS="${RSYNC_OPTS:-}"

##
## Variables
##


##
## Sanity checks
##

## Existence of git
if [ ! -f "${GIT}" ]
then
  # Error && exit
  echo "Error: git binary not found"
  exit 255
fi

## Existence of rsync
if [ ! -f "${RSYNC}" ]
then
  # Error && exit
  echo "Error: rsync binary not found"
  exit 255
fi

## Existence of tmpdir
if [ ! -d "${TMP}" ]
then
  # Error && exit
  echo "Error: tmp directory not found"
  exit 255
fi


##
## Runtime
##

# Create scratch dir
if mkdir "${TMP}/git-deploy.$$"
then
  scratch="${TMP}/git-deploy.$$"
else
  # Error && exit
  echo "Error: unable to create scratch dir or already exists."
  exit 1
fi

# an array for collecting loop rsync resturned values
declare -a ret_status

# Loop through stdin (multiple branch could be involved if git push --all)
while read old new ref
do
  log "progessing: $old $new $ref"
  # Find branch name
  branch=${ref#"refs/heads/"}

  # Check branch name
  if [ -z "${branch}" ]
  then
    echo "Refspec ${ref} is not a branch. Skipped!"
    continue
  fi

  # Don't attempt to handle deleted branches
  if [ "${new}" = "0000000000000000000000000000000000000000" ]
  then
    # Error && skip branch
    echo "Branch ${branch} deleted. Skipped!"
    continue
  fi

  ## Attempt to update
  echo "Branch ${branch} updated. Deploying ref: '$new' ..."

  # Deploy destination (if the URI is forced deploy always happen)
  # You cant test this failure from wrapper.
  dest=$(get_git_config URI "deploy.${branch}.uri")
  if [ -z "${dest}" ]
  then
    echo "Error: Destination not set! Deploy failed."
    ret_status+=( 1 )
    continue
  fi
  echo "Destination: "${dest}

  # Rsync options
  opts=$(get_git_config RSYNC_OPTS "deploy.${branch}.opts")
  RSYNC_RSH=$(get_git_config RSYNC_RSH "deploy.${branch}.rsync_rsh")
  if [ -z "${opts}" ]
  then
    opts="-rt --delete --itemize-changes"
  fi
  echo "Options: ${opts} +RSYNC_RSH: '$RSYNC_RSH'"

  # Create directory to archive into
  mkdir "${scratch}/${branch}"

  # Drop into scratchdir
  cd "${scratch}/${branch}"

  # Set umask
  umask 007

  # Get a copy of worktree in our scratchdir
  $GIT archive --format=tar ${new} | tar xf -

  # Alter modification times?
  timestamps=$(git config --bool --get "deploy.${branch}.timestamps" || true)
  if [ "${timestamps}" == "true" ]
  then
    # Set modification times to last-changed
    for file in $(find ./ -type f)
    do
      # Get the date of the last commit
      last=$(git log ${branch} --pretty=format:%ad --date=rfc -1 -- ${file})
      # Set the modification time
      touch -t $(date -d "${last}" +%Y%m%d%H%M.%S) ${file}
    done
  fi

  # Copy worktree to destination
  # status will be filled by do_rsync
  status=0
  do_rsync status "$RSYNC_RSH" "$opts" "${scratch}/${branch}/" "${dest}"

  if [ "${status}" -ne "0" ]
  then
    echo "Error: rsync exited with exit code ${status}. Deploy may not have been successful. Please review the error log above."
    ret_status+=( $status )
  else
    echo "Deploy successful!"
  fi
  echo ""
done


##
## Cleanup
##

# Remove scratch dir
#rm -rf "${scratch}"

# Unset environment variables
unset GIT RSYNC TMP GIT_DIR scratch old new ref branch dest optstimestamps file
unset last RSYNC_RSH RSYNC_URI RSYNC_OPTS

# compute return value form ret_status array
res=0
for v in ${ret_status[@]}
do
  res=$(($res + $v))
done
exit $res
