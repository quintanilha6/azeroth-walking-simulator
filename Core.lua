local ADDON_NAME, ns = ...
local L = ns.L

-- Default settings (saved per account in AWSDB.settings)
ns.DEFAULTS = {
  autoMode = true,      -- start a session on login, end it on logout
  units = "km",         -- "km" or "mi"
  trackerShown = true,
  trackerLocked = false,
  trackerScale = 1.0,
  shareEnabled = true,  -- send stats/activities to guild and friends
  globalBoard = true,   -- also join the "Everyone" leaderboard channel
  socialChat = true,    -- chat line when a friend finishes something
  banners = true,       -- big banners and toasts
  sounds = true,
  minimapShown = true,  -- minimap button
  minimapAngle = 200,   -- its position around the minimap, in degrees
}
ns.RESUME_WINDOW = 180  -- seconds: an auto session survives a /reload or quick relog
ns.HISTORY_CAP = 500
ns.WALK_MAX_SPEED = 4.0 -- yards/s: walking is 2.5, running is 7
-- Fixed step lengths (yards per step, 1 yard = 0.91 m). The same for everyone,
-- so a step means the same thing on every leaderboard and challenge.
ns.WALK_STRIDE = 1.4
ns.RUN_STRIDE = 2.0

ns.ORANGE = { 0.99, 0.30, 0.01 }
ns.GOLD = { 1.0, 0.82, 0.0 }
ns.state = { reason = nil, speed = 0, moving = false, zone = "", follow = false }

ns.REASON_TEXT = {
  dead = "Dead", taxi = "Flight path", vehicle = "Vehicle",
  mounted = "Mounted", flying = "Flying", swimming = "Swimming",
  follow = "Following", noinput = "Auto-run", blocked = "Blocked", afk = "AFK", idle = "Idle (steer)",
  carried = "On a boat or zeppelin",
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
  -- Step length used to be a setting; it's fixed now so steps are fair
  db.settings.stride, db.settings.walkStride, db.settings.runStride = nil, nil, nil
  db.settings.language = nil -- language now always follows the game
  CopyDefaults(db.settings, ns.DEFAULTS)
  db.chars = db.chars or {}
  db.since = db.since or time()
  -- Social data is keyed by character ID since v2; drop older name-keyed data
  if not db.social or db.social.v ~= 2 then db.social = { v = 2 } end
  db.social.people = db.social.people or {}       -- [guid] = stats
  db.social.feed = db.social.feed or {}           -- activities and events
  db.social.completions = db.social.completions or {} -- [periodKey][id][guid] = true
  ns.db, ns.settings = db, db.settings
  ns.ApplyLanguage()
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
---------------------------------------------------------------------------
-- Secret values: in some situations (combat, some instances) the game hands
-- addons "secret" values that can't be compared or tested. Reading one would
-- throw an error, so treat secret results as unknown.
---------------------------------------------------------------------------
local IsSecret = issecretvalue or function() return false end

-- Calls a game function and returns its result as a plain true/false
local function Flag(fn, ...)
  if not fn then return false end
  local ok, v = pcall(fn, ...)
  if not ok or IsSecret(v) then return false end
  return v and true or false
end
ns.Flag = Flag

-- Player speed in yards/second. If the game hides it, estimate normal
-- run speed while moving so steps keep counting.
local RUN_SPEED = 7.0
function ns.PlayerSpeed()
  local ok, speed = pcall(GetUnitSpeed, "player")
  if ok and type(speed) == "number" and not IsSecret(speed) then return speed end
  if Flag(IsPlayerMoving) then return RUN_SPEED end
  return 0
end

function ns.NotCountingReason()
  if Flag(UnitIsDeadOrGhost, "player") then return "dead" end
  if Flag(UnitOnTaxi, "player") then return "taxi" end
  if Flag(UnitInVehicle, "player") then return "vehicle" end
  if Flag(IsMounted) then return "mounted" end
  if Flag(IsFlying) then return "flying" end
  if Flag(IsSwimming) then return "swimming" end
  if ns.state.follow then return "follow" end
  return nil
end

local followWatch = CreateFrame("Frame")
followWatch:RegisterEvent("AUTOFOLLOW_BEGIN")
followWatch:RegisterEvent("AUTOFOLLOW_END")
followWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
followWatch:SetScript("OnEvent", function(_, event)
  ns.state.follow = (event == "AUTOFOLLOW_BEGIN")
end)

---------------------------------------------------------------------------
-- Rule 1: you must be moving yourself.
-- Steps only count while a key bound to forward, back, strafe or
-- move-and-steer is held, or both mouse buttons. That rules out auto-run
-- however it was started (any key, mouse button, macro or addon).
---------------------------------------------------------------------------
local MOVE_BINDINGS = { "MOVEFORWARD", "MOVEBACKWARD", "STRAFELEFT", "STRAFERIGHT", "MOVEANDSTEER" }
local MODIFIERS = { SHIFT = IsShiftKeyDown, CTRL = IsControlKeyDown, ALT = IsAltKeyDown, META = IsMetaKeyDown }
local MOUSE_NAMES = { "LeftButton", "RightButton", "MiddleButton" }

-- Is this key binding ("W", "SHIFT-W", "BUTTON4"...) being held right now?
local function BindingHeld(binding)
  local key = binding
  while true do
    local mod, rest = key:match("^(%u+)%-(.+)$")
    if not (mod and MODIFIERS[mod]) then break end
    if not Flag(MODIFIERS[mod]) then return false end
    key = rest
  end
  local button = tonumber(key:match("^BUTTON(%d+)$"))
  if button then
    return Flag(IsMouseButtonDown, MOUSE_NAMES[button] or ("Button" .. button))
  end
  return Flag(IsKeyDown, key)
end

function ns.HoldingMoveInput()
  if Flag(IsMouseButtonDown, "LeftButton") and Flag(IsMouseButtonDown, "RightButton") then return true end
  if not IsKeyDown or not GetBindingKey then return true end -- can't check on this client: don't block
  for _, name in ipairs(MOVE_BINDINGS) do
    local k1, k2 = GetBindingKey(name)
    if (k1 and BindingHeld(k1)) or (k2 and BindingHeld(k2)) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Rule 2: your position must really change.
-- The game reports run speed even while you push into a wall, so compare
-- against where you actually are. Position is hidden in instances; there we
-- fall back to speed (rule 1 still applies).
---------------------------------------------------------------------------
local function Plain(v) return type(v) == "number" and not IsSecret(v) end
-- shared with Routes.lua and the route card
ns.IsSecret, ns.Plain = IsSecret, Plain

-- Source 1: world coordinates in yards
local function UnitPos()
  if not UnitPosition then return nil end
  local ok, y, x, _, inst = pcall(UnitPosition, "player")
  if not ok or not Plain(x) or not Plain(y) then return nil end
  if IsSecret(inst) then inst = nil end
  return x, y, inst
end

-- Source 2: the world map position, converted back to world yards
local function MapPos()
  local M = C_Map
  if not (M and M.GetBestMapForUnit and M.GetPlayerMapPosition and M.GetWorldPosFromMapPos) then return nil end
  local ok, mapID = pcall(M.GetBestMapForUnit, "player")
  if not ok or not Plain(mapID) then return nil end
  local ok2, pos = pcall(M.GetPlayerMapPosition, mapID, "player")
  if not ok2 or type(pos) ~= "table" or not Plain(pos.x) or not Plain(pos.y) then return nil end
  local ok3, cont, world = pcall(M.GetWorldPosFromMapPos, mapID, pos)
  if not ok3 or type(world) ~= "table" or not Plain(world.x) or not Plain(world.y) then return nil end
  return world.x, world.y, Plain(cont) and cont or mapID
end

-- Also keeps the position in ns.state (posA, posB = UnitPosition order) for routes
local function ReadPosition()
  local st = ns.state
  local x, y, inst = UnitPos()
  if x then
    st.posSource, st.posA, st.posB, st.posInst = "unit", y, x, inst
    return x, y, inst
  end
  x, y, inst = MapPos()
  if x then
    st.posSource, st.posA, st.posB, st.posInst = "map", x, y, inst
    return x, y, inst
  end
  st.posSource, st.posA, st.posB, st.posInst = "none", nil, nil, nil
  return nil
end

-- Last confirmed position, and how far speed says we should have gone since
local anchorX, anchorY, anchorInst, pending = nil, nil, nil, 0
local function SetAnchor(x, y, inst) anchorX, anchorY, anchorInst, pending = x, y, inst, 0 end

-- Yards to count this tick, plus "blocked" when pushing without moving
local function MeasuredYards(speed, dt, realDt)
  local x, y, inst = ReadPosition()
  if not x then SetAnchor(nil) return speed * dt end                 -- position hidden: trust speed
  if not anchorX or anchorInst ~= inst then SetAnchor(x, y, inst) return 0 end -- first reading / new zone
  pending = pending + speed * realDt -- real time, so a freeze is not mistaken for a boat
  local moved = math.sqrt((x - anchorX) ^ 2 + (y - anchorY) ^ 2)
  ns.state.dbgMoved, ns.state.dbgPending = moved, pending
  if moved >= pending * 0.25 then
    -- Moving far faster than your own speed means something carries you
    -- (boat, zeppelin, knockback, teleport): that part isn't walking
    if moved > pending * 2 then SetAnchor(x, y, inst) return 0, "carried" end
    local yards = math.min(moved, pending * 1.25)
    SetAnchor(x, y, inst) -- (resets pending, so work out the distance first)
    return yards
  end
  if pending >= speed * 0.6 then -- over half a second of pushing without really moving
    SetAnchor(x, y, inst)
    return 0, "blocked"
  end
  return 0 -- wait a moment: the position can lag a frame behind
end

-- Don't credit movement made while not counting (auto-run, mounted...).
-- Just forget the last position; it's read again once counting resumes, so
-- nothing is looked up while you stand still or ride.
local function ResetAnchor() SetAnchor(nil) end

---------------------------------------------------------------------------
-- Rule 3 (only where the game hides your position, e.g. dungeons):
-- you must be actively playing. Holding W into a wall looks exactly like
-- walking there, so if you haven't steered, turned, jumped, cast, fought or
-- entered a new area for IDLE_LIMIT seconds, counting pauses.
---------------------------------------------------------------------------
local IDLE_LIMIT = 5
local lastActive = GetTime()
local lastCursorX, lastCursorY, lastFacing
local STEER_CREDIT = 30
local steerSince
local ACTIVE_BINDINGS = { "TURNLEFT", "TURNRIGHT", "STRAFELEFT", "STRAFERIGHT", "JUMP", "MOVEBACKWARD" }

local function MarkActive() lastActive = GetTime() end

local function SampleActivity()
  -- mouse moved (not while steering: the cursor is frozen then)
  if GetCursorPosition then
    local ok, cx, cy = pcall(GetCursorPosition)
    if ok and Plain(cx) and Plain(cy) then
      if lastCursorX and (math.abs(cx - lastCursorX) > 2 or math.abs(cy - lastCursorY) > 2) then MarkActive() end
      lastCursorX, lastCursorY = cx, cy
    end
  end
  -- raw mouse movement: on some clients this still works while steering
  local steering = Flag(IsMouselooking) and Flag(IsMouseButtonDown, "RightButton")
  if GetCursorDelta then
    local ok, dx, dy = pcall(GetCursorDelta)
    if ok and Plain(dx) and Plain(dy) and (math.abs(dx) + math.abs(dy)) > 0 then
      MarkActive()
      ns.state.mouseDelta = true
      if steering then ns.state.deltaWhileSteering = true end
    end
  end
  -- If this client can't show mouse movement while you steer with the right
  -- mouse button, holding it has to count as actively playing
  -- (for up to STEER_CREDIT seconds in a row; after that a real sign of play is
  -- needed, so a held-down mouse can't run into a wall forever)
  if steering then
    steerSince = steerSince or GetTime()
    if not ns.state.deltaWhileSteering and GetTime() - steerSince < STEER_CREDIT then MarkActive() end
  else
    steerSince = nil
  end
  -- turned around (covers steering with the right mouse button, where readable)
  if GetPlayerFacing then
    local ok, f = pcall(GetPlayerFacing)
    if ok and Plain(f) then
      if lastFacing and math.abs(f - lastFacing) > 0.02 then MarkActive() end
      lastFacing = f
      ns.state.facingReadable = true
    else
      ns.state.facingReadable = false
    end
  end
  -- turn / strafe / jump / back keys
  if GetBindingKey then
    for _, name in ipairs(ACTIVE_BINDINGS) do
      local k1, k2 = GetBindingKey(name)
      if (k1 and BindingHeld(k1)) or (k2 and BindingHeld(k2)) then MarkActive() break end
    end
  end
  if Flag(UnitAffectingCombat, "player") then MarkActive() end
end

function ns.IdleSeconds() return GetTime() - lastActive end

local activityWatch = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
                      "ZONE_CHANGED_NEW_AREA", "LOOT_OPENED", "PLAYER_ENTERING_WORLD" }) do
  activityWatch:RegisterEvent(ev)
end
activityWatch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
activityWatch:SetScript("OnEvent", MarkActive)

---------------------------------------------------------------------------
-- Tracking: distance actually moved on foot (or speed x time where the game
-- hides your position), only while you hold movement keys yourself
---------------------------------------------------------------------------
local uiAcc, winAcc, checkAcc = 0, 0, 0
local lastCheck

local function AddZone(s, zone)
  for _, z in ipairs(s.zones) do
    if z == zone then return end
  end
  table.insert(s.zones, zone)
end

function ns.Tick(dt)
  local c = ns.cdb
  SampleActivity()
  local reason = ns.NotCountingReason()
  if not reason and Flag(UnitIsAFK, "player") then reason = "afk" end
  local speed = ns.PlayerSpeed()
  if not reason and speed > 0 and not ns.HoldingMoveInput() then reason = "noinput" end

  local yards = 0
  if not reason and speed > 0 then
    local why
    yards, why = MeasuredYards(speed, dt, ns.state.realDt or dt)
    if why == "carried" then
      ns.state.carriedUntil = GetTime() + 3
    elseif why then
      ns.state.blockedUntil = GetTime() + 1
    end
    -- on a boat you only move faster than walking now and then (the position
    -- updates in jumps), so keep not counting for a moment after each one
    if (ns.state.carriedUntil or 0) > GetTime() then yards, reason = 0, "carried"
    elseif yards == 0 and (ns.state.blockedUntil or 0) > GetTime() then reason = "blocked" end
    -- Position hidden (dungeons): only count while you're actively playing
    if yards > 0 and ns.state.posSource == "none" and ns.IdleSeconds() > IDLE_LIMIT then
      yards, reason = 0, "idle"
    end
  else
    ResetAnchor()
    -- Riding a mount: no steps, but draw it on the route (in mount colors)
    local cur = ns.cdb.current
    if reason == "mounted" and speed > 0 and cur and not cur.paused then
      ReadPosition()
      local st = ns.state
      -- hidden speed reads as running; a mount is at least the 60% band
      if st.posA then ns.Routes.Record(cur, st.posA, st.posB, st.posInst, math.max(speed, 11)) end
    elseif (reason == "noinput" or reason == "follow") and speed > 0 and cur and not cur.paused then
      -- Auto-run and /follow: drawn on the route as their own dashed line, no steps
      ReadPosition()
      local st = ns.state
      if st.posA then ns.Routes.Record(cur, st.posA, st.posB, st.posInst, speed, ns.Routes.AUTO_BAND) end
    end
  end
  ns.state.reason, ns.state.speed = reason, speed

  -- /aws debug: once a second, show what the counter sees
  if ns.debug then
    local d = ns.debugInfo
    d.t, d.yards, d.speed = d.t + dt, d.yards + yards, d.speed + speed * dt
    if d.t >= 1 then
      ns.Print(("debug: keys=%s  pos=%s  speed-says=%.2f yd  counted=%.2f yd  last moved=%.2f / expected %.2f  " ..
        "idle=%ds  facing=%s  mousedelta=%s  status=%s")
        :format(ns.HoldingMoveInput() and "held" or "no", ns.state.posSource or "?", d.speed, d.yards,
          ns.state.dbgMoved or 0, ns.state.dbgPending or 0, ns.IdleSeconds(),
          ns.state.facingReadable and "readable" or "hidden",
          GetCursorDelta and (ns.state.mouseDelta and "seen" or L["none yet"]) or "unsupported",
          tostring(reason or "counting")))
      d.t, d.yards, d.speed = 0, 0, 0
    end
  end

  local s = c.current
  local active = s and not s.paused
  if active then s.elapsed = s.elapsed + dt end

  if yards > 0 then
    local stride = (speed < ns.WALK_MAX_SPEED) and ns.WALK_STRIDE or ns.RUN_STRIDE
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
    -- explored zones are kept by map ID, so they're the same in every game language
    local zkey = ns.state.zoneKey or (zone ~= "" and zone) or nil
    if zkey then
      day.z = day.z or {}
      day.z[zkey] = true
      if not c.zones[zkey] then c.zones[zkey] = time() end
    end

    if active then
      s.steps, s.distance, s.moving = s.steps + steps, s.distance + yards, s.moving + dt
      if zone ~= "" then AddZone(s, zone) end
      local st = ns.state
      if st.posA then ns.Routes.Record(s, st.posA, st.posB, st.posInst, speed) end
    end
    ns.state.moving = true
    ns.state.instRate = steps / dt
  else
    ns.state.moving = false
    ns.state.instRate = 0
  end
  -- Smoothed steps per second, sent to friends so their leaderboard can count
  -- your steps up live between updates
  local r = ns.state.rate or 0
  r = r + (ns.state.instRate - r) * math.min(1, dt / 2)
  if r < 0.05 then r = 0 end
  ns.state.rate = r

  uiAcc, winAcc, checkAcc = uiAcc + dt, winAcc + dt, checkAcc + dt
  if checkAcc >= 5 then
    checkAcc = 0
    -- challenges and achievements only move when you walk (or a new day starts)
    local fp = math.floor(c.total.steps) .. ":" .. date("%Y-%m-%d")
    if fp ~= lastCheck then
      lastCheck = fp
      ns.Challenges.Check()
      ns.Achievements.Check()
    end
  end
  if uiAcc >= 0.25 then
    uiAcc = 0
    if ns.Tracker then ns.Tracker:Refresh() end
  end
  -- The Social tab refreshes 4x a second so friends' steps count up smoothly
  local winEvery = (ns.Window and ns.Window.current == ns.SOCIAL_TAB) and 0.25 or 1
  if winAcc >= winEvery then
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
  -- the real time passed, for comparing with how far you really moved after
  -- a hitch (so a freeze isn't mistaken for a boat ride)
  ns.state.realDt = math.min(dt, 10)
  if dt > 1 then dt = 1 end -- loading screens / hitches
  ns.Tick(dt)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function UpdateZone()
  ns.state.zone = GetRealZoneText() or ""
  ns.state.zoneKey = ns.ZoneMapID()
  if ns.state.zoneKey then ns.MigrateZoneNames() end
end

-- The zone (or dungeon) you're in, as a map ID; nil if the game doesn't say
function ns.ZoneMapID()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo and Enum and Enum.UIMapType) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not Plain(id) then return nil end
  for _ = 1, 5 do
    local info = C_Map.GetMapInfo(id)
    if not info then return nil end
    local t = info.mapType
    if t == Enum.UIMapType.Zone or t == Enum.UIMapType.Dungeon then return id end
    if t < Enum.UIMapType.Zone or not info.parentMapID or info.parentMapID == 0 then return nil end
    id = info.parentMapID -- a small sub-map: use the zone it's in
  end
end

-- Zones saved by name before 2.4.2 become map IDs (names in this game language)
function ns.MigrateZoneNames()
  local c = ns.cdb
  if not c or c.zonesById or not (C_Map and C_Map.GetMapChildrenInfo and Enum and Enum.UIMapType) then return end
  local top = ns.ZoneMapID()
  for _ = 1, 10 do
    local info = top and C_Map.GetMapInfo(top)
    if not info or not info.parentMapID or info.parentMapID == 0 then break end
    top = info.parentMapID
  end
  if not top then return end -- try again next login (e.g. logged in inside a dungeon)
  local byName = {}
  for _, m in ipairs(C_Map.GetMapChildrenInfo(top, nil, true) or {}) do
    if (m.mapType == Enum.UIMapType.Zone or m.mapType == Enum.UIMapType.Dungeon) and m.name and not byName[m.name] then
      byName[m.name] = m.mapID
    end
  end
  local function Convert(set, keepEarliest)
    local moved = {}
    for k, v in pairs(set) do
      if type(k) == "string" and byName[k] then moved[k] = v end
    end
    for name, v in pairs(moved) do
      local id = byName[name]
      set[name] = nil
      if keepEarliest and set[id] then set[id] = math.min(set[id], v) else set[id] = v end
    end
  end
  Convert(c.zones, true)
  for _, day in pairs(c.daily) do
    if day.z then Convert(day.z) end
  end
  c.zonesById = true
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
    ns.MinimapButton.Create()
    ns.Options.Create()
    self:SetScript("OnUpdate", OnUpdate)
    if migrated then
      ns.Print(L["Imported your Stride data. Welcome to Azeroth Walking Simulator!"])
    end
    ns.Print(L["Type /aws to open. Good luck on this week's challenges!"])
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
  ns.Print((L["Rank: %s"]):format(ns.Achievements.RankName(ns.Achievements.RankIndex(t.steps))))
  ns.Print((L["Today: %s steps, %s"]):format(F.Number(today.s), F.Distance(today.d)))
  ns.Print((L["This week: %s steps  |  This month: %s steps"]):format(
    F.Number(ns.Challenges.WeekSteps()), F.Number(ns.Challenges.MonthSteps())))
  ns.Print((L["This character: %s steps, %s, %d activities (since %s)"]):format(
    F.Number(t.steps), F.Distance(t.distance), t.sessions, F.Day(ns.cdb.since)))
  ns.Print((L["Account (%d chars): %s steps, %s"]):format(acct.chars, F.Number(acct.steps), F.Distance(acct.distance)))
  local s = ns.cdb.current
  if s then
    ns.Print((L["Session: %s steps, %s, %s moving%s"]):format(F.Number(s.steps), F.Distance(s.distance),
      F.Time(s.moving), s.paused and L[" (paused)"] or ""))
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
    elseif s then ns.Print(L["A session is already running."])
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
  elseif cmd == "options" or cmd == "settings" or cmd == "config" then
    ns.Options.Open()
  elseif cmd == "minimap" then
    ns.settings.minimapShown = not ns.settings.minimapShown
    ns.MinimapButton.Apply()
  elseif cmd == "route" then
    -- the walk in progress if it has a route, otherwise the last activity
    local cur = ns.cdb.current
    ns.RouteViewer.Open(ns.Routes.Has(cur) and cur or ns.cdb.history[1])
  elseif cmd == "debug" and arg == "net" then
    -- route sharing and kudos traffic, for tracking down sharing problems
    ns.netDebug = not ns.netDebug
    ns.Print("Network debug " .. (ns.netDebug and "ON. Type /aws debug net again to stop." or "OFF."))
  elseif cmd == "debug" then
    ns.debug = not ns.debug
    ns.debugInfo = { t = 0, yards = 0, speed = 0 }
    ns.Print(L["Debug readout "] .. (ns.debug and L["ON (once a second). Type /aws debug again to stop."] or "OFF."))
  else
    ns.Print(L["Commands: /aws (window), start, pause, resume, stop, auto on|off, tracker, stats, "] ..
      L["challenges, trophies, social, share, route, testbanner, debug"])
  end
end

SLASH_AZEROTHWALKINGSIM1 = "/aws"
SLASH_AZEROTHWALKINGSIM2 = "/walksim"
SlashCmdList.AZEROTHWALKINGSIM = Slash
