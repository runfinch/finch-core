#!/bin/bash

set -eux

git clone https://github.com/systemd/mkosi
pushd mkosi
git checkout 4bdb47b6dafec4f258a2dca446d67ee662dbedd4
git apply ./../deps/mkosi/0001-add-support-for-al2023.patch
popd
mkdir -p "$HOME/.local/bin"
ln -s $PWD/mkosi/bin/mkosi ~/.local/bin/mkosi
# echo "export PATH=$HOME/.local/bin:$PATH" >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"

mkosi --version
