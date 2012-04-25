#!/bin/bash

cd /Users/wcombs/code/this_repo

yes | git mergetool -t combsmerge
git add .
git commit -a -m 'merge-fix auto-commit'
