#!/bin/sh

git clone https://github.com/UrusTeam/urusstudio_installer.git
cd urusstudio_installer
sudo -H source install_deps.sh
. install_linux.sh
