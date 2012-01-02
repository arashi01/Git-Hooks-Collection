#!/bin/bash

USERNAME=""
PASSWORD=""
GIT_EXECUTABLE="git" # inlcuing path if not included in $PATH
PERL=/opt/local/bin/perl5.12 # perl exectubale
PATH_TO_HOOKS=/home/schadr/git/agilefant/.git/hooks/ # hooks directory of the local git repository

COOKIE_FILE="/tmp/rtc-cookies" #file to store jazz cookies
HOST="https://jazz.net/hub/ccm" #jazz server url
COMMIT_URL="https://github.com/SuperAmerica/agilefant/commit/" #remote repository
WORK_ITEM_SEARCH_STRING="(W|w)ork\\s*(I|i)tem:\\s*"


$PERL $PATH_TO_HOOKS$1 $USERNAME $PASSWORD $GIT_EXECUTABLE $COOKIE_FILE $HOST $COMMIT_URL $WORK_ITEM_SEARCH_STRING $@

if [ $2 -eq 1 ] ; then
  echo "deleting COOKIE FILE"
  rm $COOKIE_FILE
fi
