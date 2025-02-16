#!/bin/sh

if [ "$#" -lt 1 ]; then
  echo "Please provide at least one template"
  exit 1
fi

if [ -f .envrc ]; then
  content=$(cat .envrc)$'\n'
else
  content=""
fi

for template in "$@"; do
  content="${content}use flake \"github:datsfilipe/nix-envs?dir=$template\"\n"
done

for template in "$@"; do
  env="$(curl -s https://raw.githubusercontent.com/datsfilipe/nix-envs/refs/heads/main/$template/.envrc)"
  content="${content}$(echo "$env" | tail -n +2)\n"
done

content=$(echo -e "$content" | sed '/^$/d')
echo -e "$content" > .envrc

direnv allow

echo "
.envrc
.direnv
" >> .git/info/exclude

echo "direnv is now configured with envs: $*"
