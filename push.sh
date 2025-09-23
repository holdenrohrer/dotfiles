#!/bin/sh
if [ $UID -ne 0 ]; then
    echo 'Must be run as root!'
    exit 1
fi
rsync --delete -avh ./ /etc/nixos/
nixos-rebuild switch
