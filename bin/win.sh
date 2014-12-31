#!/bin/bash

if [[ $1 = "bg" ]];then
   BG="&"
   shift
fi

if [[ $# -eq 0 ]]; then
   echo "usage: $0 [bg] <program> [args]"
   exit 0
fi

CMD="$1"
shift

while [ -n "$1" ]; do
   case "$1" in
     set*) ARG=\"$1\";;
     [+-]*) ARG=$1;;
     *) ARG=\"`cygpath -w "$1"`\"
       ;;
   esac
   CMD="$CMD $ARG";
   shift;
done

echo $CMD $BG
eval $CMD $BG
