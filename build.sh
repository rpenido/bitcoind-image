#!/usr/bin/env bash
# Local build helper. CI does the same thing, see .github/workflows/build.yaml.
set -euo pipefail
cd "$(dirname "$0")"

ver="${1:-$(cat VERSION)}"
sums=$(mktemp)
trap 'rm -f "$sums"' EXIT

curl -fsSL "https://bitcoincore.org/bin/bitcoin-core-${ver}/SHA256SUMS" -o "$sums"
sha=$(grep " bitcoin-${ver}-x86_64-linux-gnu.tar.gz$" "$sums" | awk '{print $1}')
[ -n "$sha" ] || { echo "no sha256 for ${ver}" >&2; exit 1; }

docker build \
  --build-arg "BITCOIN_VERSION=${ver}" \
  --build-arg "BITCOIN_SHA256=${sha}" \
  -t "bitcoind:${ver}" \
  -t bitcoind:latest .

docker run --rm --entrypoint bitcoind "bitcoind:${ver}" --version | head -1
