#!/bin/bash
#
# find duplicates in git
# this script uses git aliases found here [1]
#
# (c) 2023 Michel Briand
#
# This work is licensed under a Creative Commons
# Attribution-ShareAlike 4.0 International License.
# https://creativecommons.org/licenses/by-sa/4.0/
#
# [1] https://stackoverflow.com/questions/224687/git-find-duplicate-blobs-files-in-this-tree
#
# I've modified a little bit the 'git dupes' alias
# to create the 'git dupes2' alias to group duplicates
# and be able to create a file for each

# Insert this in your ~/.gitconfig in the [alias] section
#     dupes2 = !"cd `pwd`/$GIT_PREFIX && git ls-tree -r HEAD | cut -c 13- | sort | uniq -w 40 --group=append"

stats=$(mktemp)
tmpd=$(mktemp -d -t remove_dups_$$_XXXX)

n=0
m=0
N=0
h=
list=()

git dupes2 | while read hash path ; do
    if [ -z "$hash" ] ; then
        case $n in
            0) echo "zero dup"; exit 0;;
            1) : ;;
            *) k=0
               if [ -z "${list[*]}" ] ; then
                   echo "internal error" >&2
                   exit
               fi
               m=$((m+1))
               for i in "${list[@]}" ; do
                   printf "$i\n" >> $tmpd/$h
                   k=$((k+1))
               done
               N=$((N+k))
               #echo N=$N
               ;;
        esac
        n=0
        h=
        list=()
        continue
    fi

    n=$((n+1))
    h=$hash
    list+=("$path") # here " are important for filename with space
    echo "$m $N" > $stats
done

read -r m N <<< $(cat $stats)

echo "$N duplicates"
if [ $m -gt 0 ] ; then
    mean=$(echo "scale=2
$N/$m" | bc)
    echo "$mean mean number of duplicates"
fi
echo "Directory to use with script 'remove_all_duplicates_in_git.sh':"
echo $tmpd
rm -f $stats
