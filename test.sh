#!/bin/bash

ctrl_c() {
        echo "** Trapped CTRL-C"
        break
}

# trap ctrl-c and call ctrl_c()
trap 'ctrl_c' INT

for i in `seq 1 5`; do
    sleep 1
    echo -n "."
done
