# bitcoind-image

Bitcoin Core container image, built from the official signed release tarball.

Published to `ghcr.io/rpenido/bitcoind`, tagged with the Core version (`31.1`)
and `latest`.

## How it is verified

The build is only as trustworthy as its inputs, so both are checked:

1. `SHA256SUMS.asc` must carry at least two valid signatures from the builder
   keys vendored in `keys/`. Those keys come from
   [bitcoin-core/guix.sigs](https://github.com/bitcoin-core/guix.sigs/tree/main/builder-keys),
   which is the same trust anchor the official `contrib/verify-binaries`
   tooling uses.
2. The `x86_64-linux-gnu` tarball's sha256 is pinned through the
   `BITCOIN_SHA256` build arg. CI resolves it from the same release's
   `SHA256SUMS`, so a compromised mirror would also have to forge the
   signatures.

## Automation

`.github/workflows/build.yaml` runs weekly, on push, or manually:

- resolves the newest release from the GitHub API and confirms its binaries
  exist on bitcoincore.org (the API can announce a release before the tarballs
  are published),
- builds and smoke tests the binary,
- pushes `:<version>` and `:latest` to GHCR with provenance and SBOM,
- bumps `VERSION` with a bot commit.

The homeserver runs `ghcr.io/rpenido/bitcoind:latest` and Komodo watches the
digest, so a new upstream release rolls out without manual work. The version
tags are kept for rollback.

## Deliberate choices

- `USER 1000:1000`, so PID 1 is not root. The node data directory is owned by
  uid 1000 on the host.
- `debian:trixie-slim` runtime: the official binaries only need glibc and
  `libatomic1`.
- `ENTRYPOINT ["bitcoind", "-datadir=/bitcoin/.bitcoin"]` keeps the same data
  path as the previous community image, so the 900 GB dataset is reused.
- No `latest`-only dependence: roll back by changing the tag in the compose
  file.

## Local build

```bash
./build.sh 31.1
docker run --rm --entrypoint bitcoind bitcoind:31.1 --version
```

## Updating the vendored keys

```bash
curl -s "https://api.github.com/repos/bitcoin-core/guix.sigs/contents/builder-keys?ref=main" \
  | jq -r '.[] | select(.name | endswith(".gpg")) | .download_url' \
  | xargs -n1 -P4 wget -q -P keys/
```
