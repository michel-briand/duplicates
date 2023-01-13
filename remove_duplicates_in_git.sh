#!/bin/bash
#
# given a list of duplicate images
# this script display sensible information
# for the user to choose which image to keep
# and confirm deletion of dupplicates
#
# - can use Terminology inline image feature
#   (requires ethumb)
#
# (c) 2023 Michel Briand
#
# This work is licensed under a Creative Commons
# Attribution-ShareAlike 4.0 International License.
# https://creativecommons.org/licenses/by-sa/4.0/


# This script must be invoked with an argument: a file with all
# duplicate images, one path per line.

if [ -z "$1" ] ; then
    echo "Error, script requires an argument: file name of image list" >&2
    exit 1
fi

if [ ! -e "$1" ] ; then
    echo "Error, file not found: $1" >&2
    exit 1
fi

list=$1

# When script has displayed all the duplicate images, it presents a
# choice for the user to choose the image to keep, and if this number
# is typed the default choice is kept

default_choice=0

# Bash booleans (opposite of usual logic)
TRUE=0
FALSE=1

files=()
thumbs=()

# open list on fd 3
exec 3< $list

n=0
while IFS= read -u 3 -r line; do

    n=$((n+1))

    if [ "$TERMINOLOGY" == "1" ] ; then
        echo "$PWD/$line"        
        f=$(ethumb "$line" | sed -e 's/^[^=]*//' -e 's/^....//' -e "s/'.*//")
        tycat $f
        thumbs+=("$f")
    fi

    files+=("$line") # here " are important for filename with space
    s=$(stat --printf='%s %y' "$line" | xargs)
    printf "%s\t%-40s\t%s\n" "$n" "$line" "$s"
    printf "\n"
done

# close list
exec 3<&-

# == INTERACTIVE FUNCTIONS
_ask_user_yes_no() { #1: message
    while [ $TRUE ] ; do
	read -e -n 1 -p "$1 (Y|n) ? "
	case $REPLY in
	    y|Y|"") return $TRUE ;;
	    n|N) return $FALSE ;;
	esac
    done
}

_ask_user_int_choices() { #1: message, #2: default choice, #3: max
    local def=$2
    local max=$3
    local prompt="$1 ([$def] `seq -s ' ' $max`) ? (type $default_choice for default choice [/] to choose ALL [p] to pass this image and [q] to abort) "
    choice=
    while [ $TRUE ] ; do
        if [ $max -gt 9 ] ; then
            # when max>9, we need to input 2 characters, NOT TESTED
            read -e -n 2 -p "$prompt"
        else
            # case when max<=9, only one character needed
            # it's more user friendly to not expect enter key
	    read -e -n 1 -p "$prompt"
        fi

        case $REPLY in
            $default_choice|$def|"")
                choice=$def
                return $TRUE
                ;;
            p|P)
                choice=pass
                return $TRUE
                ;;
            q|Q)
                choice=quit
                return $TRUE
                ;;
            "/")
                choice=all
                return $TRUE
                ;;
	    *) ;;
        esac

        re='^[0-9]+$'
        if ! [[ $REPLY =~ $re ]] ; then
            echo "error: Not a number: $REPLY" >&2
            continue
        fi
        choice=$REPLY
        return $TRUE

    done
}

choice=

# What could be the default choice proposed to the user ?
# - alphabet order (works well if directory is somehow sorted by date)
# - modtime order (TODO:)
# At the moment, pick up the first item in the list.
proposed_def=1

if ! _ask_user_int_choices "Choose image to keep" $proposed_def $n ; then
    echo "Error in choice routine" >&2
    exit 1
fi

if [ -z "$choice" ] ; then
    echo "Error, choice empty" >&2
    exit 1
fi

case "$choice" in
    "quit") # quit with an error
        echo "User abort" >&2
        exit 1
        ;;
    "pass") # quit without error
        echo "User abort this step only" >&2
        exit 0
        ;;
    "all") # remove the complete list
        :
        ;;
    *) # check numeric choice
        if [[ $choice -gt $n ]]; then
            echo "Error, number out of range: $choice"
            exit 1
        fi
        ;;
esac

echo "choice = $choice"
echo "${files[$choice]}"

# Now that user confirmed the file to remove (choice)
# the script removes this path from the list

list2=$(mktemp)

if [ "$choice" != "all" ] ; then
    # remove user's choice
    # (sed lines begin at 1)
    cat $list |sed -e "${choice}d" > $list2
else
    # remove all
    cat $list > $list2
fi

echo "Removal list ($list2):"
cat $list2

# Now, the script creates a batch file to issue
# removal commands, and ask the user to confirm

batch=$(mktemp)

# open list2 on fd 3
exec 3< $list2
while IFS= read -u 3 -r line; do
    echo git rm \"$line\" >> $batch
done
# close list2
exec 3<&-

rm -f $list2

echo
echo "COMMANDS TO BE EXECUTED:"
echo "------------------------"
cat $batch
echo
if ! _ask_user_yes_no "Confirm commands to be executed" ; then
    rm -f $batch
    echo "User abort" >&2
    exit 0
fi

echo "Execute batch script..."
sh $batch
r=$?

rm -f  $batch

# Return code from execution line above
exit $r
