<p align="center"><img src="media/logo.png" width="160" alt="Azeroth Walking Simulator logo"></p>

# Azeroth Walking Simulator

**Strava for Azeroth.** A World of Warcraft addon that counts the steps your character walks on foot, then turns them into activities, weekly and monthly challenges, ranks, achievements and leaderboards you share with your friends and guild.

**[Download on CurseForge](https://www.curseforge.com/projects/1794070)** · Type `/aws` in game.

## Features

- **Step tracking on foot only.** Nothing counts while you're mounted, on a flight path, in a vehicle, swimming, dead, on auto-run or following someone.
- **Activities like Strava.** Start, pause and finish sessions, or let auto mode record from login to logout. Each activity saves steps, distance, moving time, pace and zones.
- **Weekly challenges** (Bronze, Silver, Gold) and **monthly challenges**, the same for everyone. Finish all three weekly ones to become **Weekly Champion**.
- **Walker ranks**, from Novice Wanderer to Walking Simulator Champion, plus **24 achievements**.
- **Banners** when you complete something, and toasts when your friends do.
- **Leaderboards** for Friends, Guild and Everyone, each by Today, Week, Month or All-time. Shows the top 50 plus your own place, with name search and an "Online now" filter.
- **Social feed** with Kudos, overtake alerts and a weekly recap.
- **Player profiles:** click anyone on the leaderboard to see their rank, stats, challenges and trophies.
- **Quick Share** your walk to Say, Party, Raid or Guild chat in two clicks.
- **Routes:** see the path you walked drawn over the zone map on a Strava-style route card, colored by speed (walking, running, fast, mounted), with auto-run as a cyan dashed line and teleports or flights as white dashed lines, and save it as a screenshot. Open your friends' routes from the feed on the Home tab. Recorded outdoors.
- **All-time totals** per character and per account, a 7-day chart, streaks and personal records.
- **Minimap button** and settings in the game's **Options → AddOns** panel.
- **6 languages:** English, Português (Portugal), Español, Français, Deutsch and Italiano. The addon always uses your game's language.

## Commands

| Command | What it does |
|---|---|
| `/aws` | Open or close the main window |
| `/aws start` / `pause` / `resume` / `stop` | Control the current session |
| `/aws auto on` / `off` | Auto mode: a session from login to logout |
| `/aws challenges` / `trophies` / `social` | Open a tab |
| `/aws stats` | Print your stats to chat |
| `/aws share` | Put your last activity in the chat box |
| `/aws route` | Show the route of your current or last walk |
| `/aws tracker` | Show or hide the mini tracker |
| `/aws minimap` | Show or hide the minimap button |
| `/aws options` | Open the settings in the game's Options panel |
| `/aws testbanner` | Preview the banners |

## How steps are counted

WoW has no step counter, so the addon measures how far you really move on foot and divides by a step length. Steps only count when **both** of these are true:

- You're holding a movement key yourself (forward, back, strafe or move-and-steer), both mouse buttons, or a controller's movement stick. Auto-run and click-to-move don't count. `/aws debug pad` shows what your controller reports.
- Your position is actually changing. Running into a wall or in place doesn't count.

In dungeons the game hides your position, so there the addon uses your movement speed instead. You still need to hold the keys, and counting pauses if you haven't moved the mouse, turned, strafed, jumped, cast or fought for 5 seconds. Nothing counts while you're AFK.

`/aws debug` prints what the counter sees once a second. `/aws debug net` prints what route sharing and kudos send and receive.

Step lengths are fixed and the same for every player, so steps are fair on every leaderboard and challenge:

- **Walking:** 1.4 yards per step
- **Running:** 2.0 yards per step

## Social and privacy

Players running the addon swap stats through hidden addon messages:

- **Friends and guild** get your stats, finished activities, challenges and achievements.
- **Everyone** (a hidden channel, `AWSWalkers`) only gets your stats for the global leaderboard.

You can turn sharing, or just the Everyone leaderboard, off in Settings.

## Installing

- **Recommended:** install from [CurseForge](https://www.curseforge.com/projects/1794070) with the CurseForge app, so you get updates automatically.
- **From source:** copy this folder to `World of Warcraft/_forever_/Interface/AddOns/AzerothWalkingSimulator`.

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
