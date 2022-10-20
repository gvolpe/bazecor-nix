#!/usr/bin/env nix-shell
#!nix-shell -i bash -p nix wget prefetch-yarn-deps nix-prefetch-github

if [ "$#" -gt 1 ] || [[ "$1" == -* ]]; then
  echo "Regenerates packaging data for the Bazecor packages."
  echo "Usage: $0 [git release tag]"
  exit 1
fi

# Revision: development branch on Sep 2, 2022
version="3f56cde2414bb667f54a0fa0fa855b38608d7009"
#version="$1"

set -euo pipefail

#if [ -z "$version" ]; then
  #version="$(wget -O- "https://api.github.com/repos/vector-im/element-desktop/releases?per_page=1" | jq -r '.[0].tag_name')"
#fi

# strip leading "v"
version="${version#v}"

src="https://raw.githubusercontent.com/Dygmalab/Bazecor/development"
#src="https://raw.githubusercontent.com/Dygmalab/Bazecor/$version"
src_hash=$(nix-prefetch-github Dygmalab Bazecor --rev ${version} | jq -r .sha256)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

pushd $tmpdir
wget "$src/yarn.lock"
yarn_hash=$(prefetch-yarn-deps yarn.lock)
popd

cat > pin.json << EOF
{
  "version": "$version",
  "srcHash": "$src_hash",
  "yarnHash": "$yarn_hash",
}
EOF
