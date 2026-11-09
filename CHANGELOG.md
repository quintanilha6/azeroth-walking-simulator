# Changelog

All notable changes to Azeroth Walking Simulator. Versions follow [Semantic Versioning](https://semver.org/).

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
