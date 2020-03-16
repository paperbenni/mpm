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

dlplugin() {
    checkspigot || echo "warning: no spigot installation found"
    if [ -z "$@" ]; then
        echo "usage: mpm pluginname"
        return
    fi

    # loop through multiple plugin args
    if [ -n "$2" ]; then
        for i in "$@"; do
            dlplugin "$i"
        done
        return 0
    fi

    # install list of plugins from mpmfile
    if [ "$1" = "-f" ]; then
        if [ -e "mpmfile" ]; then
            while read p; do
                dlplugin "$p"
                echo "$p"
            done <mpmfile
        else
            echo "put your plugin names in an mpmfile"
        fi
        return 0
    fi

    # execute from either plugins or spigot dir
    if ! [ "${PWD#**/}" = "plugins" ]; then
        NOCD="set"
        [ -e plugins ] || mkdir plugins
        cd plugins
    fi

    [ -e "$1".jar ] && echo "plugin already existing" && return

    curl -s "$RAW/plugins/$1/$MC/$1.mpm" >"$1.mpm"
    if ! grep -q 'describe: ' "$1.mpm"; then
        rm $1.mpm
        echo "$1 is not a valid plugin"
        return 1
    fi

    # download actual plugin
    wget -q "$RAW/plugins/$1/$MC/$1.jar"

    if grep -q 'depend' "$1.mpm"; then
        echo "installing plugin $1 dependencies"
        DPENDENCIES="$(grep 'depend' $1.mpm)"
        for i in "$DPENDENCIES"; do
            dlplugin "${i#**:}"
        done
    fi

    # some plugins execute shell scripts after installing
    if grep -q 'hook' <"$1.mpm"; then
        pushd .
        echo "running plugin hooks"
        source <(curl -s "$RAW/plugins/$1/$MCVERSION/hook.sh")
        minehook
        popd
    fi

    if [ -n "$NOCD" ]; then
        cd ..
    fi
}
