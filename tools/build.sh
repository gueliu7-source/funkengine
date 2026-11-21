#!/usr/bin/env bash
# Compila no Linux (Codespaces) só para conferir erros: ./tools/build.sh   (sem Lua: ./tools/build.sh -DNO_LUA)
haxelib run lime build linux "$@"
