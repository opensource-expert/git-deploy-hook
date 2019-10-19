#!/usr/bin/env bash
#
# A command line wrapper to run the git hook directly
#  
# Usage: 
#  ./run_hook.sh BARE_REPOS BRANCH REV RSYNC_URI [RSYNC_OPTS] 

# Bash strict mode
set -euo pipefail

LOCAL_HOOK_SCRIPT=$(dirname $(readlink -f $0))/git-deploy-hook.sh
GIT_USER=git

# Arguments
HOOK_SCRIPT=$1
if [[ -z $HOOK_SCRIPT ]] ; then
  HOOK_SCRIPT=$LOCAL_HOOK_SCRIPT
fi
BARE_REPOS=$2
BRANCH=$3
REV=$4
RSYNC_URI=$5
RSYNC_OPTS=""
if [[ $# -ge 6 && -n $6 ]] ; then
  RSYNC_OPTS="$6"
fi

# Checks

if [[ ! -x $HOOK_SCRIPT ]] ; then
  echo "$0:failure: HOOK_SCRIPT '$HOOK_SCRIPT' not found or not executable"
  exit 1
fi

if [[ ! -d $BARE_REPOS ]] ; then
  echo "$0:failure: BARE_REPOS not a directory: '$BARE_REPOS'"
  exit 1
fi

# RUN
# catch exit code, so strict mode disabled
set +e
# export env var for the script in th GIT_USER environment
su - $GIT_USER -c "cd $BARE_REPOS && \
   RSYNC_OPTS=\"$RSYNC_OPTS\" RSYNC_URI=\"$RSYNC_URI\" RSYNC_RSH=\"$RSYNC_RSH\"\
   $HOOK_SCRIPT <<< \"OLD $REV refs/heads/$BRANCH\""
res=$?
set -e
echo "run_hook.sh: res: $res"
exit $res
