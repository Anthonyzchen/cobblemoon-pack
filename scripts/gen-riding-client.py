#!/usr/bin/env python3
"""Regenerate the client-side datapack azc-riding-client.zip from the master world datapack.

Clients don't receive the server's species data, so the `globalpacks` mod loads this datapack
locally to give them seat DATA (for rider rendering) AND the size overrides (baseScale/hitbox)
that the renderer reads from the client's own FormData. Anything omitted here falls back to the
Cobblemon jar defaults on the client, which is why an earlier riding-only build left Lugia
rendering at jar-default size despite the server saying baseScale 0.3.

Emits one flat species_addition per species carrying only {riding, baseScale, hitbox} (whichever
the source has), merged across both source dirs. See ~/.claude/plans/quiet-hatching-conway.md.
"""

import json
import pathlib
import zipfile

MASTER_DP = pathlib.Path(
    "/Users/anthonyzchen/cobblemoon-master/saves/Server World/datapacks/"
    "cobblemon_adastra_datapack/data/cobblemon"
)
OUT_ZIP = pathlib.Path(
    "/Users/anthonyzchen/cobblemoon-pack/datapacks/azc-riding-client.zip"
)

# Only these keys drive client-side rendering/seating. Everything else stays server-only.
KEEP_KEYS = ("riding", "baseScale", "hitbox")

PACK_MCMETA = {
    "pack": {
        "pack_format": 48,
        "description": "AZC Riding + size (client-side seat data & scale)",
    }
}


def species_key(target: str) -> str:
    """Bare species name used to dedupe across the two source dirs."""
    return target.split(":", 1)[-1]


def load(dir_name: str, synthesize_target: bool):
    """Yield (key, target, relevant-subset-dict) for every override file in a source dir.

    `species/` base overrides carry no `target` field — synthesize `cobblemon:<filename>`.
    `species_additions/` files carry an explicit `target`.
    """
    root = MASTER_DP / dir_name
    if not root.exists():
        return
    for f in sorted(root.rglob("*.json")):
        try:
            data = json.loads(f.read_text())
        except (json.JSONDecodeError, OSError) as e:
            # Surface, don't swallow — a malformed source file would silently drop a species.
            print(f"[gen-riding-client] SKIP unparseable {f}: {e}")
            continue
        subset = {k: data[k] for k in KEEP_KEYS if k in data}
        if not subset:
            continue
        if synthesize_target:
            target = f"cobblemon:{f.stem}"
        else:
            target = data.get("target")
            if not target:
                print(f"[gen-riding-client] SKIP addition without target: {f}")
                continue
        yield species_key(target), target, subset


def main():
    # Key -> {"target": str, ...kept keys}. Seed with base overrides, then let additions win
    # per-key (matches server apply order: base species loads, species_additions patches on top).
    merged: dict[str, dict] = {}

    for key, target, subset in load("species", synthesize_target=True):
        merged.setdefault(key, {"target": target}).update(subset)

    for key, target, subset in load("species_additions", synthesize_target=False):
        entry = merged.setdefault(key, {"target": target})
        entry["target"] = target  # additions carry the canonical target
        entry.update(subset)       # addition wins on key conflict

    # Verification asserts (fail loudly rather than ship a wrong pack).
    assert "lugia" in merged, "Lugia missing from merged set"
    lugia = merged["lugia"]
    assert lugia.get("baseScale") == 0.3, f"Lugia baseScale wrong: {lugia.get('baseScale')}"
    assert "hitbox" in lugia, "Lugia hitbox missing"
    air = lugia.get("riding", {}).get("behaviours", {}).get("AIR", {})
    assert air.get("stats", {}).get("SPEED") == "45-62", (
        f"Lugia AIR SPEED not synced to server: {air.get('stats', {}).get('SPEED')}"
    )

    OUT_ZIP.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUT_ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("pack.mcmeta", json.dumps(PACK_MCMETA, indent=2))
        for key in sorted(merged):
            entry = merged[key]
            path = f"data/cobblemon/species_additions/{key}.json"
            z.writestr(path, json.dumps(entry, indent=2))

    n = len(merged)
    n_scale = sum(1 for e in merged.values() if "baseScale" in e or "hitbox" in e)
    n_ride = sum(1 for e in merged.values() if "riding" in e)
    print(f"[gen-riding-client] wrote {OUT_ZIP}")
    print(f"[gen-riding-client] {n} species  ({n_ride} with riding, {n_scale} with scale/hitbox)")


if __name__ == "__main__":
    main()
