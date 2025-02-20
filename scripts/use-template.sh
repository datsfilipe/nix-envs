#!/bin/sh

if [ "$#" -lt 1 ]; then
  echo "Please provide at least one template"
  exit 1
fi

if [ -f .envrc ]; then
  echo ".envrc already exists"
  exit 1
fi

nix flake new -t "github:datsfilipe/nix-envs#$1" ./

echo "
.envrc
.direnv
" >> .git/info/exclude
