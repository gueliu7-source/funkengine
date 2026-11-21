#!/usr/bin/env bash
# Instala Haxe 4.3.6 + bibliotecas no Codespaces (roda sozinho na criação).
set -e
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends g++ gcc make libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libx11-dev libxext-dev libxi-dev libxrandr-dev libxinerama-dev libpulse-dev libpng-dev libgtk2.0-dev libvorbis-dev libopenal-dev curl ca-certificates git
cd /tmp
curl -fsSL -o haxe.tar.gz https://github.com/HaxeFoundation/haxe/releases/download/4.3.6/haxe-4.3.6-linux64.tar.gz
sudo mkdir -p /opt/haxe && sudo tar -xzf haxe.tar.gz -C /opt/haxe --strip-components=1
sudo ln -sf /opt/haxe/haxe /usr/local/bin/haxe
sudo ln -sf /opt/haxe/haxelib /usr/local/bin/haxelib
mkdir -p ~/haxelib && haxelib setup ~/haxelib
bash /workspaces/*/tools/install_libs.sh
