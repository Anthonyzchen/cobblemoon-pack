#!/bin/bash
# Re-derive + publish the Cobblemoon HIGH pack from the main pack. Run AFTER update-pack.sh.
# Identical to the main/Standard pack (all mods + shaders) EXCEPT Distant Horizons is cranked:
# render radius 96 (vs Standard 32) and vertical/horizontal quality HIGH (vs MEDIUM). Targets ~12GB RAM.
# Live manifest is GCS (manifest-high); no separate git repo — source is this script in cobblemoon-pack.
set -eo pipefail
export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
MAIN="$HOME/cobblemoon-pack"; HIGH="$HOME/cobblemoon-high-pack"
BUCKET="gs://cobblemon-adastra-client-dl/pack"; PROJ="project-e0ef444e-5805-4c70-917"; ACCT="mobilebore@gmail.com"
mkdir -p "$HIGH"
rsync -a --delete --exclude='.git' --exclude='update-pack.sh' --exclude='build-lite.sh' --exclude='build-high.sh' --exclude='README.md' "$MAIN/" "$HIGH/"
cd "$HIGH"
# crank Distant Horizons (overlay on the Standard 32/MEDIUM config inherited from main)
sed -i '' \
 -e 's/^\([[:space:]]*\)lodChunkRenderDistanceRadius = .*/\1lodChunkRenderDistanceRadius = 96/' \
 -e 's/^\([[:space:]]*\)verticalQuality = .*/\1verticalQuality = "HIGH"/' \
 -e 's/^\([[:space:]]*\)horizontalQuality = .*/\1horizontalQuality = "HIGH"/' \
 config/DistantHorizons.toml
sed -i '' 's/^name = "Cobblemoon"/name = "Cobblemoon High"/' pack.toml
packwiz refresh
echo "DH set to: $(grep -E 'lodChunkRenderDistanceRadius|verticalQuality|horizontalQuality' config/DistantHorizons.toml | tr -s ' \t' ' ' | paste -sd'|' -)"
gcloud storage rsync -r -x '(\.git/|\.DS_Store)' "$HIGH" "$BUCKET/manifest-high" --project="$PROJ" --account="$ACCT" 2>&1 | tail -1
gcloud storage objects update "$BUCKET/manifest-high/**" --cache-control="no-cache, max-age=0" --project="$PROJ" --account="$ACCT" >/dev/null 2>&1
echo "HIGH published -- $(ls mods/*.pw.toml | wc -l | tr -d ' ') mods, DH radius 96 / HIGH quality"
echo "  manifest: https://storage.googleapis.com/cobblemon-adastra-client-dl/pack/manifest-high/pack.toml"
