#!/bin/bash

TOP=$( [ -z $1 ] && echo 10 || echo $1)

declare -a mem=($(ps -e -orss=,args= | awk '{print $1 " " $2 }' | awk '{tot[$2]+=$1;count[$2]++} END {for (i in tot) {print tot[i],i,count[i]}}' | sort -n | tail -n $TOP | sort -nr | awk '{hr=$1/1024; printf("%13.2fM|%s", hr, $2)}' | tr '\n' ' '))
declare -a swp=($(cat /proc/*/status | grep -E 'VmSwap:|Name:' | grep -B1 'VmSwap' | cut -d':' -f2 | grep -v -- '--' | grep -o -E '[a-zA-Z0-9]+.*$' | cut -d' ' -f1 | xargs -n2 echo | sort -hrk2 | awk '{hr=$2/1024; if (hr>0) printf("%13.2fM|%s", hr,$1)}' | tr '\n' ' '))


printf "%-9s %35s %-9s %20s\n" "MEMORY" "Top $TOP processes       " "SWAP" ""
for (( j=0; j<${#mem[@]}; j++ ));
do
  printf "%9s %-35s %9s %-20s\n" $(echo ${mem[$j]} | sed 's/|/ /;s/usr\///;s/bin\///;s/lib\///;s/\///') $(echo ${swp[$j]} | sed 's/|/ /')
done
echo
printf "%9s %-35s %9s %-20s\n" $(free -m | awk '/Mem/{print($3"M "$1)}'| sed 's/Mem:/MemTotal/') $(free -m | awk '/Swap/{print($3"M "$1)}' | sed 's/Swap:/SwapTotal/')
