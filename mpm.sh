#!/bin/bash

# needs java
command -v java &>/dev/null || echo "please install java" && exit 1

# allow setting custom repos
if ! [ -e ~/.mpmrc ]; then
    RAW="https://raw.githubusercontent.com/paperbenni/mpm-repo/master"
else
    RAW="$(cat .mpmrc)"
fi

# detect mc version if not set manually
if [ -z "$MC" ]; then
    if [ -e version_history.json ]; then
        MC=1."$(grep -o '1\.[0-9]*' version_history.json | grep -o '[^\.]*$' | sort -n | tail -1)"
    else
        MC="$(curl -s $RAW/latest)"
    fi
fi

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

#jar opener with settings
pjava() {
    if [ -e ./"$1" ]; then
        MEMORY=${2:-650m}
        java -Xmx$MEMORY -Xms$MEMORY -XX:+AlwaysPreTouch -XX:+DisableExplicitGC \
            -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions \
            -XX:MaxGCPauseMillis=45 -XX:TargetSurvivorRatio=90 \
            -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 \
            -XX:InitiatingHeapOccupancyPercent=10 \
            -XX:G1MixedGCLiveThresholdPercent=50 \
            -jar "$1"
    else
        echo "file not existing, trying out other jar files!"
        pjava ./*.jar
    fi
}

# is there a valid spigot installation
checkspigot() {
    [ -e plugins ] && [ -e eula.txt ] && return 0
    return 1
}

# spigexe version memory
spigexe() {
    case "$1" in
    -f)
        java -jar spigot.jar
        ;;
    1.*)
        spigotdl "$1"
        pjava spigot.jar "$2"
        ;;
    *)
        spigotdl
        pjava spigot.jar "$1"
        ;;
    esac
}

spigotserveo() {
    nohup autossh -p 2222 -M 0 -R 25565:localhost:25565 paperbenni.mooo.com
}
