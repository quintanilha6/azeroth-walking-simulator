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
}

local BY_ID = {}
for _, a in ipairs(A.LIST) do BY_ID[a.id] = a end
function A.ById(id) return BY_ID[id] end

function A.Count()
  local n = 0
  for _ in pairs(ns.cdb.achievements) do n = n + 1 end
  return n
end

function A.ProgressText(a, value, goal)
  local v = math.min(value or 0, goal)
  if a.fmt == "dist" then return F.Distance(v) .. " / " .. F.Distance(goal) end
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
      icon = "Interface\\Icons\\Ability_Rogue_Sprint", color = ns.ORANGE })
    ns.Print(L["Rank up! You are now a "] .. A.RankColored(rank) .. ".")
    ns.Social.Announce("r", tostring(rank), "")
  end

  for _, a in ipairs(A.LIST) do
    if not c.achievements[a.id] then
      local value, goal = a.check(c)
      if (value or 0) >= goal then
        c.achievements[a.id] = time()
        if not silent then
          ns.Banner.Show({ kicker = L["ACHIEVEMENT EARNED"], title = L[a.name], sub = L[a.desc], icon = a.icon,
            color = ns.GOLD })
          ns.Print((L["Achievement earned: |cffffd100%s|r - %s"]):format(L[a.name], L[a.desc]))
          ns.Social.Announce("a", a.id, "")
        end
      end
    end
  end
end
