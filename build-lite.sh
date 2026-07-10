#!/bin/bash
# Re-derive + publish the Cobblemoon LITE pack from the main pack. Run after update-pack.sh.
set -eo pipefail
export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
MAIN="$HOME/cobblemoon-pack"; LITE="$HOME/cobblemoon-lite-pack"
BUCKET="gs://cobblemon-adastra-client-dl/pack"; PROJ="project-e0ef444e-5805-4c70-917"; ACCT="mobilebore@gmail.com"
mkdir -p "$LITE"
rsync -a --delete --exclude='.git' --exclude='update-pack.sh' --exclude='build-lite.sh' --exclude='README.md' "$MAIN/" "$LITE/"
cd "$LITE"
python3 - <<'PY'
import glob,os,re
pats=["distanthorizons","visuality","particular","wakes","fallingleaves","snowundertrees","cave_dust","cavedust","eating-animation","eatinganimation","punchy","cobblethemes","lambdynamiclights","lambdynlights"]
for mf in glob.glob(os.path.expanduser("~/cobblemoon-lite-pack/mods/*.pw.toml")):
    fn=re.search(r'filename = "([^"]+)"',open(mf).read()).group(1).lower()
    if any(fn.startswith(p) for p in pats): os.remove(mf)
PY
rm -f resourcepacks/*cobblesounds*.pw.toml
rm -f shaderpacks/*.pw.toml 2>/dev/null; rmdir shaderpacks 2>/dev/null || true
[ -f config/iris.properties ] && { grep -q '^enableShaders=' config/iris.properties && sed -i '' 's/^enableShaders=.*/enableShaders=false/' config/iris.properties || printf '\nenableShaders=false\n' >> config/iris.properties; }
sed -i '' -e 's/^graphicsMode:.*/graphicsMode:0/' -e 's/^renderDistance:.*/renderDistance:6/' -e 's/^simulationDistance:.*/simulationDistance:6/' -e 's/^entityDistanceScaling:.*/entityDistanceScaling:0.5/' -e 's/^mipmapLevels:.*/mipmapLevels:2/' -e 's/^biomeBlendRadius:.*/biomeBlendRadius:1/' options.txt
sed -i '' -e 's#,"file/CobbleSounds-Complete-v1.4.1.zip"##' -e 's#"file/CobbleSounds-Complete-v1.4.1.zip",##' options.txt
sed -i '' 's/^name = "Cobblemoon"/name = "Cobblemoon Lite"/' pack.toml
packwiz refresh
git add -A
git -c user.email="anthonyzchen1@gmail.com" -c user.name="Anthonyzchen" commit -q -m "update lite $(date +%Y-%m-%d)" 2>/dev/null && git push -q origin main || echo "lite: no git changes"
gcloud storage rsync -r -x '(\.git/|\.DS_Store)' "$LITE" "$BUCKET/manifest-lite" --project="$PROJ" --account="$ACCT" 2>&1 | tail -1
gcloud storage objects update "$BUCKET/manifest-lite/**" --cache-control="no-cache, max-age=0" --project="$PROJ" --account="$ACCT" >/dev/null 2>&1
echo "LITE published -- $(ls mods/*.pw.toml | wc -l | tr -d ' ') mods"
