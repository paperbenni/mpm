#!/bin/bash

# needs java
command -v java &>/dev/null || {
    echo "please install java"
    exit 1
}

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
    [ -e spigot.jar ] && {
        echo "spigot already existing"
        return
    }
    export MC=${1:-$MC}
    echo "downloading minecraft version $MC"
    wget -q "$RAW/spigot/$MC/spigot.jar"
    [ -e server-icon.png ] || wget -O server-icon.png -q "$RAW/paperbenni64.png"
    [ -e eula.txt ] || echo "eula=true" >eula.txt
    getmpm server.properties
    ls *.html &>/dev/null && rm *.html
}

lightconf() {
    getmpm bukkit.yml
    getmpm paper.yml
    getmpm spigot.yml
}

#jar opener with settings
pjava() {
    if [ -e ./"$1" ]; then
        MEMORY=${2:-650m}
        if [ -e ~/.nativeminecraft ]
        then
            echo "executing without special args"
            java -Xmx$MEMORY -Xms$MEMORY -jar "$1"
        else
            java -Xmx$MEMORY -Xms$MEMORY -XX:+AlwaysPreTouch -XX:+DisableExplicitGC \
                -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions \
                -XX:MaxGCPauseMillis=45 -XX:TargetSurvivorRatio=90 \
                -XX:G1NewSizePercent=50 -XX:G1MaxNewSizePercent=80 \
                -XX:InitiatingHeapOccupancyPercent=10 \
                -XX:G1MixedGCLiveThresholdPercent=50 \
                -jar "$1"
        fi
    else
        echo "file not existing, trying out other jar files!"
        pjava ./*.jar
    fi
}

# is there a valid spigot installation
checkspigot() {
    {
        {
            [ -e plugins ] && [ -e eula.txt ]
        } || {
            [ -e ../plugins ] && [ -e ../eula.txt ]
        }
    } && return 0
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

# establish a tcp tunnel
spigotserveo() {
    if [ "$1" = "-o" ]; then
        shift 1
        autossh -o StrictHostKeyChecking=no -p 2222 -M 0 -R "${1:-0}":localhost:"${2:-25565}" mc.paperbenni.xyz
    else
        nohup autossh -o StrictHostKeyChecking=no -p 2222 -M 0 -R "${1:-0}":localhost:"${2:-25565}" mc.paperbenni.xyz
    fi
}

# gets the hash of the last commit
lastcommit() {
    LINK='https://api.github.com/repos/paperbenni/mpm-repo/commits?path='"$(echo $1 | sed -s 's~/~%2F~g')"'&page=1&per_page=1'
    curl -s "$LINK" | jq -r '.[0].commit.url' | grep -o '[^/]*$'
}

# download a plugin into the plugins folder
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
    if ! [ "${PWD##*/}" = "plugins" ]; then
        NOCD="set"
        [ -e plugins ] || mkdir plugins
        cd plugins
    fi

    [ -e "$1".jar ] && echo "plugin already existing" && return

    curl -s "$RAW/plugins/$1/$MC/$1.mpm" >"$1.mpm"
    if ! grep -q '^describe:' "$1.mpm"; then
        rm $1.mpm
        echo "$1 is not a valid plugin"
        return 1
    fi

    # download actual plugin
    echo "installing plugin $1"
    wget -q "$RAW/plugins/$1/$MC/$1.jar"
    # commit needed for updating
    if grep -q 'github' <<<"$RAW"; then
        echo commit: $(lastcommit "plugins/$1/$MC/$1.jar") >>$1.mpm
    fi
    # some plugins execute shell scripts after installing
    if grep -q 'hook' <"$1.mpm"; then
        pushd .
        echo "running plugin hooks"
        curl -s "$RAW/plugins/$1/$MC/hook.sh" | bash
        popd
    fi

    if grep -q 'depend' "$1.mpm"; then
        echo "installing plugin $1 dependencies"
        DPENDENCIES="$(grep 'depend' $1.mpm)"
        for i in "$DPENDENCIES"; do
            dlplugin "${i#**:}"
        done
    fi

    if [ -n "$NOCD" ]; then
        cd ..
        unset NOCD
    fi
}

# display .mpm file of plugin
pluginfo() {
    PLUGTEXT="$(curl -s $RAW/plugins/$1/$MC/$1.mpm)"
    if grep -q 'describe:' <<<"$PLUGTEXT"; then
        echo "$PLUGTEXT"
    fi
}

# TODO: updater

# remove the last n lines from file
rmlast() {
    RMTIMES="${2:-1}"
    for i in $(seq $RMTIMES); do
        head -n -1 "$1" >tempfoo.txt
        mv tempfoo.txt "$1"
    done
}

#usage: mineuuid {playername}
# returns the mojang uuid fromt the username
mineuuid() {
    if [ -z "$1" ]; then
        echo 'Error: usage: mineuuid name [offline]'
        return 1
    fi
    if [ -z "$2" ]; then
        UUID_URL=https://api.mojang.com/users/profiles/minecraft/$1
        mojang_output="$(wget -qO- $UUID_URL)"
        rawUUID=${mojang_output:7:32}
        UUID=${rawUUID:0:8}-${rawUUID:8:4}-${rawUUID:12:4}-${rawUUID:16:4}-${rawUUID:20:12}
        echo $UUID
    else
        rawUUID=$(curl -s http://tools.glowingmines.eu/convertor/nick/"$1")
        rawUUID2=${rawUUID#*teduuid\":\"}
        UUID=${rawUUID2%\"*}
        echo "$UUID"
    fi
}

# ops the user $1
# execute in the spigot folder
mcop() {

    [ -e ops.json ] && touch ops.json
    [ -z "$1" ] && echo "usage: mcop username" && return

    if [ -e server.properties ] &&
        grep -q 'online-mode=true' server.properties; then
        UUID=$(mineuuid "$1")
    else
        UUID=$(mineuuid "$1" offline)
    fi

    if grep -q "$UUID" ops.json; then
        echo "already op"
        return 0
    fi

    if grep -q 'uuid' <ops.json; then
        rmlast ops.json 3
        echo "  }," >>ops.json
    else
        rm ops.json
        touch ops.json
        echo "[" >>ops.json
    fi

    echo "  {" >>ops.json
    echo "    \"uuid\": \"$UUID\", " >>ops.json
    echo "    \"name\": \"$1\", " >>ops.json
    echo "    \"level\": 4, " >>ops.json
    echo "    \"bypassesPlayerLimit\": false" >>ops.json
    echo "  }" >>ops.json
    echo "]" >>ops.json
    echo "" >>ops.json
}

USAGE="usage: mpm //todo"

if [ -z "$1" ]; then
    echo "$USAGE"
    exit
else
    ACTION="$1"
    shift 1
fi

case "$ACTION" in
plugin)
    dlplugin $@
    ;;
spigot)
    spigotdl $@
    ;;
start)
    spigexe $@
    ;;
op)
    mcop $@
    ;;
tunnel)
    spigotserveo $@
    ;;
install)
    dlplugin -f
    ;;
info)
    pluginfo "$1"
    ;;
*)
    echo "$USAGE"
    ;;
esac
