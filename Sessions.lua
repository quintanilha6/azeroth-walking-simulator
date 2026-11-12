local _, ns = ...
local L = ns.L
local F = ns.F

---------------------------------------------------------------------------
-- Session control
---------------------------------------------------------------------------
function ns.StartSession(auto, quiet)
  if ns.cdb.current then return end
  ns.cdb.current = {
    start = time(), elapsed = 0, moving = 0, distance = 0, steps = 0,
    zones = {}, paused = false, auto = auto and true or false,
  }
  if not quiet then ns.Print(auto and L["Session started (auto)."] or L["Session started."]) end
  ns.RefreshUI()
end

function ns.PauseSession()
  local s = ns.cdb.current
  if not s then return ns.Print(L["No session running."]) end
  if s.paused then return end
  s.paused = true
  ns.Print(L["Session paused."])
  ns.RefreshUI()
end

function ns.ResumeSession()
  local s = ns.cdb.current
  if not s then return ns.Print(L["No session to resume."]) end
  if not s.paused then return end
  s.paused = false
  ns.Print(L["Session resumed."])
  ns.RefreshUI()
end

-- Finish the current session and save it to history
function ns.StopSession(endTime, quiet)
  local c = ns.cdb
  local s = c.current
  if not s then
    if not quiet then ns.Print(L["No session running."]) end
    return
  end
  c.current = nil
  s.finish = endTime or time()
  s.paused, s.lastSeen, s.alive = nil, nil, nil

  if s.steps < 1 then
    if not quiet then ns.Print(L["Session ended with no steps - not saved."]) end
  else
    ns.Routes.Finish(s)
    table.insert(c.history, 1, s)
    while #c.history > ns.HISTORY_CAP do table.remove(c.history) end
    ns.Routes.Trim(c.history)
    c.total.sessions = c.total.sessions + 1
    ns.SyncAccount()
    if not quiet then
      ns.Print((L["Session saved: %s steps, %s, %s moving, pace %s"]):format(
        F.Number(s.steps), F.Distance(s.distance), F.Time(s.moving), F.Pace(s.moving, s.distance)))
    end
    ns.Social.OnActivityFinished(s)
    ns.Challenges.Check()
    ns.Achievements.Check()
  end
  ns.RefreshUI()
end

-- activity: the activity table (or its index in history)
function ns.DeleteSession(activity)
  local history = ns.cdb.history
  if type(activity) == "number" then activity = history[activity] end
  for i, a in ipairs(history) do
    if a == activity then
      table.remove(history, i)
      break
    end
  end
  ns.RefreshUI()
end

function ns.SetAutoMode(on)
  ns.settings.autoMode = on
  ns.Print(L["Auto mode "] .. (on and L["ON: a session starts on login and ends on logout."] or L["OFF: use Start/Stop."]))
  if on and not ns.cdb.current then ns.StartSession(true) end
  ns.RefreshUI()
end

function ns.ResetCharacter()
  wipe(AWSCharDB)
  ns.InitCharDB()
  ns.SyncAccount()
  if ns.settings.autoMode then ns.StartSession(true, true) end
  ns.Print(L["Character data reset."])
  ns.RefreshUI()
end

---------------------------------------------------------------------------
-- Login / logout. An auto session ends when you log out and a new one starts
-- when you log in; a /reload carries on the same one. PLAYER_LOGOUT fires for
-- both, so the next login tells them apart: isInitialLogin / isReloadingUi
-- from PLAYER_ENTERING_WORLD, or (clients without them) whether you were away
-- longer than RESUME_WINDOW. With Auto mode on this applies to every
-- session, including ones started with the Start button; with Auto mode off,
-- sessions stay open until you finish them.
---------------------------------------------------------------------------
function ns.OnLogin(isInitialLogin, isReloadingUi)
  local s = ns.cdb.current
  if s and (s.auto or ns.settings.autoMode) then
    -- lastSeen is set at logout; after a crash it's missing, so fall back to
    -- the last time the session was seen running (alive, every 30 s)
    local last = s.lastSeen or s.alive or s.start
    local newLogin
    if isInitialLogin ~= nil or isReloadingUi ~= nil then
      newLogin = isInitialLogin and not isReloadingUi
    else
      newLogin = time() - last > ns.RESUME_WINDOW
    end
    if newLogin then
      ns.StopSession(last, true)
      if s.steps >= 1 then
        ns.Print((L["Your last session was saved (%s steps). A new one has started."]):format(F.Number(s.steps)))
      end
    end
  end
  -- what the last login looked like (/dump AWSCharDB.lastLogin to check)
  ns.cdb.lastLogin = {
    initial = isInitialLogin, reload = isReloadingUi, had = s and (s.auto and "auto" or "manual") or "none",
    kept = (s ~= nil and ns.cdb.current == s), at = date("%H:%M:%S"),
  }
  if ns.cdb.current then
    ns.cdb.current.lastSeen = nil
  elseif ns.settings.autoMode then
    ns.StartSession(true, true)
  end
end

function ns.OnLogout()
  local s = ns.cdb.current
  if s then s.lastSeen = time() end
end

---------------------------------------------------------------------------
-- Stats helpers
---------------------------------------------------------------------------
local function KeyToTime(key)
  local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function TodayNoon()
  local t = date("*t")
  t.hour, t.min, t.sec = 12, 0, 0
  return time(t)
end

function ns.GetDay(key)
  return ns.cdb.daily[key] or { s = 0, d = 0 }
end

-- Last n days, oldest first: { key, ts, s, d }
function ns.LastDays(n)
  local base, out = TodayNoon(), {}
  for i = n - 1, 0, -1 do
    local ts = base - i * 86400
    local key = date("%Y-%m-%d", ts)
    local day = ns.GetDay(key)
    table.insert(out, { key = key, ts = ts, s = day.s, d = day.d })
  end
  return out
end

-- A day counts toward a streak if you took at least 1 step
function ns.Streaks()
  local daily = ns.cdb.daily
  local current, base = 0, TodayNoon()
  for i = 0, 3650 do
    local day = daily[date("%Y-%m-%d", base - i * 86400)]
    if day and day.s >= 1 then
      current = current + 1
    elseif i > 0 then
      break -- today with no steps yet doesn't break the streak
    end
  end

  local times = {}
  for key, day in pairs(daily) do
    if day.s >= 1 then
      local ts = KeyToTime(key)
      if ts then table.insert(times, ts) end
    end
  end
  table.sort(times)
  local longest, run = 0, 0
  for i, ts in ipairs(times) do
    if i > 1 and math.floor((ts - times[i - 1]) / 86400 + 0.5) == 1 then
      run = run + 1
    else
      run = 1
    end
    if run > longest then longest = run end
  end
  return current, longest
end

-- Personal bests from history and daily log
function ns.Records()
  local r = {}
  for _, s in ipairs(ns.cdb.history) do
    if not r.steps or s.steps > r.steps.steps then r.steps = s end
    if not r.distance or s.distance > r.distance.distance then r.distance = s end
    if not r.moving or s.moving > r.moving.moving then r.moving = s end
  end
  for key, day in pairs(ns.cdb.daily) do
    if not r.dayKey or day.s > r.daySteps then r.dayKey, r.daySteps, r.dayDist = key, day.s, day.d end
  end
  return r
end
