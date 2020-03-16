#!/bin/bash
if [ -z "$1" ]; then
    echo "installing mpm"
    curl -s https://raw.githubusercontent.com/paperbenni/mpm/master/mpm.sh | sudo tee /usr/local/bin/mpm
    sudo chmod 755 /usr/local/bin/mpm
    echo "done installing mpm"
else
    echo "removing mpm"
    [ -e /usr/local/bin/mpm ] && sudo rm /usr/local/bin/mpm
    [ -e ~/.cache/mpm ] && rm -rf ~/.cache/mpm
    echo "done removing mpm"
fi
