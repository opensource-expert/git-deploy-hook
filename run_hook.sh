#!/usr/bin/env bash
#
# Usage: 
#  echo "old_hash new_hash refs/heads/prod" > /tmp/input
#  su - git -c "bash $PWD/run_hook.sh '' HEAD"

set -euo pipefail

DEFAULT_REPOS=/var/lib/gitolite3/repositories/cleandrop/application-serveur/webapp.git
HOOK_SCRIPT=/var/lib/gitolite3/local/hooks/common/post-receive.d/git-deploy-hook.sh
HOOK_SCRIPT=$(dirname $(readlink -f $0))/git-deploy-hook.sh

BARE_REPOS=$1
REV=$2
REMOTE_HOST=""

echo $#

if [[ $# -ge 3 ]] ; then
  REMOTE_HOST=$3
  echo "REMOTE_HOST $REMOTE_HOST"
fi

if [[ $BARE_REPOS == '' ]] ; then
  BARE_REPOS=$DEFAULT_REPOS
fi

cd $BARE_REPOS
$HOOK_SCRIPT "$REMOTE_HOST" <<< "OLD $REV refs/heads/prod"
