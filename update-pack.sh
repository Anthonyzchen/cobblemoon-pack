#!/bin/bash
# Sync the Cobblemoon CurseForge instance into the packwiz pack and publish.
# Only changed/new jars are re-uploaded; config is mirrored; then git push.
set -eo pipefail
export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
INST="/Users/anthonyzchen/Documents/curseforge/minecraft/Instances/Cobblemoon"
PACK="$HOME/cobblemoon-pack"
BUCKET="gs://cobblemon-adastra-client-dl/pack"
BASEURL="https://storage.googleapis.com/cobblemon-adastra-client-dl/pack"
PROJ="cobblemon-adastra-server"
cd "$PACK"
rm -rf /tmp/pwup; mkdir -p /tmp/pwup
python3 - "$INST" "$PACK" "$BASEURL" <<'PY'
import sys,glob,os,re,hashlib,urllib.parse,shutil
INST,PACK,BASEURL=sys.argv[1:4]
def sha(f):
    import hashlib;return hashlib.sha256(open(f,'rb').read()).hexdigest()
def slug(s): return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')
# current pack metafiles by filename
have={}
for mf in glob.glob(PACK+"/mods/*.pw.toml"):
    t=open(mf).read()
    have[re.search(r'filename = "([^"]+)"',t).group(1)]=(mf,re.search(r'hash = "([^"]+)"',t).group(1))
local=set()
for j in glob.glob(INST+"/mods/*.jar"):
    fn0=os.path.basename(j)
    if fn0.startswith("Axiom"): continue
    fn=fn0.replace("[","").replace("]","")  # bracket-free for GCS
    local.add(fn); h=sha(j)
    if fn in have and have[fn][1]==h: continue   # unchanged
    shutil.copy(j,"/tmp/pwup/"+fn)
    open(f"{PACK}/mods/{slug(fn[:-4])}.pw.toml","w").write(
f'name = "{fn[:-4]}"\nfilename = "{fn}"\nside = "both"\n\n[download]\nurl = "{BASEURL}/mods/'+urllib.parse.quote(fn)+f'"\nhash-format = "sha256"\nhash = "{h}"\n')
    print("  changed:",fn)
# drop metafiles for removed mods
for fn,(mf,_) in have.items():
    if fn not in local: os.remove(mf); print("  removed:",fn)
PY
[ -n "$(ls /tmp/pwup 2>/dev/null)" ] && gcloud storage cp /tmp/pwup/*.jar "$BUCKET/mods/" --project="$PROJ" 2>&1 | tail -1
rsync -a --delete --exclude='*.bak*' --exclude='resourceful-config-web.json' "$INST/config/" "$PACK/config/"
cp "$INST/options.txt" "$PACK/options.txt" 2>/dev/null || true
packwiz refresh
git add -A
git -c user.email="anthonyzchen1@gmail.com" -c user.name="Anthonyzchen" commit -q -m "update pack $(date +%Y-%m-%d)" 2>/dev/null && git push -q origin main && echo "PUBLISHED — players auto-pull on next launch" || echo "no changes to publish"
