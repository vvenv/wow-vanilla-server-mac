---
name: vanilla-wow-local
description: Set up a complete local World of Warcraft private server plus a native macOS/Linux client, from nothing to logged-in. Covers Vanilla 1.12.1 (VMaNGOS) and WotLK 3.3.5a (AzerothCore), sourcing a legitimate client data package, extracting server maps/vmaps/mmaps and client art assets, and verifying the auth chain end to end. Use when someone wants to run WoW locally, set up a WoW private server, use the Wowee native client, or asks about AzerothCore / VMaNGOS / mangos / realmlist / MPQ extraction.
---

# Local WoW private server + native client

Builds a working local realm and a client that connects to it. Everything runs on the
user's machine; no external hosting.

## Step 0 — Route the version first (this is a hard fork in the road)

**Ask before doing anything else.** The server core is determined by the client version,
and the two common requests are incompatible:

| Client version | Build | Server core | Notes |
|---|---|---|---|
| Vanilla 1.12.1 | 5875 | **VMaNGOS** | AzerothCore does **not** support the 1.12 protocol. There is no Vanilla branch. |
| WotLK 3.3.5a | 12340 | **AzerothCore** | The mainstream choice; most mature server *and* client support. |
| TBC 2.4.3 | 8606 | CMaNGOS-TBC | Less common. |

If the user names both "Vanilla" and "AzerothCore", surface the conflict and let them
choose. Do not silently pick one.

**Also decide which client**, not just which server — see `references/native-clients.md`.
Short version: there is no more mature open-source *reimplementation* than
[Wowee](https://github.com/Kelsidavis/WoWee), but the reliable path is running the **original
Blizzard binary** under [WoWSilicon](https://wowsilicon.github.io/) (free, GPLv3, bundles its
own Wine runtime — no CrossOver). The original binary is the reference implementation, so
none of a reimplementation's protocol/UI gaps exist there.

Wowee's tradeoff is real, not academic: it is genuinely native ARM64 + Vulkan (better frame
rate and battery), but its `classic` profile has confirmed defects — see
`references/known-client-issues.md`. Offer both and let the user pick.

## Step 1 — Survey the machine

```sh
uname -m && sw_vers                       # arm64 vs x86_64 decides which images work
docker info | grep -E "Server Version|Total Memory"
df -h ~                                   # need ~30 GB free
ls /Applications | grep -i wow            # is a client already installed?
```

For a Wowee install, read `<App>/Contents/Resources/Data/expansions/*/expansion.json`
to confirm the exact build numbers the client speaks, and
`strings <App>/Contents/MacOS/wowee_bin | grep -E "^WOWEE_[A-Z_]+$"` for its env knobs.

## Step 2 — Start the client-data download early, in the background

It is 5+ GB and everything else can proceed in parallel. **Use `aria2c -x16`, not `curl`** —
on a slow link this was the difference between 3 hours and 25 minutes.

See `references/client-sources.md` for vetted sources and **how to verify a package before
committing to the download**. Two traps worth knowing up front:

- Many archives are **Windows installers** (`setup-N.bin`, InstallShield), not extractable
  on macOS. Check with `lsar` on the partial file before waiting for a 5 GB download.
- You can read a remote ZIP's central directory with HTTP range requests and inspect its
  file list — and even pull small files like `README`/`SHA256SUMS` out — *before*
  downloading it. `scripts/peek-remote-zip.py` does this.

## Step 3 — Bring up the server while the client downloads

**Vanilla 1.12.1** — use [vmangos-deploy](https://github.com/mserajnik/vmangos-deploy)
(prebuilt `amd64` **and** `arm64` images, so no compiling):

```sh
git clone https://github.com/mserajnik/vmangos-deploy.git
cd vmangos-deploy
cp ./config/mangosd.conf.example ./config/mangosd.conf
cp ./config/realmd.conf.example ./config/realmd.conf
cp ./compose.yaml.example ./compose.yaml
```

Then edit `compose.yaml`: set `TZ` on every service. Defaults for image tag (`:5875`) and
realmlist (`127.0.0.1:8085`) are already right for local play. Leave everything else alone —
the README is explicit that undocumented changes are unsupported.

**⚠️ Required for any non-original client** (Wowee, HermesProxy, any reimplementation) —
in `config/realmd.conf`:

```
StrictVersionCheck = 0
```

Default is `1`, which verifies the client binary's integrity hash against `allowed_clients`.
A reimplemented client cannot produce it. Symptom: realmd logs
`tried to login with modified client!` and the client shows
`Login failed: Version mismatch`. SRP6 password auth is unaffected — only the version proof
fails, which makes this easy to misdiagnose.

Start the database first so it initialises in parallel:

```sh
docker compose up -d database   # wait for healthy — do NOT interrupt DB creation
docker compose up -d realmd
```

**WotLK 3.3.5a** — use [AzerothCore Docker](https://www.azerothcore.org/wiki/install-with-docker)
(`docker compose up -d --build`; `ac-client-data-init` fetches server data automatically).

## Step 4 — Extract server data, but split the slow part off

Put the client where the server extractor can see it (`storage/mangosd/client-data/`, with
`Data/` inside). Point the client's own asset extractor at that **same** directory — one copy
of the MPQs serves both, saving ~5 GB.

The stock `extract-client-data` wrapper runs four steps in sequence and the last one
(`mmap_extract.py`) takes **hours**. Split it:

1. `scripts/02a-extract-maps-vmaps.sh` — maps + vmaps + dbc. **Minutes.** Enough to log in and play.
2. `scripts/02b-extract-mmaps.sh` — mmaps (NPC pathfinding). **Hours.** Run last, in the background.

Notes:
- The extractors are interactive; with stdin at EOF they take defaults, which are correct.
- `02a` deliberately keeps `Buildings/` — `02b` needs it.
- `scripts/04-mmaps-then-restart.sh` waits for `02b`, **verifies output before acting**, then
  restarts `mangosd`. Never restart on an unverified extraction.
- `mmap_extract.py` parallelises **across maps** with `--threads 1` each. Early on it saturates
  every core; at the end only maps 0 and 1 remain, so raising the CPU cap does nothing.
  Cap it while the user plays: `docker update --cpus=6 <container>`.

## Step 5 — Extract client art assets

For Wowee, ~80k files / ~6.5 GB, and it is fast (well under a minute):

```sh
"<App>/Contents/MacOS/asset_extract" --mpq-dir <client>/Data \
  --output "$HOME/Library/Application Support/Wowee/Data" \
  --expansion classic --expansion-subdir --locale enUS
```

Do **not** use the bundled `extract_assets.sh` — it writes into the code-signed `.app`.
Run the binary directly with `--output` elsewhere, then copy in the bundle's
`Data/expansions/<id>/*.json` metadata (`dbc_layouts`, `opcodes`, `update_fields`).
Point the client at it with `WOW_DATA_PATH`.

**Adding or changing any file under that tree requires registering it in `manifest.json`**
(key = MPQ-style backslash path, `h` = CRC32). `scripts/manifest-add.py` handles this.

## Step 5.5 — Install and wire up the client

Full detail in `references/native-clients.md`. The two failure modes that cost the most time:

- **Editing `realmlist.wtf` is not enough.** `WTF/Config.wtf` caches a `SET realmList` line
  that **takes precedence**. Third-party client packages ship both pointing at their own
  server. Change both.
- **WoWSilicon's Play button silently no-ops until patching is done** — and the app writes
  no log, produces no stdout even when launched from a terminal, and shows no error. A
  correctly patched game directory has `mods/winerosetta.dll`, `mods/libDllLdr.dll`, a root
  `d3d9.dll`, and `mods/winerosetta.dll` listed in `dlls.txt`.

```sh
scripts/wowsilicon-setup.sh <game-dir> 127.0.0.1   # realmlist + patches + readiness check
scripts/wowsilicon-launch.sh <game-dir>            # bypass the UI entirely if Play still fails
```

`game_path` may be a **symlink** — Wine handles it fine — so the client and the server's
`storage/mangosd/client-data` can share one copy of the MPQs.

## Step 6 — Create an account

`docker attach` fails with `cannot attach stdin to a TTY-enabled container because stdin is
not a terminal`. Use `scripts/mangos-console.py`, which allocates a pty and detaches cleanly
with Ctrl-P Ctrl-Q:

```sh
scripts/mangos-console.py "account create <name> <password>" "account set gmlevel <name> 6"
```

## Step 7 — Verify before handing off

Do not stop at "the containers are healthy". `scripts/auth-check.py` is a standalone SRP6
client that proves the whole chain — password, client build acceptance, realm list:

```sh
scripts/auth-check.py <account> <password>
```

Then confirm server-side that the character actually exists:

```sh
docker exec <db-container> mariadb -umangos -pmangos characters \
  -e "SELECT guid,name,level,online FROM characters;"
```

## Troubleshooting and known client gaps

- `references/native-clients.md` — client landscape, WoWSilicon install/wiring, and the
  realmlist + patching gotchas. **Whisky was discontinued in April 2025** — many guides are stale.
- `references/known-client-issues.md` — Wowee `classic` profile defects, which are fixable
  locally and which are not, plus the local fixes and how to remove them.
- `references/client-sources.md` — vetted client packages and how to verify one.

## Diagnostic method that paid off

When something looks broken, prove where it is before changing anything.

- **Check the data before blaming it.** Compare `manifest.json` entry counts against files on
  disk; parse the DBC header (`WDBC`, record/field counts) and compare field offsets against
  the client's own `dbc_layouts.json`. In this build every "missing asset" turned out to be
  present and correct.
- **Beware truncated evidence.** `ls -l ... | head -20` sorts alphabetically and cut off
  `spell.dbc`, which briefly looked like a missing file. Grep the full list.
- **Decompose garbage values.** A bogus field read as `1677787136` = `0x64010000` decomposed
  into `[spellId high bytes][state=1][cost low byte=0x64]`, which located a packet parser's
  read offset to the byte. That turns "it's broken" into a filable bug report.
- **Read the server's source to settle who is wrong.** VMaNGOS's `SendTrainerSpellHelper`
  writes 38 bytes/entry in canonical MaNGOS order — which proved the server correct and the
  client's parser wrong.
