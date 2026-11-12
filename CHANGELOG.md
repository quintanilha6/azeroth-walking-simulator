# Changelog

All notable changes to Azeroth Walking Simulator. Versions follow [Semantic Versioning](https://semver.org/).

## [2.7.0] - 2026-11-12

### Added
- **16 new trophies (40 in total):**
  - **Iron Legs:** 50,000 steps in one day
  - **Ultramarathon:** 50 km in one activity
  - **Endurance:** 2 hours of moving time in one activity
  - **Busy Week:** 7 activities (1,000+ steps each) in one week
  - **Weekend Warrior:** 10,000+ steps on both Saturday and Sunday
  - **Champion Streak:** Weekly Champion 4 weeks in a row
  - **Gold Rush:** 10 Gold weekly challenges
  - **Month Champion:** both monthly challenges in the same month
  - **Dungeon Crawler:** walk in 5 different dungeons
  - **Capital Tour:** walk in all three capitals of your faction
  - **Two Worlds:** walk on Kalimdor and the Eastern Kingdoms
  - **Fan Club:** 5 kudos on one activity
  - **Super Fan:** give 50 kudos
  - **Walking Buddies:** a 2,000+ step activity while in a party
  - **Leveling on Foot:** gain a level during an activity
  - **Night Walker:** 5,000 steps between midnight and 6 am in one night
- New trophies you already qualify for are awarded on your first login, with one toast instead of a banner each. Everything you'd already earned stays.
- Friends' profiles show all 40 trophies. Friends still on 2.6.x show the first 24.

## [2.6.1] - 2026-11-12

### Changed
- **Tracker buttons in two columns** (Pause / Finish, Share / Route, Social / Stats), with a new **Social** button that opens the leaderboard.
- **Narrower tracker:** 240 wide instead of 312.

## [2.6.0] - 2026-11-12

### Added
- **Clickable banners.** Click a banner to open what you just unlocked: the achievement, rank or challenge flashes so you can see it. Right-click just closes it. Toasts work too: friend news opens that friend's profile, overtakes the leaderboard, kudos your activities.
- **See your friends' trophies.** Click anyone on the leaderboard (or a friend's row in the feed, or "View trophies" in the right-click menu) to open their profile: rank and progress, today / week / month / all-time, streak, this week's challenges and all their achievements. Friends need 2.6.0 for the achievement list; on older versions you see their count.

### Changed
- **A cleaner window.** The tabs are now Home, Activities, Challenges, Trophies and Leaderboard, and the selected tab is the bright one. Settings moved to the ⚙ icon next to the close button.
- **New Home tab** (replaces Overview):
  - today's steps in big, with this week and your streak next to them
  - the walk in progress on one line, with a Share button
  - a bigger 7-day chart
  - your weekly challenges at a glance (click to open Challenges)
  - the feed from you and your friends
- **Activities are cards** with a title like "Afternoon walk in The Barrens", the stats and your kudos. Click one to open its route. Right-click for Quick Share, edit in chat box or Delete; the red ✕ buttons are gone.
- **Leaderboard:** Friends, Guild and Everyone are tabs, and the period (Today, Week, Month, All-time) is one dropdown. Your own row has a gold edge. The feed moved to Home.
- **Challenges:** the Weekly Champion line is now a banner above the weekly challenges.
- **Trophies:** a bigger rank bar; hover the rank card to see all ranks. Your all-time totals moved here, and the account totals only show when you have more than one character.
- **Smaller tracker:** the buttons sit under it. While you're walking they only show when your mouse is over the tracker; with no session or a paused one they're always there.

## [2.5.1] - 2026-11-12

### Added
- **Controller support.** Walking with a controller's movement stick (WoW's built-in gamepad mode, including ConsolePort) now counts steps, just like holding W. Before, it was treated as auto-run.
  - Auto-run started from a controller button still doesn't count, and neither does the camera stick on its own.
  - In dungeons, moving the camera stick or turning the movement stick counts as active play, like moving the mouse.
  - Controllers mapped to keyboard keys (Steam Input, DS4Windows...) already worked and still do.
- `/aws debug pad` prints what your controller reports once a second, to help if controller steps don't count.

## [2.5.0] - 2026-11-11

### Added
- **Leaderboards made for lots of players:** the board shows the top 50. If you're further down, a "..." row follows, then your own row with your real place (for example #342) and the two players above and below you.
- **Name search** on the leaderboard: type part of a name to find anyone on the board, even outside the top 50, with their real place.
- **"Online now" filter:** show only players who are online right now. Everyone keeps their real place on the full board.

## [2.4.4] - 2026-11-11

### Fixed
- **Boats and zeppelins no longer count as steps.** Holding W against the railing during the ride used to count the trip as walking. Now when something carries you faster than you can run, it doesn't count, and the tracker shows "Not counting: On a boat or zeppelin".
- **In dungeons, holding both mouse buttons into a wall no longer counts forever.** Steering counts as activity for up to 30 seconds in a row; after that you need to turn, jump, strafe, cast or fight to keep counting.
- **Protection against spam from modified addons:**
  - A friend or guildie can post at most 8 news items a minute (activities, challenges, achievements, rank-ups).
  - News with fake periods or ranks is ignored.
  - Text from other players is cleaned, so it can't show fake links or images in your Feed.
- Friends' challenge completions are now cleaned up after two months instead of being saved forever.
- **The Everyone leaderboard can't be shut down by locking its channel.** If someone sets a password on the hidden channel or bans you from it, the addon switches to a backup channel. It also rejoins if you get kicked.
- **Overtake alerts no longer repeat** when you and a friend walk side by side. You need a clear lead (100+ steps), and each friend triggers at most one alert every 15 minutes.
- **Leaderboards also check how fast someone's steps grow.** All-time steps can't grow faster than anyone can walk, so edited saved data is kept off the leaderboards until enough time has passed.
- A short freeze of the game while you walk is no longer mistaken for a boat ride.
- Deleting an activity always removes the one you clicked, even if a walk finishes while the confirmation is open.
- Quick Share no longer breaks accented letters when it has to shorten a long message.

### Added
- **Auto-run on routes:** auto-run and /follow are now drawn along the path you really took, as a cyan dashed line. They still never count as steps.
- Teleports, hearthstones, flight paths and boats stay white dashed lines. Both now have their own entry in the route card's legend: "Auto-run / follow" and "Teleport, flight, boat".

### Changed
- **The leaderboard's right-click menu shows one party option:** "Ask to join their party" if the player is already in a group, otherwise "Invite to party". Nothing is shown if they're in your group already. Their group status comes from their addon, so players on older versions always show "Invite to party".
- On the Everyone channel, only about 1 in 5 players answer when someone logs in. Everyone's stats still reach newcomers within a few minutes, and the addon stays fast as more people install it.
- The Social tab no longer recalculates your own totals 4 times a second.
- Stats from strangers on the Everyone channel no longer make the addon add up your own week each time.

## [2.4.3] - 2026-11-11

### Added
- **Right-click a player on the leaderboard** to whisper them, invite them to your party, ask to join their party, or add them as a friend. The options are greyed out while they're offline.

## [2.4.2] - 2026-11-11

### Fixed
- **Shared routes and kudos now reach guildies and friends reliably.** They were sent as hidden whispers to a name the addon built itself, which fails for some names and realms, so the route never arrived. They now go through the guild channel for guildies, and Battle.net or your friends list for friends, the same way stats do. Both players need this version.
- **Leaderboards ignore impossible numbers**, such as more steps in a day than anyone can walk, so nobody can fake their way to the top.
- A player can no longer pretend to be someone else, or give the same walk kudos many times from made-up characters.
- A friend's "Today" steps no longer show up on the wrong day around midnight or across time zones.
- A walk that goes past midnight on Sunday now counts for the new week's challenges, like its steps do.
- Explored zones are now saved by map, not by name, so changing the game's language no longer counts them twice. Your existing zones are converted automatically.

### Changed
- Less work in the background: your stats, challenges and achievements are only recalculated when something changed.

### Added
- `/aws debug net` prints what route sharing and kudos send and receive, to help track down problems.

## [2.4.1] - 2026-11-11

### Fixed
- **Shared routes:** when a friend doesn't answer, the card now says they may need to update the addon, instead of wrongly saying they're offline. Both players need this version or newer to share routes.
- Opening the same friend's route twice no longer cancels the second try.
- Route replies are sent before other addon messages, and the card keeps waiting as long as pieces are still arriving, so long routes no longer give up halfway.
- Very stop-and-go walks can now be shared too. Before, the friend saw "no route".
- Asking for the same route over and over no longer floods the owner's messages.
- Mount rides are drawn in mount colors even when the game hides your speed.

## [2.4.0] - 2026-11-11

### Added
- **Share routes with friends.** Click the map icon on a friend's activity in the Feed and their route loads onto your route card, with their name and stats. The route is only sent when you ask for it, and only to you. If your friend is offline, the card tells you.
- **Speed colors on routes:** yellow walking, orange running, red fast on foot (travel form, ghost wolf, Sprint), blue mount 60%, purple mount 100%, with a legend on the card. Mount rides are now drawn on the route too. They still never count as steps.
- **Minimap button:** click to open, right-click for the route card, Shift-click for options, drag to move. It can be hidden in Settings.
- **Settings in the game's Options → AddOns panel**, and `/aws options` to open them.
- **Translations:** Português (Portugal), Español, Français, Deutsch and Italiano.
  - The addon always uses the same language as your game. Portuguese game clients get European Portuguese.
  - Other game languages show English.

### Changed
- Routes recorded before this version show in plain orange, without speed colors.

## [2.3.0] - 2026-11-11

### Added
- **Routes.** Your walking path is recorded outdoors and saved with each activity, like Strava.
- The route card **opens on the zone you're in**, centered on you, with a yellow marker for where you're standing. The **target icon** brings you back there; **Fit route** zooms to your whole walk.
- **Route card with its own map**, working like the game map: scroll to zoom, drag to move, click a zone to zoom into it, right-click to zoom out (zone → continent → world). Buttons for −, +, "Fit route", "Up" and "World".
- The card's map shows the areas you've explored, just like your game map. Unexplored areas stay blank, as they do there.
- Your route is an orange line with a green start and white finish, and **every part of the walk is drawn on whatever map you look at**. Use "World" to see walks on several continents at once.
- **Jumps** (hearthstone, portals, zeppelins, boats, flight paths, mount rides) are shown as **dashed lines** between where you stopped walking and where you started again.
- Distance, steps, moving time and pace on the card. Open it with the new **Route** button on the mini tracker, the map icon on an activity in the Activities tab, or `/aws route` for your current or last walk.
- The regular world map is left untouched, so the addon works alongside any map addon.
- **Screenshot** button on the route card saves a clean picture to your Screenshots folder.
- Routes are simplified when an activity is finished, and kept for the newest 30 activities, so saved data stays small. Very long walks are simplified along the way instead of stopping the recording.
- While the card shows the walk you're on, its stats update every second and the route redraws as it grows.

### Notes
- Routes aren't recorded in dungeons, because the game hides your position there.
- Activities from before this version don't have routes.

## [2.2.1] - 2026-11-11

### Changed
- **Step length is now fixed for everyone**: 1.4 yards per step walking and 2.0 yards running. The step-length settings have been removed, because a shorter step length gave more steps for the same walk on leaderboards, challenges, ranks and achievements. Anyone who had changed it is back to the standard values. Steps counted before this update are not changed.

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
