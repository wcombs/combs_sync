#!/bin/bash

cd $1

yes | git mergetool -t combsmerge
# check why this add is not working
git add .
git commit -a -m 'merge-fix auto-commit'
