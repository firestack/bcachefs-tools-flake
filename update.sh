#! /usr/bin/env bash
set -eux -o pipefail

function prefetch-url {
   local package=$1
   local filepath=$2
   local name=$(nix eval "$package.name" --raw)
   local url=$(nix eval "$package.urls" --apply builtins.head --raw)
   nix-prefetch-url --type sha256 \
      --name "$name" "$url" > $filepath
}

function get-latest-commmit-id {
   local commit_id_sha_column='$1'

   local url=$1 # "https://evilpiepirate.org/git/bcachefs.git"
   local ref=$2

   git ls-remote $url $ref | awk "{ print $commit_id_sha_column }"
}

nix flake lock --recreate-lock-file

get-latest-commmit-id "https://evilpiepirate.org/git/bcachefs.git" "HEAD" > ./pins/bcachefs-kernel.latest.rev

prefetch-url ".#bcachefs-patch" ./pins/bcachefs-kernel.patch.sha256
prefetch-url ".#bcachefs-patch-latest" ./pins/bcachefs-kernel.patch.latest.sha256