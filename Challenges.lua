local _, ns = ...
local L = ns.L
local F = ns.F

-- Weekly (Mon-Sun) and monthly challenges. Everyone gets the same picks for a
-- period (chosen from a hash of the period key), so friends race the same goals.

local C = {}
ns.Challenges = C

local KM = 1000 / 0.9144 -- yards in a km

C.TIERS = {
  bronze  = { name = "Bronze",  color = { 0.80, 0.50, 0.20 }, icon = "Interface\\Icons\\INV_Misc_Coin_05" },
  silver  = { name = "Silver",  color = { 0.78, 0.78, 0.85 }, icon = "Interface\\Icons\\INV_Misc_Coin_03" },
  gold    = { name = "Gold",    color = { 1.00, 0.82, 0.00 }, icon = "Interface\\Icons\\INV_Misc_Coin_01" },
  monthly = { name = "Monthly", color = { 0.64, 0.21, 0.93 }, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01" },
}

-- metric: steps | dist (yards) | activeDays (2k+ steps) | zones | acts5k | bestAct
local function D(id, tier, name, desc, metric, goal)
  return { id = id, tier = tier, name = name, desc = desc, metric = metric, goal = goal }
end

C.POOLS = {
  bronze = {
    D("wb_steps", "bronze", "Stretch Your Legs", "Walk 20,000 steps this week", "steps", 20000),
    D("wb_days", "bronze", "Regular Rambler", "Be active on 4 days (2,000+ steps each)", "activeDays", 4),
    D("wb_zones", "bronze", "Sightseer", "Walk in 3 different zones", "zones", 3),
  },
  silver = {
    D("ws_steps", "silver", "Road Warrior", "Walk 50,000 steps this week", "steps", 50000),
    D("ws_dist", "silver", "Long Haul", "Cover 30 km on foot", "dist", 30 * KM),
    D("ws_acts", "silver", "Triple Threat", "Finish 3 activities of 5,000+ steps", "acts5k", 3),
    D("ws_zones", "silver", "Tourist of Azeroth", "Walk in 6 different zones", "zones", 6),
  },
  gold = {
    D("wg_steps", "gold", "Centurion", "Walk 100,000 steps this week", "steps", 100000),
    D("wg_days", "gold", "Every Single Day", "Be active all 7 days (2,000+ steps each)", "activeDays", 7),
    D("wg_big", "gold", "The Big One", "One activity of 20,000+ steps", "bestAct", 20000),
    D("wg_dist", "gold", "Ultra Walker", "Cover 75 km on foot", "dist", 75 * KM),
  },
  monthlyFixed = D("m_steps", "monthly", "Quarter Million", "Walk 250,000 steps this month", "steps", 250000),
  monthly = {
    D("m_days", "monthly", "Habit Forged", "Be active on 20 days this month", "activeDays", 20),
    D("m_zones", "monthly", "World Tour", "Walk in 15 different zones", "zones", 15),
    D("m_acts", "monthly", "Dedicated", "Finish 10 activities of 5,000+ steps", "acts5k", 10),
    D("m_dist", "monthly", "Double Century", "Cover 200 km on foot", "dist", 200 * KM),
    D("m_big", "monthly", "Epic Journey", "One activity of 40,000+ steps", "bestAct", 40000),
  },
}

local BY_ID = {}
for key, pool in pairs(C.POOLS) do
  if pool.id then BY_ID[pool.id] = pool else for _, d in ipairs(pool) do BY_ID[d.id] = d end end
end
function C.ById(id) return BY_ID[id] end
function C.TierName(ch) return L[C.TIERS[ch.tier].name] end

---------------------------------------------------------------------------
-- Periods
---------------------------------------------------------------------------
local function DayKeys(startT, count)
  local keys = {}
  for i = 0, count - 1 do
    local t = { year = startT.year, month = startT.month, day = startT.day + i, hour = 12 }
    table.insert(keys, date("%Y-%m-%d", time(t)))
  end
  return keys
end

function C.WeekPeriod(ts)
  local t = date("*t", ts or time())
  local back = (t.wday + 5) % 7 -- days since Monday (wday: 1 = Sunday)
  local st = { year = t.year, month = t.month, day = t.day - back, hour = 0 }
  local startTs = time(st)
  local endTs = time({ year = st.year, month = st.month, day = st.day + 7, hour = 0 })
  local norm = date("*t", startTs)
  return { kind = "weekly", key = "W" .. date("%Y-%m-%d", startTs), startTs = startTs, endTs = endTs,
           days = DayKeys(norm, 7) }
end

function C.MonthPeriod(ts)
  local t = date("*t", ts or time())
  local startTs = time({ year = t.year, month = t.month, day = 1, hour = 0 })
  local endTs = time({ year = t.year, month = t.month + 1, day = 1, hour = 0 })
  local n = math.floor((endTs - startTs) / 86400 + 0.5)
  return { kind = "monthly", key = "M" .. date("%Y-%m", startTs), startTs = startTs, endTs = endTs,
           days = DayKeys({ year = t.year, month = t.month, day = 1 }, n) }
end

local function Hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

local function Pick(pool, seed)
  return pool[(Hash(seed) % #pool) + 1]
end

function C.WeeklyPicks(p)
  return { Pick(C.POOLS.bronze, p.key .. "b"), Pick(C.POOLS.silver, p.key .. "s"), Pick(C.POOLS.gold, p.key .. "g") }
end

function C.MonthlyPicks(p)
  return { C.POOLS.monthlyFixed, Pick(C.POOLS.monthly, p.key .. "m") }
end

---------------------------------------------------------------------------
-- Progress
---------------------------------------------------------------------------
function C.Gather(p)
  local c = ns.cdb
  local m = { steps = 0, dist = 0, activeDays = 0, zones = 0, acts5k = 0, bestAct = 0 }
  local zones = {}
  for _, key in ipairs(p.days) do
    local d = c.daily[key]
    if d then
      m.steps, m.dist = m.steps + d.s, m.dist + d.d
      if d.s >= 2000 then m.activeDays = m.activeDays + 1 end
      if d.z then for z in pairs(d.z) do zones[z] = true end end
    end
  end
  for _ in pairs(zones) do m.zones = m.zones + 1 end
  -- an activity belongs to the period it finished in (a walk past midnight
  -- on Sunday counts for the new week, like its steps)
  for _, s in ipairs(c.history) do
    local t = s.finish or s.start
    if t >= p.startTs and t < p.endTs then
      if s.steps >= 5000 then m.acts5k = m.acts5k + 1 end
      if s.steps > m.bestAct then m.bestAct = s.steps end
    end
  end
  local cur = c.current
  local now = time()
  if cur and now >= p.startTs and now < p.endTs and cur.steps > m.bestAct then m.bestAct = cur.steps end
  return m
end

function C.WeekSteps() return C.Gather(C.WeekPeriod()).steps end
function C.MonthSteps() return C.Gather(C.MonthPeriod()).steps end

function C.ProgressText(ch, value)
  local v = math.min(value, ch.goal)
  if ch.metric == "dist" then
    return F.Distance(v) .. " / " .. F.Distance(ch.goal)
  elseif ch.metric == "activeDays" then
    return (L["%d / %d days"]):format(v, ch.goal)
  elseif ch.metric == "zones" then
    return (L["%d / %d zones"]):format(v, ch.goal)
  elseif ch.metric == "acts5k" then
    return (L["%d / %d activities"]):format(v, ch.goal)
  elseif ch.metric == "bestAct" then
    return (L["best %s / %s steps"]):format(F.Number(v), F.Number(ch.goal))
  end
  return F.Number(v) .. " / " .. F.Number(ch.goal) .. L[" steps"]
end

-- All current challenges with progress: { ch, period, value, done }
function C.Active()
  local list = {}
  local function Add(p, picks)
    local m = C.Gather(p)
    local done = ns.cdb.completed[p.key] or {}
    for _, ch in ipairs(picks) do
      table.insert(list, { ch = ch, period = p, value = m[ch.metric] or 0, done = done[ch.id] })
    end
  end
  local w, mo = C.WeekPeriod(), C.MonthPeriod()
  Add(w, C.WeeklyPicks(w))
  Add(mo, C.MonthlyPicks(mo))
  return list, w, mo
end

-- Friends (guids) who finished a challenge this period
function C.FriendsDone(periodKey, id)
  local p = ns.db.social.completions[periodKey]
  return p and p[id]
end

C.cache = { weeklyLeft = 3 }

---------------------------------------------------------------------------
-- Completion
---------------------------------------------------------------------------
function C.Check()
  if not ns.cdb then return end
  local c = ns.cdb
  local list, week = C.Active()
  local weeklyDone, weeklyLeft = 0, 0
  for _, e in ipairs(list) do
    local ch, p = e.ch, e.period
    if not e.done and e.value >= ch.goal then
      c.completed[p.key] = c.completed[p.key] or {}
      c.completed[p.key][ch.id] = time()
      e.done = time()
      table.insert(c.badges, { kind = p.kind, id = ch.id, period = p.key, ts = time() })
      local tier = C.TIERS[ch.tier]
      ns.Banner.Show({
        kicker = p.kind == "weekly" and L["WEEKLY CHALLENGE COMPLETE"] or L["MONTHLY CHALLENGE COMPLETE"],
        title = L[ch.name], sub = L[tier.name] .. "  -  " .. L[ch.desc], icon = tier.icon, color = tier.color,
        open = { tab = ns.CHALLENGES_TAB, ch = ch.id },
      })
      ns.Print((L["Challenge complete: |cffffd100%s|r (%s)"]):format(ns.ChallengeLink(ch), L[tier.name]))
      ns.Social.Announce("c", ch.id, p.key)
    end
    if p.kind == "weekly" then
      if e.done then weeklyDone = weeklyDone + 1 else weeklyLeft = weeklyLeft + 1 end
    end
  end
  C.cache.weeklyLeft = weeklyLeft

  local wdone = c.completed[week.key]
  if weeklyDone >= 3 and wdone and not wdone.champion then
    wdone.champion = time()
    ns.Banner.Show({ kicker = L["ALL WEEKLY CHALLENGES DONE"], title = L["Weekly Champion!"],
      sub = L["Bronze, Silver and Gold complete. Show off!"], icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
      color = ns.GOLD, open = { tab = ns.CHALLENGES_TAB, champion = true } })
    ns.Print(L["|cffffd100You are this week's Weekly Champion!|r"])
    ns.Social.Announce("w", "champion", week.key)
  end
end

-- Count of weekly challenges and champion titles ever completed
function C.Counts()
  local weekly, monthly, champion = 0, 0, 0
  for _, b in ipairs(ns.cdb.badges) do
    if b.kind == "weekly" then weekly = weekly + 1 elseif b.kind == "monthly" then monthly = monthly + 1 end
  end
  for key, t in pairs(ns.cdb.completed) do
    if t.champion then champion = champion + 1 end
  end
  return weekly, monthly, champion
end

function C.WeekChallengesDone(key)
  local n, t = 0, ns.cdb.completed[key or C.WeekPeriod().key]
  if t then for id in pairs(t) do if id ~= "champion" then n = n + 1 end end end
  return n
end

-- The Weekly Champion line shown on Home and on the Challenges tab.
-- Returns the text and whether you're already champion this week.
function C.ChampionText(key)
  key = key or C.WeekPeriod().key
  local t = ns.cdb.completed[key]
  if t and t.champion then return L[" |cffffd100You are this week's Weekly Champion!|r"], true end
  local left = math.max(0, 3 - C.WeekChallengesDone(key))
  return (L["|cffaaaaaaFinish %d more to become |r|cffffd100Weekly Champion|r"]):format(left), false
end

---------------------------------------------------------------------------
-- Weekly recap: first login of a new week
---------------------------------------------------------------------------
function C.WeeklyRecap()
  local c = ns.cdb
  local now = C.WeekPeriod()
  if c.lastRecap == now.key then return end
  local first = c.lastRecap == nil
  c.lastRecap = now.key
  if first then return end -- no recap on the very first run

  local last = C.WeekPeriod(now.startTs - 3 * 86400)
  local steps = C.Gather(last).steps
  if steps < 1 then return end
  local done = C.WeekChallengesDone(last.key)
  local place, total = ns.Social.PlaceInWeek(last.key, steps)
  local text = (L["Last week: %s steps, %d/3 challenges"]):format(F.Number(steps), done)
  if total > 1 then text = text .. (L[", #%d of %d friends"]):format(place, total) end
  ns.Print(text .. L[". New challenges are live!"])
  ns.Banner.Toast({ title = L["Weekly recap"], text = text, icon = "Interface\\Icons\\INV_Misc_Note_01",
    open = { tab = ns.CHALLENGES_TAB } })
end
