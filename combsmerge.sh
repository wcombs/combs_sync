#!/bin/bash

ORIGNAME=$1
LOCAL=$2
REMOTE=$4
HOSTNESS=`hostname`
PATHNESS=`pwd | sed -e 's/\//-/g'`

cp -p "${LOCAL}" "${ORIGNAME}.conflict-from-${HOSTNESS}:${PATHNESS}"
cp -p "${REMOTE}" "${ORIGNAME}.conflict-from-remote"
git rm "$ORIGNAME"

