local ADDON_NAME, ns = ...

-- Default settings (saved per account in AWSDB.settings)
ns.DEFAULTS = {
  autoMode = true,      -- start a session on login, end it on logout
  walkStride = 1.4,     -- yards per step while walking (1 yard = 0.91 m)
  runStride = 2.0,      -- yards per step while running
  units = "km",         -- "km" or "mi"
  trackerShown = true,
  trackerLocked = false,
  trackerScale = 1.0,
  shareEnabled = true,  -- send stats/activities to guild and friends
  globalBoard = true,   -- also join the "Everyone" leaderboard channel
  socialChat = true,    -- chat line when a friend finishes something
  banners = true,       -- big banners and toasts
  sounds = true,
}
ns.RESUME_WINDOW = 180  -- seconds: an auto session survives a /reload or quick relog
ns.HISTORY_CAP = 500
ns.WALK_MAX_SPEED = 4.0 -- yards/s: walking is 2.5, running is 7

ns.ORANGE = { 0.99, 0.30, 0.01 }
ns.GOLD = { 1.0, 0.82, 0.0 }
ns.state = { reason = nil, speed = 0, moving = false, zone = "", autorun = false, follow = false }

ns.REASON_TEXT = {
  dead = "Dead", taxi = "Flight path", vehicle = "Vehicle",
  mounted = "Mounted", flying = "Flying", swimming = "Swimming",
  autorun = "Auto-run", follow = "Following",
}

function ns.Print(msg)
  print("|cfffc4c02AWS|r: " .. msg)
end

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = v end
  end
end

local function DeepCopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = DeepCopy(v) end
  return r
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
function ns.InitCharDB()
  AWSCharDB = AWSCharDB or {}
  local c = AWSCharDB
  c.since = c.since or time()
  c.total = c.total or {}
  CopyDefaults(c.total, { steps = 0, distance = 0, moving = 0, sessions = 0 })
  c.daily = c.daily or {}         -- ["YYYY-MM-DD"] = { s = steps, d = yards, z = { [zone] = true } }
  c.history = c.history or {}     -- finished sessions, newest first
  c.zones = c.zones or {}         -- every zone you've walked in: [zone] = first time
  c.completed = c.completed or {} -- [periodKey] = { [challengeId] = time, champion = time }
  c.badges = c.badges or {}       -- challenge completions log
  c.achievements = c.achievements or {} -- [id] = time
  c.kudosGiven = c.kudosGiven or 0
  c.kudosReceived = c.kudosReceived or 0
  ns.cdb = c
end

local migrated = false

local function InitDB()
  -- One-time import from the old "Stride" addon (kept as a small data bridge)
  if not AWSDB and type(StrideDB) == "table" then
    AWSDB = DeepCopy(StrideDB)
    AWSDB.social = nil
    migrated = true
  end
  if not AWSCharDB and type(StrideCharDB) == "table" then
    AWSCharDB = DeepCopy(StrideCharDB)
    migrated = true
  end

  AWSDB = AWSDB or {}
  local db = AWSDB
  db.settings = db.settings or {}
  db.settings.stride = nil
  CopyDefaults(db.settings, ns.DEFAULTS)
  db.chars = db.chars or {}
  db.since = db.since or time()
  -- Social data is keyed by character ID since v2; drop older name-keyed data
  if not db.social or db.social.v ~= 2 then db.social = { v = 2 } end
  db.social.people = db.social.people or {}       -- [guid] = stats
  db.social.feed = db.social.feed or {}           -- activities and events
  db.social.completions = db.social.completions or {} -- [periodKey][id][guid] = true
  ns.db, ns.settings = db, db.settings
  ns.InitCharDB()
end

function ns.CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

-- Copy this character's totals into the account DB
function ns.SyncAccount()
  if not ns.db or not ns.charKey then return end
  local t = ns.cdb.total
  local e = ns.db.chars[ns.charKey] or {}
  e.steps, e.distance, e.moving, e.sessions = t.steps, t.distance, t.moving, t.sessions
  e.since = ns.cdb.since
  local _, class = UnitClass("player")
  e.class = class or e.class
  e.level = UnitLevel("player") or e.level
  ns.db.chars[ns.charKey] = e
end

function ns.AccountTotals()
  ns.SyncAccount()
  local r = { steps = 0, distance = 0, moving = 0, sessions = 0, chars = 0 }
  for _, e in pairs(ns.db.chars) do
    r.steps = r.steps + (e.steps or 0)
    r.distance = r.distance + (e.distance or 0)
    r.moving = r.moving + (e.moving or 0)
    r.sessions = r.sessions + (e.sessions or 0)
    r.chars = r.chars + 1
  end
  return r
end

function ns.PlaySound(id)
  if ns.settings.sounds and PlaySound then pcall(PlaySound, id) end
end

---------------------------------------------------------------------------
-- On-foot check: returns a reason when movement should NOT count
---------------------------------------------------------------------------
function ns.NotCountingReason()
  if UnitIsDeadOrGhost("player") then return "dead" end
  if UnitOnTaxi("player") then return "taxi" end
  if UnitInVehicle and UnitInVehicle("player") then return "vehicle" end
  if IsMounted() then return "mounted" end
  if IsFlying and IsFlying() then return "flying" end
  if IsSwimming() then return "swimming" end
  if ns.state.autorun then return "autorun" end
  if ns.state.follow then return "follow" end
  return nil
end

---------------------------------------------------------------------------
-- Auto-run detection: only steps you walk yourself count.
-- Auto-run is toggled by ToggleAutoRun (Num Lock / key binding) and cancelled
-- by pressing forward or back, or by stopping.
---------------------------------------------------------------------------
local function SafeHook(name, fn)
  if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end
SafeHook("ToggleAutoRun", function() ns.state.autorun = not ns.state.autorun end)
SafeHook("StartAutoRun", function() ns.state.autorun = true end)
SafeHook("StopAutoRun", function() ns.state.autorun = false end)
SafeHook("MoveForwardStart", function() ns.state.autorun = false end)
SafeHook("MoveBackwardStart", function() ns.state.autorun = false end)

local moveWatch = CreateFrame("Frame")
moveWatch:RegisterEvent("PLAYER_STOPPED_MOVING")
moveWatch:RegisterEvent("AUTOFOLLOW_BEGIN")
moveWatch:RegisterEvent("AUTOFOLLOW_END")
moveWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
moveWatch:SetScript("OnEvent", function(_, event)
  if event == "AUTOFOLLOW_BEGIN" then
    ns.state.follow = true
  elseif event == "AUTOFOLLOW_END" then
    ns.state.follow = false
  else
    ns.state.autorun = false
    if event == "PLAYER_ENTERING_WORLD" then ns.state.follow = false end
  end
end)

---------------------------------------------------------------------------
-- Tracking: distance = speed (yards/s) * time, only while on foot
---------------------------------------------------------------------------
local uiAcc, winAcc, checkAcc = 0, 0, 0

local function AddZone(s, zone)
  for _, z in ipairs(s.zones) do
    if z == zone then return end
  end
  table.insert(s.zones, zone)
end

function ns.Tick(dt)
  local c = ns.cdb
  local reason = ns.NotCountingReason()
  local speed = GetUnitSpeed("player") or 0
  ns.state.reason, ns.state.speed = reason, speed

  local s = c.current
  local active = s and not s.paused
  if active then s.elapsed = s.elapsed + dt end

  if not reason and speed > 0 then
    local yards = speed * dt
    local stride = (speed < ns.WALK_MAX_SPEED) and ns.settings.walkStride or ns.settings.runStride
    local steps = yards / stride
    local t = c.total
    t.steps, t.distance, t.moving = t.steps + steps, t.distance + yards, t.moving + dt

    local key = date("%Y-%m-%d")
    local day = c.daily[key]
    if not day then
      day = { s = 0, d = 0 }
      c.daily[key] = day
    end
    day.s, day.d = day.s + steps, day.d + yards

    local zone = ns.state.zone
    if zone ~= "" then
      day.z = day.z or {}
      day.z[zone] = true
      if not c.zones[zone] then c.zones[zone] = time() end
    end

    if active then
      s.steps, s.distance, s.moving = s.steps + steps, s.distance + yards, s.moving + dt
      if zone ~= "" then AddZone(s, zone) end
    end
    ns.state.moving = true
  else
    ns.state.moving = false
  end

  uiAcc, winAcc, checkAcc = uiAcc + dt, winAcc + dt, checkAcc + dt
  if checkAcc >= 5 then
    checkAcc = 0
    ns.Challenges.Check()
    ns.Achievements.Check()
  end
  if uiAcc >= 0.25 then
    uiAcc = 0
    if ns.Tracker then ns.Tracker:Refresh() end
  end
  if winAcc >= 1 then
    winAcc = 0
    if ns.Window and ns.Window:IsShown() then ns.Window:RefreshLive() end
  end
end

-- Refresh everything after a session starts/stops/changes
function ns.RefreshUI()
  if ns.Tracker then ns.Tracker:Refresh() end
  if ns.Window and ns.Window:IsShown() then ns.Window:RefreshPage() end
end

-- Refresh the Social / Challenges tabs when friend data arrives
function ns.OnSocialChanged()
  local w = ns.Window
  if w and w:IsShown() and (w.current == ns.SOCIAL_TAB or w.current == ns.CHALLENGES_TAB) then
    w:RefreshPage()
  end
end

local driver = CreateFrame("Frame")
local acc = 0
local function OnUpdate(_, elapsed)
  acc = acc + elapsed
  if acc < 0.1 then return end
  local dt = acc
  acc = 0
  if dt > 1 then dt = 1 end -- loading screens / hitches
  ns.Tick(dt)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function UpdateZone()
  ns.state.zone = GetRealZoneText() or ""
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_LOGOUT")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    InitDB()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    ns.charKey = ns.CharKey()
    UpdateZone()
    ns.SyncAccount()
    ns.OnLogin()
    ns.CreateTracker()
    self:SetScript("OnUpdate", OnUpdate)
    if migrated then
      ns.Print("Imported your Stride data. Welcome to Azeroth Walking Simulator!")
    end
    ns.Print("Type /aws to open. Good luck on this week's challenges!")
    C_Timer.After(3, function()
      ns.Achievements.Check(not ns.cdb.achInit) -- first run: award old progress quietly
      ns.cdb.achInit = true
      ns.Challenges.Check()
    end)
    C_Timer.After(15, function() ns.Challenges.WeeklyRecap() end)
  elseif event == "PLAYER_LOGOUT" then
    ns.OnLogout()
    ns.SyncAccount()
  else
    UpdateZone()
  end
end)

---------------------------------------------------------------------------
-- Slash commands and addon-compartment button
---------------------------------------------------------------------------
function AWS_OnCompartmentClick()
  ns.ToggleWindow()
end

local function PrintStats()
  local t, F = ns.cdb.total, ns.F
  local today = ns.GetDay(date("%Y-%m-%d"))
  local acct = ns.AccountTotals()
  ns.Print(("Rank: %s"):format(ns.Achievements.RankName(ns.Achievements.RankIndex(t.steps))))
  ns.Print(("Today: %s steps, %s"):format(F.Number(today.s), F.Distance(today.d)))
  ns.Print(("This week: %s steps  |  This month: %s steps"):format(
    F.Number(ns.Challenges.WeekSteps()), F.Number(ns.Challenges.MonthSteps())))
  ns.Print(("This character: %s steps, %s, %d activities (since %s)"):format(
    F.Number(t.steps), F.Distance(t.distance), t.sessions, F.Day(ns.cdb.since)))
  ns.Print(("Account (%d chars): %s steps, %s"):format(acct.chars, F.Number(acct.steps), F.Distance(acct.distance)))
  local s = ns.cdb.current
  if s then
    ns.Print(("Session: %s steps, %s, %s moving%s"):format(F.Number(s.steps), F.Distance(s.distance),
      F.Time(s.moving), s.paused and " (paused)" or ""))
  end
end

local function Slash(msg)
  msg = strlower(strtrim(msg or ""))
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "show" then
    ns.ToggleWindow()
  elseif cmd == "start" then
    local s = ns.cdb.current
    if s and s.paused then ns.ResumeSession()
    elseif s then ns.Print("A session is already running.")
    else ns.StartSession(false) end
  elseif cmd == "pause" then
    ns.PauseSession()
  elseif cmd == "resume" then
    ns.ResumeSession()
  elseif cmd == "stop" or cmd == "finish" then
    ns.StopSession()
  elseif cmd == "auto" then
    local on
    if arg == "on" then on = true elseif arg == "off" then on = false else on = not ns.settings.autoMode end
    ns.SetAutoMode(on)
  elseif cmd == "tracker" then
    ns.settings.trackerShown = not ns.settings.trackerShown
    ns.ApplyTrackerSettings()
  elseif cmd == "stats" then
    PrintStats()
  elseif cmd == "challenges" then
    ns.ToggleWindow(ns.CHALLENGES_TAB)
  elseif cmd == "trophies" then
    ns.ToggleWindow(ns.TROPHIES_TAB)
  elseif cmd == "social" then
    ns.ToggleWindow(ns.SOCIAL_TAB)
  elseif cmd == "share" then
    ns.Social.ShareToChat(ns.cdb.history[1])
  elseif cmd == "testbanner" then
    ns.Banner.Test()
  else
    ns.Print("Commands: /aws (window), start, pause, resume, stop, auto on|off, tracker, stats, " ..
      "challenges, trophies, social, share, testbanner")
  end
end

SLASH_AZEROTHWALKINGSIM1 = "/aws"
SLASH_AZEROTHWALKINGSIM2 = "/walksim"
SlashCmdList.AZEROTHWALKINGSIM = Slash
