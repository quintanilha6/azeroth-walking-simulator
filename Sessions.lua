local _, ns = ...
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
  if not quiet then ns.Print(auto and "Session started (auto)." or "Session started.") end
  ns.RefreshUI()
end

function ns.PauseSession()
  local s = ns.cdb.current
  if not s then return ns.Print("No session running.") end
  if s.paused then return end
  s.paused = true
  ns.Print("Session paused.")
  ns.RefreshUI()
end

function ns.ResumeSession()
  local s = ns.cdb.current
  if not s then return ns.Print("No session to resume.") end
  if not s.paused then return end
  s.paused = false
  ns.Print("Session resumed.")
  ns.RefreshUI()
end

-- Finish the current session and save it to history
function ns.StopSession(endTime, quiet)
  local c = ns.cdb
  local s = c.current
  if not s then
    if not quiet then ns.Print("No session running.") end
    return
  end
  c.current = nil
  s.finish = endTime or time()
  s.paused, s.lastSeen = nil, nil

  if s.steps < 1 then
    if not quiet then ns.Print("Session ended with no steps - not saved.") end
  else
    table.insert(c.history, 1, s)
    while #c.history > ns.HISTORY_CAP do table.remove(c.history) end
    c.total.sessions = c.total.sessions + 1
    ns.SyncAccount()
    if not quiet then
      ns.Print(("Session saved: %s steps, %s, %s moving, pace %s"):format(
        F.Number(s.steps), F.Distance(s.distance), F.Time(s.moving), F.Pace(s.moving, s.distance)))
    end
    ns.Social.OnActivityFinished(s)
    ns.Challenges.Check()
    ns.Achievements.Check()
  end
  ns.RefreshUI()
end

function ns.DeleteSession(index)
  table.remove(ns.cdb.history, index)
  ns.RefreshUI()
end

function ns.SetAutoMode(on)
  ns.settings.autoMode = on
  ns.Print("Auto mode " .. (on and "ON: a session starts on login and ends on logout." or "OFF: use Start/Stop."))
  if on and not ns.cdb.current then ns.StartSession(true) end
  ns.RefreshUI()
end

function ns.ResetCharacter()
  wipe(AWSCharDB)
  ns.InitCharDB()
  ns.SyncAccount()
  if ns.settings.autoMode then ns.StartSession(true, true) end
  ns.Print("Character data reset.")
  ns.RefreshUI()
end

---------------------------------------------------------------------------
-- Login / logout. PLAYER_LOGOUT also fires on /reload, so an auto session
-- is only closed if the next login comes more than RESUME_WINDOW later.
-- Manual sessions stay open until you stop them.
---------------------------------------------------------------------------
function ns.OnLogin()
  local s = ns.cdb.current
  if s and s.auto then
    local last = s.lastSeen or s.start
    if time() - last > ns.RESUME_WINDOW then
      ns.StopSession(last, true)
    end
  end
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
