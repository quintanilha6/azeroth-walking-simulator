<p align="center"><img src="media/logo.png" width="160" alt="Azeroth Walking Simulator logo"></p>

# Azeroth Walking Simulator

**Strava for Azeroth.** A World of Warcraft addon that counts the steps your character walks on foot, then turns them into activities, weekly and monthly challenges, ranks, achievements and leaderboards you share with your friends and guild.

Type `/aws` in game.

## Features

- **Step tracking on foot only.** Nothing counts while you're mounted, on a flight path, in a vehicle, swimming, dead, on auto-run or following someone.
- **Activities like Strava.** Start, pause and finish sessions, or let auto mode record from login to logout. Each activity saves steps, distance, moving time, pace and zones.
- **Weekly challenges** (Bronze, Silver, Gold) and **monthly challenges**, the same for everyone. Finish all three weekly ones to become **Weekly Champion**.
- **Walker ranks**, from Novice Wanderer to Walking Simulator Champion, plus **24 achievements**.
- **Banners** when you complete something, and toasts when your friends do.
- **Leaderboards** for Friends, Guild and Everyone, each by Today, Week, Month or All-time.
- **Social feed** with Kudos, overtake alerts and a weekly recap.
- **Quick Share** your walk to Say, Party, Raid or Guild chat in two clicks.
- **All-time totals** per character and per account, a 7-day chart, streaks and personal records.

## Commands

| Command | What it does |
|---|---|
| `/aws` | Open or close the main window |
| `/aws start` / `pause` / `resume` / `stop` | Control the current session |
| `/aws auto on` / `off` | Auto mode: a session from login to logout |
| `/aws challenges` / `trophies` / `social` | Open a tab |
| `/aws stats` | Print your stats to chat |
| `/aws share` | Put your last activity in the chat box |
| `/aws tracker` | Show or hide the mini tracker |
| `/aws testbanner` | Preview the banners |

## How steps are counted

WoW has no step counter, so the addon measures how far you move on foot (speed × time) and divides by a step length:

- **Walking:** 1.4 yards per step by default
- **Running:** 2.0 yards per step by default

Both can be changed in **Settings**.

## Social and privacy

Players running the addon swap stats through hidden addon messages:

- **Friends and guild** get your stats, finished activities, challenges and achievements.
- **Everyone** (a hidden channel, `AWSWalkers`) only gets your stats for the global leaderboard.

You can turn sharing, or just the Everyone leaderboard, off in Settings.

## Installing from source

Copy this folder to `World of Warcraft/_forever_/Interface/AddOns/AzerothWalkingSimulator`.

## Releasing (maintainers)

Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) GitHub Action (`.github/workflows/release.yml`):

1. Add your entry to `CHANGELOG.md`.
2. Commit, then tag and push:
   ```bash
   git tag v2.1.0
   ```
   ```bash
   git push origin main --tags
   ```
3. The action builds `AzerothWalkingSimulator-v2.1.0.zip` and uploads it to CurseForge and GitHub Releases.

To build a zip by hand instead, run `scripts/build-zip.ps1`.

## License

[MIT](LICENSE) © 2026 Quinta
