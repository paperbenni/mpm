#!/bin/bash

RAW="https://raw.githubusercontent.com/paperbenni/mpm-repo/master"

if [ -z "$MC" ]; then
    if [ -e version_history.json ]; then
        MC=1."$(grep -o '1\.[0-9]*' version_history.json | grep -o '[^\.]*$' | sort -n | tail -1)"
    else
        MC="$(curl -s $RAW/latest)"
    fi
fi

command -v java &>/dev/null || echo "please install java" && exit 1

# get a file from the mpm repo
getmpm() {
    test -e $1 || wget -q "$RAW/spigot/$MC/$1"
}

# download spigot jar
spigotdl() {
    [ -e spigot.jar ] || echo "spigot already existing" && return
    export MC=${1:-$MC}
    echo "downloading minecraft version $MC"
    wget -q "$RAW/spigot/$MC/spigot.jar"
    [ -e server-icon.png ] || wget -O server-icon.png -q "$RAW/paperbenni64.png"
    cat eula.txt || echo "eula=true" >eula.txt #accept eula
    getmpm bukkit.yml
    getmpm paper.yml
    getmpm spigot.yml
    getmpm server.properties
    ls *.html &>/dev/null && rm *.html
}
