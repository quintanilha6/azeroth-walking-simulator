# Publishing on CurseForge: checklist and paste-ready text

Based on CurseForge's "Creating and Submitting a Project" guide and its Moderation Policies.

## Rules that matter for this addon

- **Name:** must be unique. It must not contain the game name ("World of Warcraft"), version numbers or file versions. "Azeroth Walking Simulator" is fine.
- **Summary:** one sentence, not copied from the description.
- **Description:** correct English that clearly says what the addon does. Grammar mistakes or vague text get rejected.
- **Logo:** exactly **400×400**, not a plain color, nothing copyrighted (no Blizzard art), and not `.webp`. Use `media/logo.png`.
- **Files:** `.zip` only. Every file needs a **changelog**. You need at least one **Release** file (not Beta or Alpha) before the addon shows up in the CurseForge app.
- **No external download links** in the description. Donation and personal links are allowed only at the bottom.
- A place to report bugs (GitHub issues) is strongly recommended.
- If something is rejected, **do not delete and re-upload**. Fix it and reply to the moderator.

## Step by step

1. Log in at https://authors.curseforge.com and choose **Create Project** → **World of Warcraft**.
2. Fill in the form:
   - **Name:** Azeroth Walking Simulator
   - **Summary:** see below
   - **Main category:** Miscellaneous
   - **Additional categories** (up to 4, only related ones): Achievements, Chat & Communication, Data Export
   - **License:** MIT License
   - **Logo:** `media/logo.png`
3. **Description tab:** paste the description below.
4. **Source:** https://github.com/quintanilha6/azeroth-walking-simulator
   **Issues:** https://github.com/quintanilha6/azeroth-walking-simulator/issues
5. After creating the project, copy its **Project ID** from the right sidebar of the project page. Add this line to `AzerothWalkingSimulator.toc` so the GitHub Action can upload releases:
   ```
   ## X-Curse-Project-ID: 123456
   ```
6. Create an API token at https://legacy.curseforge.com/account/api-tokens. Save it in GitHub under **Settings → Secrets and variables → Actions** as `CF_API_KEY`.
7. Push a tag (`git tag v2.1.0`, then `git push origin --tags`). The action uploads the zip with the changelog, set as **Release**.
   - If the action can't match the game version for WoW Forever (Interface 16001), upload the first zip by hand from **Project → Files → Upload File**. Pick the WoW Forever / Classic game version shown there and choose **Release**.
8. Add the screenshots below in the **Images** tab. They're optional for addons but help a lot.

## Screenshots to take in game (please send them to me)

Press **Print Screen** in game. Screenshots are saved to `_forever_\Screenshots`.

1. **Mini tracker** while walking, showing the green "Recording" status.
2. **Overview tab** with some steps and the 7-day chart.
3. **Challenges tab** with progress bars.
4. **Trophies tab** showing your rank and achievements.
5. **Social → Leaderboard**, ideally with a friend or guildie on it.
6. **A challenge banner.** `/aws testbanner` shows one any time.
7. **The Quick Share menu** open.

Tip: hide the rest of the UI if you can (Alt+Z hides it, but that also hides addon frames, so crop instead).

---

## Summary (paste into "Summary")

Strava for Azeroth: count the steps you walk on foot, beat weekly challenges, earn ranks and race your friends on leaderboards.

## Description (paste into "Description")

**Azeroth Walking Simulator** turns every step your character takes on foot into progress. Walk through Azeroth to log activities, complete weekly and monthly challenges, climb walker ranks, unlock achievements and compete with your friends and guild.

### What it tracks
- **Steps you walk yourself.** Steps only count while you hold a movement key or both mouse buttons and your character really moves. Auto-run, running into walls, mounts, flight paths, vehicles, swimming, being dead and following another player never count.
- **Distance, moving time and pace** in kilometers or miles.
- **Activities:** start, pause and finish sessions yourself, or let auto mode record from login to logout.
- **All-time totals** for each character and for your whole account, a 7-day chart, daily streaks and personal records.

### Challenges and progression
- **Weekly challenges** in Bronze, Silver and Gold that reset every Monday. Complete all three to become **Weekly Champion**.
- **Monthly challenges**, including the 250,000-step Quarter Million.
- Everyone gets the **same challenges** each period, so you race your friends on equal terms.
- **Nine walker ranks**, from Novice Wanderer to Walking Simulator Champion.
- **24 achievements** for step milestones, streaks, marathon distances, exploring zones and more.
- **Banners** celebrate your wins in the middle of the screen.

### Social
- **Leaderboards** for Friends, Guild and Everyone, each by today, this week, this month or all time.
- An **activity feed** where you can give **Kudos** to your friends' walks.
- **Overtake alerts** when you pass a friend on the weekly leaderboard, or they pass you.
- A **weekly recap** of your steps, challenges and place among friends.
- **Quick Share** posts your walk to Say, Party, Raid or Guild chat in two clicks.

### Routes
- See the path you walked on a **route card with its own map**: zoom, drag, click into zones, or view the whole world.
- Routes are **colored by speed**: walking, running, fast on foot, and mounted travel.
- Hearthstones, portals and flight paths show as dashed lines.
- Open your **friends' routes** straight from the Feed, and save any route card as a **screenshot**.

### Languages
English, Português (Portugal), Español, Français, Deutsch, Italiano, Suomi and Svenska. The addon follows your game language automatically, and you can change it in Settings.

Only players who also use the addon can see your stats. You can turn sharing off at any time in Settings.

### Getting started
Install the addon and log in. A small tracker appears on screen. Type **/aws** to open the main window.

| Command | Action |
|---|---|
| /aws | Open the main window |
| /aws start, pause, resume, stop | Control a session |
| /aws challenges | View this week's challenges |
| /aws stats | Print your stats in chat |

### How steps are calculated
World of Warcraft has no step counter, so the addon measures how far you actually travel on foot and divides it by a step length: 1.4 yards when walking and 2.0 yards when running. These are the same for every player, so steps are fair on all leaderboards and challenges. Click-to-move and controller movement are not counted.

### Feedback
Found a bug or have an idea? Open an issue on GitHub: https://github.com/quintanilha6/azeroth-walking-simulator/issues
