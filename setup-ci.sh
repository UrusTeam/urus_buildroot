#!/bin/sh

git clone https://github.com/UrusTeam/urusstudio_installer.git
cd urusstudio_installer
git checkout master-linux32
sudo -H ./install_deps.sh
./install_linux.sh
cd ..
