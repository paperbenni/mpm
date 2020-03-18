
<div align="center">
    <h1>mpm</h1>
    <p>The Missing Package Manager for Minecraft</p>
    <img width="300" src="https://raw.githubusercontent.com/paperbenni/mpm/master/logo/logo.png">
</div>

# mpm
---------------------------------------

## Install mpm
```
curl -Ls https://git.io/JvXZm | bash
```
Works on Linux and Mac. If you use Windows you are probably more comfortable with hunting down files on the web. 

dependencies to take full advantage of mpm: bash, wget, curl, java and autossh

## Usage
mpm has several subcommands

Create a spigot install in the current directory:

```sh
mpm spigot versionnumber
# example
mpm spigot 1.15
```

Start the current spigot install
```sh
mpm start memory
# example
mpm start 4000m
```

Install a plugin
(Execute in the spigot or plugins directory)
```sh
mpm plugin
```

Give op to a person when the server is not running
```sh
mpm op username
```
