#!/bin/bash
#
# remove all duplicates found by find_duplicates_in_git.sh
# using a git branch
#
# (c) 2023 Michel Briand
#
# This work is licensed under a Creative Commons
# Attribution-ShareAlike 4.0 International License.
# https://creativecommons.org/licenses/by-sa/4.0/


# This script loops over duplicate images lists stored in 
# a temporary directory and calls 'remove_duplicates_in_git.sh'

tmpd=$1

now=$(date "+%H%M%S")
br=_remove_dups_$now

echo "creating a new branch [$br] to work in"
git checkout -b $br

for i in $tmpd/*; do
    hash=${i##*/}

    echo "calling remove_duplicates_in_git.sh for hash $hash"
    if ! remove_duplicates_in_git.sh $i ; then
        echo "Error or abort in remove sub-program" >&2
        exit 1
    fi

    if [ -z "$(git status --porcelain)" ]; then 
        # Working directory clean
        echo "working directory clean, continue"
    else 
        # Uncommitted changes
        echo "calling 'git add -u' and 'git commit'"
        git add -u
        git commit -m"removed duplicates for hash $hash"
    fi
done

echo "you can now merge the branch [$br] into your main branch"
