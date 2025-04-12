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

for arg in "$@"; do
  if echo "$arg" | grep -q "#"; then
    template=$(echo "$arg" | cut -d '#' -f 1)
    output=$(echo "$arg" | cut -d '#' -f 2)
    
    content="${content}use flake \"github:datsfilipe/nix-envs?dir=$template#$output\"\n"
  else
    content="${content}use flake \"github:datsfilipe/nix-envs?dir=$arg\"\n"
  fi
done

for arg in "$@"; do
  template=$(echo "$arg" | cut -d '#' -f 1)
  env_url="https://raw.githubusercontent.com/datsfilipe/nix-envs/refs/heads/main/$template/.envrc"
  
  if curl --output /dev/null --silent --head --fail "$env_url"; then
    env="$(curl -s "$env_url")"
    processed_env=$(echo "$env" | tail -n +2)
    content="${content}${processed_env}\n"
  fi
done

content=$(echo -e "$content" | sed '/^$/d')
echo -e "$content" > .envrc

direnv allow

echo "
.envrc
.direnv
" >> .git/info/exclude

echo "direnv is now configured with: $*"
