#! /usr/bin/env bash
set -eux -o pipefail

function prefetch-url {
   local package=$1
   local name=$(nix eval "$package.name" --raw)
   local url=$(nix eval "$package.urls" --apply builtins.head --raw)
   nix-prefetch-url --type sha256 \
      --name "$name" "$url"
}

function prefetch-url-unpack {
   local package=$1
   local name=$(nix eval "$package.name" --raw)
   local url=$(nix eval "$package.urls" --apply builtins.head --raw)
   nix-prefetch-url \
      --unpack \
      --type sha256 \
      --name "$name" "$url"
}

function get-latest-commmit-id {
   local commit_id_sha_column='$1'

   local url=$1 # "https://evilpiepirate.org/git/bcachefs.git"
   local ref=$2

   git ls-remote $url $ref | awk "{ print $commit_id_sha_column }"
}

nix flake lock --recreate-lock-file

prefetch-url-unpack ".#kernel.src" > ./pins/bcachefs-kernel.sha256

get-latest-commmit-id "https://evilpiepirate.org/git/bcachefs.git" "HEAD" > ./pins/bcachefs-kernel.latest.rev

prefetch-url-unpack ".#kernel-latest.src" > ./pins/bcachefs-kernel.latest.sha256

prefetch-url ".#bcachefs-kernel-patch" > ./pins/bcachefs-kernel.patch.sha256
prefetch-url ".#bcachefs-kernel-latest-patch" > ./pins/bcachefs-kernel.patch.latest.sha256