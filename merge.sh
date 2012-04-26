#!/bin/bash

cd $1

yes | git mergetool -t combsmerge

