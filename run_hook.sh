#!/usr/bin/env bash
#
# A command line wrapper to run the git hook directly
#  
# Usage: 
#  ./run_hook.sh BARE_REPOS BRANCH REV RSYNC_URI [RSYNC_OPTS] 

set -euo pipefail

HOOK_SCRIPT=$(dirname $(readlink -f $0))/git-deploy-hook.sh
GIT_USER=git

if [[ ! -x $HOOK_SCRIPT ]] ; then
  echo "$0:failure: HOOK_SCRIPT '$HOOK_SCRIPT' not found or not executable"
  exit 1
fi

# Arguments
BARE_REPOS=$1
BRANCH=$2
REV=$3
RSYNC_URI=$4
RSYNC_OPTS=""
if [[ $# -ge 5 && -n $5 ]] ; then
  RSYNC_OPTS="$5"
fi

if [[ ! -d $BARE_REPOS ]] ; then
  echo "$0:failure: not a directory '$BARE_REPOS'"
  exit 1
fi

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
