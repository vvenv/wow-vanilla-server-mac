# wow-vanilla-server-mac

*[中文](README.md) · English*

Stand up a complete local **World of Warcraft Vanilla 1.12.1** private server and a playable
client on macOS (Apple Silicon). Everything runs on your machine — nothing is hosted anywhere.

Packaged as a [Claude Code Skill](https://docs.claude.com/en/docs/claude-code/skills): drop it
into a project and say *"set up a local WoW private server"*. It also reads perfectly well as
a plain human runbook plus a toolbox of scripts.

## Why this exists

The setup itself is not hard. What is hard is that the information is scattered and a lot of
it is stale. This repo records what it actually cost to get it working end to end:

- **AzerothCore does not support Vanilla 1.12.** It is WotLK 3.3.5a only; there is no 1.12
  branch. This is the most common wrong turn, so `SKILL.md` forces a version-routing decision
  as step 0.
- **`StrictVersionCheck = 0` is mandatory for any non-original client.** The default `1`
  verifies the client binary's integrity hash, which a reimplementation cannot produce. It
  surfaces as `Login failed: Version mismatch` — but SRP6 password auth actually *passed*,
  which makes it very easy to misdiagnose as a bad account.
- **Editing `realmlist.wtf` is not enough.** `WTF/Config.wtf` caches a `SET realmList` line
  that takes precedence.
- **Whisky was discontinued in April 2025.** Plenty of guides still recommend it.
- **You can inspect a 5 GB client package before downloading it.**
  `scripts/peek-remote-zip.py` reads a remote ZIP's central directory over HTTP range
  requests, and can even pull `README`/`SHA256SUMS` out of it. Many "clients" turn out to be
  Windows installers (`setup-N.bin`) that macOS cannot extract at all.
- **`mmaps` extraction takes hours but has nothing to do with logging in.** Split it off, play
  first, backfill pathfinding later.

## Quick start

```sh
# As a Claude Code Skill
mkdir -p .claude/skills
git clone https://github.com/vvenv/wow-vanilla-server-mac .claude/skills/vanilla-wow-local

# Or enable it globally
git clone https://github.com/vvenv/wow-vanilla-server-mac ~/.claude/skills/vanilla-wow-local
```

Then tell Claude Code: **"set up a local Vanilla WoW private server"**.

To follow it by hand, read [`SKILL.md`](SKILL.md) and work through its seven steps.

> The prose in `SKILL.md` is English; the reference documents and script comments are Chinese.

## Contents

| File | What it covers |
|---|---|
| [`SKILL.md`](SKILL.md) | Main workflow: version routing → survey → download → server → data extraction → client → account → verification |
| [`references/client-sources.md`](references/client-sources.md) | Vetted client packages, how to verify one before downloading, disk budget |
| [`references/native-clients.md`](references/native-clients.md) | Client landscape, WoWSilicon install and wiring, realmlist and patching pitfalls |
| [`references/known-client-issues.md`](references/known-client-issues.md) | Wowee `classic` profile defects — which are locally fixable, the fixes, and how to remove them |

### Scripts

| Script | Purpose |
|---|---|
| `scripts/peek-remote-zip.py` | Read a remote ZIP's directory and extract small files without downloading the archive |
| `scripts/fetch-client.sh` | `aria2c -x16` multi-connection download (an order of magnitude faster than curl on a slow link) |
| `scripts/02a-extract-maps-vmaps.sh` | Extract maps/vmaps/dbc — minutes, and enough to log in and play |
| `scripts/02b-extract-mmaps.sh` | Extract mmaps pathfinding meshes — hours, run it in the background |
| `scripts/04-mmaps-then-restart.sh` | Wait for mmaps, **verify the output**, then restart mangosd |
| `scripts/mangos-console.py` | Drive the server console through a pty, working around `docker attach`'s TTY requirement |
| `scripts/auth-check.py` | Standalone SRP6 client that verifies the whole auth chain without a game client |
| `scripts/wowsilicon-setup.sh` | Wire up WoWSilicon: realmlist (both places) + patches + readiness check |
| `scripts/wowsilicon-launch.sh` | Launch the game directly, bypassing the launcher UI when Play silently no-ops |
| `scripts/make-incomplete-icon.py` | Rewrite BLP2/DXT3 colour endpoints to synthesise the grey quest icon Vanilla lacks |
| `scripts/gen-spellbook-filter.py` | Build the hidden-spell tables from Spell.dbc for the spellbook filter addon |
| `scripts/manifest-add.py` | Register added or modified assets in the client's `manifest.json` (CRC32) |

## Upstream projects

This repo is only the process and the tooling. Every actual component comes from:

- [VMaNGOS](https://github.com/vmangos/core) — Vanilla server core
- [vmangos-deploy](https://github.com/mserajnik/vmangos-deploy) — prebuilt amd64/arm64 images, no compiling
- [WoWSilicon](https://github.com/WoWSilicon/WoWSilicon) — runs the original client on Apple Silicon
- [Wowee](https://github.com/Kelsidavis/WoWee) — open-source native client written from scratch
- [AzerothCore](https://github.com/azerothcore/azerothcore-wotlk) — WotLK 3.3.5a server, referenced for version routing

## About game assets

This repository **contains and distributes no Blizzard game assets, binaries, or code**. Every
MPQ, DBC, and art file must come from a copy of the client you legitimately own; the docs only
explain how to verify and extract one.

## License

MIT
