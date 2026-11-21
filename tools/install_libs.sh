#!/usr/bin/env bash
# Instala as bibliotecas Haxe do projeto (usado no Codespaces e no GitHub Actions).
set -e
haxelib install lime --quiet || true
haxelib install openfl --quiet || true
haxelib install flixel --quiet || true
haxelib install flixel-addons --quiet || true
haxelib install hscript --quiet || true
haxelib git linc_luajit https://github.com/nebulazorua/linc_luajit || true
haxelib run lime setup -y || true
haxelib list
