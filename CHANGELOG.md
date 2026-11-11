# Changelog

All notable changes to Azeroth Walking Simulator. Versions follow [Semantic Versioning](https://semver.org/).

## [2.2.0] - 2026-11-11

### Changed
- **New, fairer step counting.** Steps only count when both are true:
  - you're holding a movement key yourself (forward, back, strafe, move-and-steer) or both mouse buttons
  - your position is really changing
- Distance now comes from how far you actually move, not just your movement speed. In dungeons, where the game hides your position, speed is still used, but you must hold the keys.
- In dungeons, steps only count while you're actively playing. If you haven't moved the mouse, turned, strafed, jumped, cast a spell, fought or entered a new area for 5 seconds, counting pauses ("Not counting: Idle") until you do. Steering with the right mouse button (or both buttons) counts as activity.
- Nothing counts while your character is marked AFK.
- Click-to-move and controller movement no longer count.

### Added
- `/aws debug` prints what the step counter sees once a second, to help track down counting problems.

### Fixed
- Auto-run could still count steps in some cases: running into a wall, after loading screens, after steering with both mouse buttons, with other auto-run keybinds, or from macros. Auto-run never counts now, however it's started.
- Pushing into a wall or running in place no longer counts. The tracker shows "Not counting: Blocked".
- **Half Marathon**, **Marathon**, **Early Bird** and **Night Owl** now include the activity you're walking right now. They unlock during the walk instead of only after you press Finish, and their progress on the Trophies tab moves live.

## [2.1.6] - 2026-11-09

### Fixed
- Holding both mouse buttons to run during auto-run now starts counting steps straight away, just like pressing W. A key bound to "Move and Steer" works too.

## [2.1.5] - 2026-11-09

### Changed
- **Live leaderboards.** While you walk, friends and guildies get your stats every 5 seconds. The Everyone leaderboard updates every 30 seconds to stay within WoW's message limits.
- Between updates, friends' steps now **count up smoothly** on your leaderboard, based on how fast they're walking. Each new update corrects the number.
- The Social tab refreshes four times a second, so the numbers move fluidly.

### Added
- A pulsing green dot shows who is walking right now.
- Green ▲ and red ▼ arrows show when someone moves up or down the leaderboard.

## [2.1.4] - 2026-11-09

### Changed
- Leaderboards update much faster. Your stats now reach friends and guildies within about 15 seconds of walking, instead of up to a minute. Updates are still only sent when your stats actually change.

## [2.1.3] - 2026-11-09

### Fixed
- Removed the repeated "No player named ... is currently playing" chat message. The addon was sending hidden updates to friends on other realms using your realm name instead of theirs.
- Friends are now reached by the exact name on your friends list, and Battle.net friends are reached through Battle.net first, which works across realms.
- If a hidden update to a friend still fails, the error is hidden and the addon waits 10 minutes before trying that friend again.
- Friend and guild detection for the leaderboards is more reliable across realms.

## [2.1.2] - 2026-11-09

### Added
- **Walker ranks list** in the Trophies tab. It shows all nine ranks, the steps each one needs, which you've reached, where you are now and how many steps until the next rank.
- Hover your rank on the mini tracker or the Trophies rank card to see what ranks are, the full list and your progress.
- Leaderboard tooltips show each player's rank number and how far they are from the next rank.

## [2.1.1] - 2026-11-09

### Fixed
- Fixed a Lua error ("attempt to compare a secret number value") that could repeat many times a second when the game hides your movement speed from addons, for example in combat. Steps keep counting using normal run speed until the game shows the real speed again.
- Pressing W or S during auto-run now starts counting steps straight away. Before, counting only resumed after you stopped moving.

## [2.1.0] - 2026-11-09

### Added
- **Quick Share** button on the mini tracker, in the main window and on your own activities. Pick Say, Party, Raid or Guild from a small menu to post your current session, last activity or today's steps.
- Click an activity in the Activities tab to Quick Share it. Shift-click still puts it in the chat box so you can edit it first.

## [2.0.0] - 2026-11-09

### Changed
- Renamed from **Stride** to **Azeroth Walking Simulator**. Slash command is now `/aws` (also `/walksim`).
- Existing Stride data is imported automatically on first login.
- Wider main window with six tabs: Overview, Activities, Challenges, Trophies, Social, Settings.

### Added
- **Weekly challenges**: Bronze, Silver and Gold, resetting every Monday. Finish all three to become **Weekly Champion**.
- **Monthly challenges**: a fixed 250,000-step goal plus a rotating one.
- Everyone gets the same challenges each period, so friends race on identical goals.
- **Walker ranks**: nine titles from Novice Wanderer to Walking Simulator Champion.
- **24 achievements** covering steps, streaks, distance, exploration, time of day, challenges and social play.
- **Banners**: a big center banner for your own completions, small toasts for friends' news.
- **Leaderboards** for Friends, Guild and Everyone, each with Today, Week, Month and All-time.
- **Overtake alerts** when you pass a friend on the weekly leaderboard, or they pass you.
- **Weekly recap** on your first login of a new week.
- Friends' challenges, achievements and rank-ups appear in the Feed.
- Settings for banners, sounds and the Everyone leaderboard.

### Fixed
- Auto-run and `/follow` no longer count as steps. Only steps you walk yourself count.
- Your own character could appear twice on the leaderboard on realms with two-part character names.

## [1.1.0] - 2026-11-09

### Added
- Social features: friends and guildies with the addon see each other's stats.
- Activity feed with Kudos.
- Share an activity to chat.
- Separate step length for walking and running, for more realistic step counts.

## [1.0.0] - 2026-11-09

### Added
- First release as **Stride**.
- Counts steps on foot only, not mounted, on flight paths, in vehicles, swimming or dead.
- Manual sessions (Start / Pause / Finish) and auto mode (log in to log out).
- Activity history, all-time totals per character and per account, a daily chart, streaks and personal records.
- Movable mini tracker and main window.
