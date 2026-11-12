local _, ns = ...
local L = ns.L
local F = ns.F

local A = {}
ns.Achievements = A

local M_TO_YD = 1 / 0.9144

---------------------------------------------------------------------------
-- Walker ranks (by all-time steps on this character)
---------------------------------------------------------------------------
A.RANKS = {
  { 0, "Novice Wanderer" },
  { 25000, "Footpad" },
  { 100000, "Trail Runner" },
  { 250000, "Pathfinder" },
  { 500000, "Trailblazer" },
  { 1000000, "Marathoner" },
  { 2500000, "Globetrotter" },
  { 5000000, "Legend of Azeroth" },
  { 10000000, "Walking Simulator Champion" },
}
-- gray/white -> green -> blue -> purple -> orange, like item quality
local RANK_COLORS = { "ffffffff", "ffffffff", "ff1eff00", "ff1eff00", "ff0070dd", "ff0070dd",
                      "ffa335ee", "ffa335ee", "ffff8000" }

function A.RankIndex(steps)
  local idx = 1
  for i, r in ipairs(A.RANKS) do
    if (steps or 0) >= r[1] then idx = i end
  end
  return idx
end

function A.RankName(i) return L[(A.RANKS[i] or A.RANKS[1])[2]] end

function A.RankColored(i)
  i = math.max(1, math.min(#A.RANKS, i or 1))
  return ("|c%s%s|r"):format(RANK_COLORS[i], A.RankName(i))
end

function A.MyRank() return A.RankIndex(ns.cdb.total.steps) end

A.CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t"

-- "12,345 more steps to Footpad" (or nil at max rank)
function A.NextRankText(steps)
  local nextRank = A.RANKS[A.RankIndex(steps) + 1]
  if not nextRank then return nil end
  return (L["%s more steps to %s"]):format(F.Number(nextRank[1] - steps), L[nextRank[2]])
end

-- Tooltip explaining ranks, with the full list and your progress
function A.ShowRankTooltip(owner)
  local steps = ns.cdb.total.steps
  local idx = A.MyRank()
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L["Walker rank: "] .. A.RankColored(idx))
  GameTooltip:AddLine(L["Ranks are earned from the all-time steps you walk on this character."], 1, 1, 1, true)
  GameTooltip:AddLine(A.NextRankText(steps) or L["Max rank reached. Legendary walker!"], 0.99, 0.6, 0.3)
  GameTooltip:AddLine(" ")
  for i, r in ipairs(A.RANKS) do
    local mark = i <= idx and (A.CHECK .. " ") or "     "
    GameTooltip:AddDoubleLine(mark .. A.RankColored(i), F.Number(r[1]) .. L[" steps"], 1, 1, 1, 0.7, 0.7, 0.7)
  end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Achievements: check(c) returns current value and goal
---------------------------------------------------------------------------
local function BestDay(c)
  local best = 0
  for _, d in pairs(c.daily) do if d.s > best then best = d.s end end
  return best
end

-- Finished activities plus the one you're walking now, so activity
-- achievements unlock during the walk instead of only after "Finish"
local function Activities(c)
  if not c.current then return ipairs(c.history) end
  local list = { c.current }
  for _, s in ipairs(c.history) do list[#list + 1] = s end
  return ipairs(list)
end

local function BestDistance(c)
  local best = 0
  for _, s in Activities(c) do if s.distance > best then best = s.distance end end
  return best
end

local function ZoneCount(c)
  local n = 0
  for _ in pairs(c.zones) do n = n + 1 end
  return n
end

local function StartedBetween(c, from, to)
  for _, s in Activities(c) do
    local h = tonumber(date("%H", s.start))
    if h >= from and h < to and s.steps >= 1000 then return 1 end
  end
  return 0
end

local function Longest(c) local _, l = ns.Streaks(); return l end

---------------------------------------------------------------------------
-- Checks for the 2.7.0 trophies
---------------------------------------------------------------------------
local function DayTs(key) -- "YYYY-MM-DD" -> noon that day
  local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function BestOf(c, field)
  local best = 0
  for _, s in Activities(c) do if (s[field] or 0) > best then best = s[field] end end
  return best
end

local function BestNight(c)
  local best = 0
  for _, d in pairs(c.daily) do if (d.n or 0) > best then best = d.n end end
  return best
end

local function MostKudos(c)
  local best = 0
  for _, s in ipairs(c.history) do if s.kudos and #s.kudos > best then best = #s.kudos end end
  return best
end

-- Most activities of 1,000+ steps in one Monday-Sunday week
local function BusiestWeek(c)
  local perWeek, best = {}, 0
  for _, s in Activities(c) do
    if s.steps >= 1000 and s.start then
      local key = ns.Challenges.WeekPeriod(s.start).key
      perWeek[key] = (perWeek[key] or 0) + 1
      if perWeek[key] > best then best = perWeek[key] end
    end
  end
  return best
end

-- 10,000+ steps on a Saturday and on the Sunday right after it
local function WeekendWarrior(c)
  for key, d in pairs(c.daily) do
    local ts = d.s >= 10000 and DayTs(key)
    if ts and date("*t", ts).wday == 7 then
      local sunday = c.daily[date("%Y-%m-%d", ts + 86400)]
      if sunday and sunday.s >= 10000 then return 1 end
    end
  end
  return 0
end

-- Longest run of Weekly Champion weeks in a row
local function ChampionRun(c)
  local best = 0
  for key, t in pairs(c.completed) do
    local monday = t.champion and key:match("^W(.+)$")
    local ts = monday and DayTs(monday)
    if ts then
      local run = 1
      while true do
        ts = ts + 7 * 86400
        local nextWeek = c.completed["W" .. date("%Y-%m-%d", ts)]
        if not (nextWeek and nextWeek.champion) then break end
        run = run + 1
      end
      if run > best then best = run end
    end
  end
  return best
end

local function GoldCount(c)
  local n = 0
  for _, b in ipairs(c.badges) do
    local ch = b.kind == "weekly" and ns.Challenges.ById(b.id)
    if ch and ch.tier == "gold" then n = n + 1 end
  end
  return n
end

-- Both monthly challenges of one month
local function MonthDouble(c)
  for key, t in pairs(c.completed) do
    if key:match("^M") then
      local n = 0
      for id in pairs(t) do if id ~= "champion" then n = n + 1 end end
      if n >= 2 then return 1 end
    end
  end
  return 0
end

local function WithActivity(c, test)
  for _, s in Activities(c) do if test(s) then return 1 end end
  return 0
end

-- Zones are saved by map ID: look up which are dungeons and which continent
-- each is on. Cached until a new zone is walked in.
local CAPITALS = {
  Alliance = { 1453, 1455, 1457 }, -- Stormwind, Ironforge, Darnassus
  Horde = { 1454, 1456, 1458 },    -- Orgrimmar, Thunder Bluff, Undercity
}
local zoneInfo = { size = -1 }
local function ZoneInfo(c)
  local size = ZoneCount(c)
  if zoneInfo.size == size then return zoneInfo end
  local dungeons, continents, nCont = 0, {}, 0
  local ok = C_Map and C_Map.GetMapInfo and Enum and Enum.UIMapType
  for id in pairs(c.zones) do
    local info = ok and type(id) == "number" and C_Map.GetMapInfo(id)
    if info then
      if info.mapType == Enum.UIMapType.Dungeon then dungeons = dungeons + 1 end
      local p = info
      for _ = 1, 6 do
        if not p or p.mapType == Enum.UIMapType.Continent then break end
        p = p.parentMapID and p.parentMapID ~= 0 and C_Map.GetMapInfo(p.parentMapID)
      end
      if p and p.mapType == Enum.UIMapType.Continent and not continents[p.mapID] then
        continents[p.mapID] = true
        nCont = nCont + 1
      end
    end
  end
  zoneInfo = { size = size, dungeons = dungeons, continents = nCont }
  return zoneInfo
end

local function CapitalsVisited(c)
  local list = CAPITALS[UnitFactionGroup and UnitFactionGroup("player") or ""] or {}
  local n = 0
  for _, id in ipairs(list) do if c.zones[id] then n = n + 1 end end
  return n
end

local function Ach(id, name, desc, icon, check, fmt)
  return { id = id, name = name, desc = desc, icon = "Interface\\Icons\\" .. icon, check = check, fmt = fmt }
end

local function Steps(c) return c.total.steps end

A.LIST = {
  Ach("first", "First Steps", "Finish your first activity", "INV_Boots_05",
    function(c) return #c.history, 1 end),
  Ach("day10k", "10K Day", "Walk 10,000 steps in one day", "Ability_Rogue_Sprint",
    function(c) return BestDay(c), 10000 end),
  Ach("day25k", "Sole Survivor", "Walk 25,000 steps in one day", "Spell_Nature_Swiftness",
    function(c) return BestDay(c), 25000 end),
  Ach("all100k", "Hundred Thousand", "Walk 100,000 steps in total", "INV_Misc_Coin_05",
    function(c) return Steps(c), 100000 end),
  Ach("all500k", "Half a Million", "Walk 500,000 steps in total", "INV_Misc_Coin_03",
    function(c) return Steps(c), 500000 end),
  Ach("all1m", "Millionaire", "Walk 1,000,000 steps in total", "INV_Misc_Coin_01",
    function(c) return Steps(c), 1000000 end),
  Ach("all5m", "Five Million Footsteps", "Walk 5,000,000 steps in total", "INV_Misc_Head_Dragon_01",
    function(c) return Steps(c), 5000000 end),
  Ach("streak7", "Week Warrior", "Walk 7 days in a row", "Spell_Fire_Immolation",
    function(c) return Longest(c), 7 end),
  Ach("streak30", "Monthly Momentum", "Walk 30 days in a row", "Spell_Fire_SealOfFire",
    function(c) return Longest(c), 30 end),
  Ach("streak100", "Unstoppable", "Walk 100 days in a row", "Spell_Fire_SelfDestruct",
    function(c) return Longest(c), 100 end),
  Ach("half", "Half Marathon", "Cover 21.1 km in one activity", "Ability_Mount_JungleTiger",
    function(c) return BestDistance(c), 21097.5 * M_TO_YD end, "dist"),
  Ach("marathon", "Marathon", "Cover 42.2 km in one activity", "Ability_Hunter_RunningShot",
    function(c) return BestDistance(c), 42195 * M_TO_YD end, "dist"),
  Ach("zones10", "Explorer", "Walk in 10 different zones", "INV_Misc_Map_01",
    function(c) return ZoneCount(c), 10 end),
  Ach("zones25", "Seasoned Explorer", "Walk in 25 different zones", "INV_Misc_Spyglass_02",
    function(c) return ZoneCount(c), 25 end),
  Ach("zones50", "World Walker", "Walk in 50 different zones", "INV_Misc_Spyglass_03",
    function(c) return ZoneCount(c), 50 end),
  Ach("earlybird", "Early Bird", "Start an activity (1,000+ steps) between 5 and 8 am", "Spell_Holy_HolySmite",
    function(c) return StartedBetween(c, 5, 8), 1 end),
  Ach("nightowl", "Night Owl", "Start an activity (1,000+ steps) between midnight and 4 am", "Spell_Shadow_Twilight",
    function(c) return StartedBetween(c, 0, 4), 1 end),
  Ach("champion", "Weekly Champion", "Complete all 3 weekly challenges in one week", "Spell_Holy_ChampionsBond",
    function() local _, _, ch = ns.Challenges.Counts(); return ch, 1 end),
  Ach("weekly5", "Challenge Accepted", "Complete 5 weekly challenges", "INV_Misc_Note_01",
    function() local w = ns.Challenges.Counts(); return w, 5 end),
  Ach("weekly25", "Challenge Addict", "Complete 25 weekly challenges", "INV_Misc_Note_02",
    function() local w = ns.Challenges.Counts(); return w, 25 end),
  Ach("monthly1", "Month Master", "Complete a monthly challenge", "INV_Misc_PocketWatch_01",
    function() local _, m = ns.Challenges.Counts(); return m, 1 end),
  Ach("cheer", "Cheerleader", "Give 10 kudos to friends", "Spell_Holy_PrayerOfHealing02",
    function(c) return c.kudosGiven, 10 end),
  Ach("popular", "Crowd Favourite", "Receive 25 kudos", "Spell_Holy_GreaterHeal",
    function(c) return c.kudosReceived, 25 end),
  Ach("toppack", "Top of the Pack", "Lead the weekly leaderboard with 3+ friends on it", "Ability_Warrior_BattleShout",
    function() return ns.Social.IsWeekLeader() and 1 or 0, 1 end),

  -- 2.7.0 (append only: see the note below)
  Ach("day50k", "Iron Legs", "Walk 50,000 steps in one day", "Ability_Warrior_Charge",
    function(c) return BestDay(c), 50000 end),
  Ach("ultra", "Ultramarathon", "Cover 50 km in one activity", "Spell_Nature_SpiritWolf",
    function(c) return BestDistance(c), 50000 * M_TO_YD end, "dist"),
  Ach("endurance", "Endurance", "Move for 2 hours in one activity", "Spell_Holy_WordFortitude",
    function(c) return BestOf(c, "moving"), 7200 end, "time"),
  Ach("busyweek", "Busy Week", "Finish 7 activities (1,000+ steps each) in one week", "Spell_Nature_TimeStop",
    function(c) return BusiestWeek(c), 7 end),
  Ach("weekend", "Weekend Warrior", "Walk 10,000+ steps on both Saturday and Sunday of one weekend",
    "Ability_Warrior_WarCry", function(c) return WeekendWarrior(c), 1 end),
  Ach("champ4", "Champion Streak", "Be Weekly Champion 4 weeks in a row", "INV_Misc_Head_Dragon_Black",
    function(c) return ChampionRun(c), 4 end),
  Ach("gold10", "Gold Rush", "Complete 10 Gold weekly challenges", "INV_Misc_Coin_02",
    function(c) return GoldCount(c), 10 end),
  Ach("monthboth", "Month Champion", "Complete both monthly challenges in the same month", "Spell_Holy_SealOfWisdom",
    function(c) return MonthDouble(c), 1 end),
  Ach("dungeons5", "Dungeon Crawler", "Walk in 5 different dungeons", "INV_Misc_Key_03",
    function(c) return ZoneInfo(c).dungeons, 5 end),
  Ach("capitals", "Capital Tour", "Walk in all three capital cities of your faction", "INV_Misc_Spyglass_01",
    function(c) return CapitalsVisited(c), 3 end),
  Ach("twoworlds", "Two Worlds", "Walk on both Kalimdor and the Eastern Kingdoms", "Spell_Arcane_Blink",
    function(c) return ZoneInfo(c).continents, 2 end),
  Ach("fanclub", "Fan Club", "Get 5 kudos on one activity", "Spell_Holy_FlashHeal",
    function(c) return MostKudos(c), 5 end),
  Ach("cheer50", "Super Fan", "Give 50 kudos to friends", "Spell_Holy_PrayerOfHealing",
    function(c) return c.kudosGiven, 50 end),
  Ach("buddies", "Walking Buddies", "Finish an activity of 2,000+ steps while in a party", "Spell_Holy_PrayerOfFortitude",
    function(c)
      for _, s in ipairs(c.history) do if s.grouped and s.steps >= 2000 then return 1, 1 end end
      return 0, 1
    end),
  Ach("levelup", "Leveling on Foot", "Gain a character level during an activity", "Spell_Nature_EnchantArmor",
    function(c) return WithActivity(c, function(s) return s.levelUp end), 1 end),
  Ach("nightwalk", "Night Walker", "Walk 5,000 steps between midnight and 6 am in one night", "Spell_Nature_StarFall",
    function(c) return BestNight(c), 5000 end),
}

-- Leveling on Foot: remember a level gained while an activity is running
local levelWatch = CreateFrame("Frame")
levelWatch:RegisterEvent("PLAYER_LEVEL_UP")
levelWatch:SetScript("OnEvent", function()
  local s = ns.cdb and ns.cdb.current
  if s and not s.paused then
    s.levelUp = true
    A.Check()
  end
end)

-- NOTE: A.LIST is append-only. Its order is the bit order of A.Mask(), which
-- friends receive, so reordering or removing entries would show them the
-- wrong trophies.

local BY_ID = {}
for _, a in ipairs(A.LIST) do BY_ID[a.id] = a end
function A.ById(id) return BY_ID[id] end

-- Earned achievements as hex bitmasks for the stats message, 24 per part
-- (part 1 = A.LIST[1..24], field 29, read by 2.6.0+; part 2 = A.LIST[25..48],
-- field 30, 2.7.0+). 24 bits keep each part inside what %x can format.
local PART = 24
function A.Mask(earned)
  earned = earned or ns.cdb.achievements
  local parts = { 0, 0 }
  for i, a in ipairs(A.LIST) do
    local p = math.floor((i - 1) / PART) + 1
    if earned[a.id] and parts[p] then parts[p] = parts[p] + 2 ^ ((i - 1) % PART) end
  end
  return ("%x"):format(parts[1]), ("%x"):format(parts[2])
end

-- Is A.LIST[i] set? mask1/mask2 are the two parts (nil = unknown)
function A.MaskHas(mask1, mask2, i)
  local mask = i <= PART and mask1 or mask2
  local n = mask and tonumber(mask, 16)
  if not n then return false end
  return math.floor(n / 2 ^ ((i - 1) % PART)) % 2 == 1
end

function A.Count()
  local n = 0
  for _ in pairs(ns.cdb.achievements) do n = n + 1 end
  return n
end

function A.ProgressText(a, value, goal)
  local v = math.min(value or 0, goal)
  if a.fmt == "dist" then return F.Distance(v) .. " / " .. F.Distance(goal) end
  if a.fmt == "time" then return F.Time(v) .. " / " .. F.Time(goal) end
  return F.Number(v) .. " / " .. F.Number(goal)
end

---------------------------------------------------------------------------
-- Check for new ranks and achievements. silent = award without banners.
---------------------------------------------------------------------------
function A.Check(silent)
  local c = ns.cdb
  if not c then return end
  if not c.achInit then silent = true end

  local rank = A.MyRank()
  if not c.rank or silent then
    c.rank = math.max(c.rank or 1, rank)
  elseif rank > c.rank then
    c.rank = rank
    ns.Banner.Show({ kicker = L["RANK UP"], title = A.RankName(rank),
      sub = (L["Rank %d of %d  -  %s steps walked"]):format(rank, #A.RANKS, F.Number(c.total.steps)),
      icon = "Interface\\Icons\\Ability_Rogue_Sprint", color = ns.ORANGE,
      open = { tab = ns.TROPHIES_TAB, rank = true } })
    ns.Print(L["Rank up! You are now a "] .. A.RankColored(rank) .. ".")
    ns.Social.Announce("r", tostring(rank), "")
  end

  -- Trophies added in an update that you already qualify for are awarded
  -- quietly, with one toast, instead of a banner each
  local known = c.achListSize or 24 -- how many trophies existed at the last check
  local caught = 0

  for i, a in ipairs(A.LIST) do
    if not c.achievements[a.id] then
      local value, goal = a.check(c)
      if (value or 0) >= goal then
        c.achievements[a.id] = time()
        if not silent and i > known then
          caught = caught + 1
        elseif not silent then
          ns.Banner.Show({ kicker = L["ACHIEVEMENT EARNED"], title = L[a.name], sub = L[a.desc], icon = a.icon,
            color = ns.GOLD, open = { tab = ns.TROPHIES_TAB, ach = a.id } })
          ns.Print((L["Achievement earned: |cffffd100%s|r - %s"]):format(L[a.name], L[a.desc]))
          ns.Social.Announce("a", a.id, "")
        end
      end
    end
  end
  c.achListSize = #A.LIST

  if caught > 0 then
    local text = caught == 1 and L["You already earned a new trophy!"]
      or (L["You already earned %d new trophies!"]):format(caught)
    ns.Print(text)
    ns.Banner.Toast({ title = L["New trophies"], text = text, icon = "Interface\\Icons\\INV_Misc_Coin_01",
      open = { tab = ns.TROPHIES_TAB } })
  end
end
