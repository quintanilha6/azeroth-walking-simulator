local _, ns = ...
local F = ns.F

local WIDTH, HEIGHT = 640, 560
local TABS = { "Overview", "Activities", "Challenges", "Trophies", "Social", "Settings" }
ns.CHALLENGES_TAB, ns.TROPHIES_TAB, ns.SOCIAL_TAB = 3, 4, 5

---------------------------------------------------------------------------
-- Small UI helpers
---------------------------------------------------------------------------
local function Header(parent, x, y, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetTextColor(unpack(ns.ORANGE))
  fs:SetText(text)
  return fs
end

-- A stat tile: small gray label with a big value under it. Returns the value string.
local function Tile(parent, x, y, label)
  local l = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  l:SetPoint("TOPLEFT", x, y)
  l:SetText(label)
  local v = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
  v:SetText("-")
  return v
end

local function Text(parent, font, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  return fs
end

---------------------------------------------------------------------------
-- Overview
---------------------------------------------------------------------------
local function BuildOverview(page)
  local o = {}
  local COL = { 0, 150, 300, 450 }

  Header(page, 0, 0, "This session")
  o.sStatus = Text(page, "GameFontHighlightSmall", 110, -1)
  o.sSteps = Tile(page, COL[1], -18, "Steps")
  o.sDist = Tile(page, COL[2], -18, "Distance")
  o.sMoving = Tile(page, COL[3], -18, "Moving time")
  o.sPace = Tile(page, COL[4], -18, "Avg pace")

  Header(page, 0, -66, "Steps")
  o.tSteps = Tile(page, COL[1], -84, "Today")
  o.wSteps = Tile(page, COL[2], -84, "This week")
  o.mSteps = Tile(page, COL[3], -84, "This month")
  o.tDist = Tile(page, COL[4], -84, "Distance today")

  -- 7-day bar chart
  Header(page, 0, -132, "Last 7 days")
  local chart = CreateFrame("Frame", nil, page)
  chart:SetPoint("TOPLEFT", 0, -150)
  chart:SetSize(300, 100)
  o.bars = {}
  for i = 1, 7 do
    local x = (i - 1) * 42
    local bar = chart:CreateTexture(nil, "ARTWORK")
    bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetVertexColor(unpack(ns.ORANGE))
    bar:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, 16)
    bar:SetSize(30, 1)
    local bg = chart:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(1, 1, 1, 0.06)
    bg:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, 16)
    bg:SetSize(30, 66)
    local day = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    day:SetPoint("TOP", bg, "BOTTOM", 0, -2)
    local val = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    o.bars[i] = { bar = bar, day = day, val = val }
  end

  Header(page, 330, -132, "Rank & streak")
  o.rank = Text(page, "GameFontHighlightLarge", 330, -152)
  o.curStreak = Tile(page, 330, -180, "Current streak")
  o.bestStreak = Tile(page, 450, -180, "Longest streak")
  o.weekly = Text(page, "GameFontHighlightSmall", 330, -226)

  o.charHeader = Header(page, 0, -262, "All-time: this character")
  o.cSteps = Tile(page, COL[1], -280, "Steps")
  o.cDist = Tile(page, COL[2], -280, "Distance")
  o.cMoving = Tile(page, COL[3], -280, "Moving time")
  o.cSessions = Tile(page, COL[4], -280, "Activities")

  o.acctHeader = Header(page, 0, -328, "All-time: account")
  o.aSteps = Tile(page, COL[1], -346, "Steps")
  o.aDist = Tile(page, COL[2], -346, "Distance")
  o.aMoving = Tile(page, COL[3], -346, "Moving time")
  o.aSessions = Tile(page, COL[4], -346, "Activities")

  function page:Refresh()
    local s = ns.cdb.current
    local key, label = ns.Status()
    o.sStatus:SetText(label)
    o.sStatus:SetTextColor(unpack(ns.StatusColor(key)))
    if s then
      o.sSteps:SetText(F.Number(s.steps))
      o.sDist:SetText(F.Distance(s.distance))
      o.sMoving:SetText(F.Time(s.moving))
      o.sPace:SetText(F.Pace(s.moving, s.distance))
    else
      for _, v in ipairs({ o.sSteps, o.sDist, o.sMoving, o.sPace }) do v:SetText("-") end
    end

    local days = ns.LastDays(7)
    local today = days[7]
    o.tSteps:SetText(F.Number(today.s))
    o.tDist:SetText(F.Distance(today.d))
    o.wSteps:SetText(F.Number(ns.Challenges.WeekSteps()))
    o.mSteps:SetText(F.Number(ns.Challenges.MonthSteps()))
    local max = 1
    for _, d in ipairs(days) do if d.s > max then max = d.s end end
    for i, d in ipairs(days) do
      local b = o.bars[i]
      b.bar:SetHeight(math.max(1, 66 * d.s / max))
      b.day:SetText(i == 7 and "Today" or date("%a", d.ts))
      if d.s >= 1000 then b.val:SetText(("%.1fk"):format(d.s / 1000))
      elseif d.s >= 1 then b.val:SetText(F.Number(d.s))
      else b.val:SetText("") end
    end

    o.rank:SetText(ns.Achievements.RankColored(ns.Achievements.MyRank()))
    local cur, best = ns.Streaks()
    o.curStreak:SetText(cur .. (cur == 1 and " day" or " days"))
    o.bestStreak:SetText(best .. (best == 1 and " day" or " days"))
    o.weekly:SetText(("Weekly challenges: %d / 3 done"):format(ns.Challenges.WeekChallengesDone()))

    local t = ns.cdb.total
    o.charHeader:SetText(("All-time: %s (since %s)"):format(UnitName("player"), F.Day(ns.cdb.since)))
    o.cSteps:SetText(F.Number(t.steps))
    o.cDist:SetText(F.Distance(t.distance))
    o.cMoving:SetText(F.Time(t.moving))
    o.cSessions:SetText(t.sessions)

    local a = ns.AccountTotals()
    o.acctHeader:SetText(("All-time: account (%d character%s, since %s)"):format(
      a.chars, a.chars == 1 and "" or "s", F.Day(ns.db.since)))
    o.aSteps:SetText(F.Number(a.steps))
    o.aDist:SetText(F.Distance(a.distance))
    o.aMoving:SetText(F.Time(a.moving))
    o.aSessions:SetText(a.sessions)
  end
end

---------------------------------------------------------------------------
-- Activities (session history)
---------------------------------------------------------------------------
local COLS = { { "Date", 0 }, { "Steps", 120 }, { "Distance", 195 }, { "Moving", 280 }, { "Pace", 350 },
               { "Zones", 435 } }
local ROW_W, ROW_H = 570, 20

StaticPopupDialogs["AWS_DELETE_SESSION"] = {
  text = "Delete this activity from your history?\n(All-time totals are not changed.)",
  button1 = YES, button2 = NO,
  OnAccept = function(_, index) ns.DeleteSession(index) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function ShowSessionTooltip(row, s)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(F.Date(s.start) .. (s.auto and "  (auto)" or "  (manual)"), unpack(ns.ORANGE))
  GameTooltip:AddDoubleLine("Steps", F.Number(s.steps), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Distance", F.Distance(s.distance), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Moving time", F.Time(s.moving), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Elapsed time", F.Time(s.elapsed), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Avg pace", F.Pace(s.moving, s.distance), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine("Ended", F.Date(s.finish), 0.7, 0.7, 0.7, 1, 1, 1)
  if s.zones and #s.zones > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Zones: " .. table.concat(s.zones, ", "), 1, 1, 1, true)
  end
  if s.kudos and #s.kudos > 0 then
    local names = {}
    for _, g in ipairs(s.kudos) do table.insert(names, ns.Social.ColoredName(g)) end
    GameTooltip:AddLine("Kudos from: " .. table.concat(names, ", "), 0.99, 0.6, 0.3, true)
  end
  GameTooltip:AddLine(" ")
  if ns.Routes.Has(s) then GameTooltip:AddLine("Map icon: view route", 0.5, 0.5, 0.5) end
  GameTooltip:AddLine("Click: Quick Share   Shift-click: edit in chat box", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function BuildActivities(page)
  for _, c in ipairs(COLS) do
    local h = Text(page, "GameFontNormalSmall", c[2] + 4, 0)
    h:SetText(c[1])
  end

  local _, content = ns.MakeScroll(page, "AWSActivitiesScroll", -16)

  local empty = Text(page, "GameFontDisable", 4, -30)
  empty:SetText("No activities yet. Finish a session to see it here.")

  local rows = {}
  local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = ns.RowBase(content, i, ROW_H, ROW_W)
    r.cells = {}
    for c, col in ipairs(COLS) do
      local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      fs:SetPoint("LEFT", col[2] + 4, 0)
      fs:SetJustifyH("LEFT")
      fs:SetWordWrap(false)
      local nextX = COLS[c + 1] and COLS[c + 1][2] or (ROW_W - 48)
      fs:SetWidth(nextX - col[2] - 6)
      r.cells[c] = fs
    end
    r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
    r.del:SetSize(20, 20)
    r.del:SetPoint("RIGHT", 2, 0)
    r.del:SetScript("OnClick", function()
      StaticPopup_Show("AWS_DELETE_SESSION", nil, nil, r.index)
    end)
    -- Map button: open the route card (only shown when the activity has a route)
    r.route = CreateFrame("Button", nil, r)
    r.route:SetSize(16, 16)
    r.route:SetPoint("RIGHT", r.del, "LEFT", -2, 0)
    r.route:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    r.route:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    r.route:SetScript("OnClick", function() ns.RouteViewer.Open(ns.cdb.history[r.index]) end)
    r.route:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("View route")
      GameTooltip:Show()
    end)
    r.route:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnEnter", function(self) ShowSessionTooltip(self, ns.cdb.history[self.index]) end)
    r:SetScript("OnClick", function(self)
      local a = ns.cdb.history[self.index]
      if IsShiftKeyDown() then ns.Social.ShareToChat(a)
      else ns.QuickShare.Open(self, ns.QuickShare.ActivityText(a)) end
    end)
    rows[i] = r
    return r
  end

  function page:Refresh()
    local hist = ns.cdb.history
    empty:SetShown(#hist == 0)
    for i, s in ipairs(hist) do
      local r = GetRow(i)
      r.index = i
      local k = (s.kudos and #s.kudos > 0) and ("  |cfffc4c02+" .. #s.kudos .. "|r") or ""
      r.cells[1]:SetText(date("%b %d  %H:%M", s.start))
      r.cells[2]:SetText(F.Number(s.steps) .. k)
      r.cells[3]:SetText(F.Distance(s.distance))
      r.cells[4]:SetText(F.Time(s.moving))
      r.cells[5]:SetText(F.Pace(s.moving, s.distance))
      r.cells[6]:SetText(s.zones and table.concat(s.zones, ", ") or "")
      r.route:SetShown(ns.Routes.Has(s))
      r:Show()
    end
    for i = #hist + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #hist * ROW_H))
  end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
StaticPopupDialogs["AWS_RESET_CHAR"] = {
  text = "Reset ALL Azeroth Walking Simulator data for this character?\n" ..
    "(Totals, history, challenges and achievements. This cannot be undone.)",
  button1 = YES, button2 = NO,
  OnAccept = function() ns.ResetCharacter() end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

local function BuildSettings(page)
  local y = 0
  local checks = {}

  local function Check(label, key, onChange, x)
    local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x or 0, y)
    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
      onChange(self:GetChecked() and true or false)
    end)
    checks[key] = cb
    return cb
  end

  -- "-  value  +" stepper
  local function Stepper(label, getText, onMinus, onPlus)
    local l = Text(page, "GameFontHighlight", 4, y - 4)
    l:SetText(label)
    local minus = ns.SmallButton(page, "-", 24, onMinus)
    minus:SetPoint("TOPLEFT", 190, y)
    local val = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    val:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    val:SetWidth(150)
    val:SetJustifyH("CENTER")
    local plus = ns.SmallButton(page, "+", 24, onPlus)
    plus:SetPoint("LEFT", val, "RIGHT", 6, 0)
    y = y - 26
    return function() val:SetText(getText()) end
  end

  local s = ns.settings
  Header(page, 0, y, "Tracking")
  y = y - 18
  Check("Auto mode: start a session on login, end it on logout", "autoMode", function(on) ns.SetAutoMode(on) end)
  y = y - 24
  Check("Show mini tracker", "trackerShown", function(on) s.trackerShown = on; ns.ApplyTrackerSettings() end)
  Check("Lock mini tracker", "trackerLocked", function(on) s.trackerLocked = on end, 300)
  y = y - 24
  Check("Banners and toasts", "banners", function(on) s.banners = on end)
  Check("Sounds", "sounds", function(on) s.sounds = on end, 300)
  y = y - 30

  Header(page, 0, y, "Social")
  y = y - 18
  Check("Share my stats and activities with guild and friends", "shareEnabled", function(on)
    s.shareEnabled = on
    if on then ns.Social.BroadcastStats(true) end
  end)
  y = y - 24
  Check("Join the Everyone leaderboard (all players with the addon)", "globalBoard", function(on)
    ns.Social.SetGlobalBoard(on)
  end)
  y = y - 24
  Check("Chat message when a friend finishes something", "socialChat", function(on) s.socialChat = on end)
  y = y - 30

  Header(page, 0, y, "Display")
  y = y - 20
  local updaters = {}
  local function Round(v) return math.floor(v * 100 + 0.5) / 100 end
  table.insert(updaters, Stepper("Distance units",
    function() return s.units == "mi" and "Miles" or "Kilometers" end,
    function() s.units = (s.units == "mi") and "km" or "mi"; page:Refresh(); ns.RefreshUI() end,
    function() s.units = (s.units == "mi") and "km" or "mi"; page:Refresh(); ns.RefreshUI() end))
  table.insert(updaters, Stepper("Tracker size",
    function() return ("%d%%"):format(s.trackerScale * 100 + 0.5) end,
    function() s.trackerScale = math.max(0.6, Round(s.trackerScale - 0.1)); ns.ApplyTrackerSettings(); page:Refresh() end,
    function() s.trackerScale = math.min(2.0, Round(s.trackerScale + 0.1)); ns.ApplyTrackerSettings(); page:Refresh() end))

  y = y - 6
  local resetPos = ns.SmallButton(page, "Reset tracker position", 180, function()
    s.trackerPoint = nil
    ns.ApplyTrackerSettings()
  end)
  resetPos:SetPoint("TOPLEFT", 0, y)
  local test = ns.SmallButton(page, "Test banner", 120, function() ns.Banner.Test() end)
  test:SetPoint("LEFT", resetPos, "RIGHT", 8, 0)
  local resetChar = ns.SmallButton(page, "Reset character data", 180, function()
    StaticPopup_Show("AWS_RESET_CHAR")
  end)
  resetChar:SetPoint("LEFT", test, "RIGHT", 8, 0)
  y = y - 32

  local help = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", 0, y)
  help:SetWidth(WIDTH - 50)
  help:SetJustifyH("LEFT")
  help:SetText("Steps only count while you hold movement keys (or both mouse buttons) and really move: " ..
    "not auto-run, walls, mounted, flight paths, vehicles, swimming, dead or /follow. " ..
    "Step length is the same for everyone (1.4 yd walking, 2.0 yd running) so all leaderboards are fair.\n" ..
    "Commands: /aws, /aws start | pause | resume | stop, /aws auto on|off, /aws tracker, /aws stats, " ..
    "/aws challenges, /aws trophies, /aws social, /aws share, /aws route, /aws testbanner. " ..
    "Right-click the tracker to open.")

  function page:Refresh()
    for key, cb in pairs(checks) do cb:SetChecked(s[key]) end
    for _, u in ipairs(updaters) do u() end
  end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local BUILDERS = {
  BuildOverview,
  BuildActivities,
  function(page) ns.BuildChallengesPage(page) end,
  function(page) ns.BuildTrophiesPage(page) end,
  function(page) ns.BuildSocialPage(page) end,
  BuildSettings,
}

local function CreateWindow()
  local f = ns.CreatePanel("AWSWindow")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()
  tinsert(UISpecialFrames, "AWSWindow") -- close with Escape

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText("AZEROTH WALKING SIMULATOR")
  title:SetTextColor(unpack(ns.ORANGE))
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
  f.sub = sub

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  local quick
  quick = ns.SmallButton(f, "Quick Share", 100, function() ns.QuickShare.Open(quick) end)
  quick:SetPoint("RIGHT", close, "LEFT", -4, 0)

  f.pages, f.tabs = {}, {}
  for i, name in ipairs(TABS) do
    local tab = ns.SmallButton(f, name, 98, function() f:SelectTab(i) end)
    tab:SetSize(98, 22)
    tab:SetPoint("TOPLEFT", 14 + (i - 1) * 102, -40)
    f.tabs[i] = tab

    local page = CreateFrame("Frame", nil, f)
    page:SetPoint("TOPLEFT", 20, -76)
    page:SetPoint("BOTTOMRIGHT", -16, 14)
    page:Hide()
    BUILDERS[i](page)
    f.pages[i] = page
  end

  function f:SelectTab(i)
    self.current = i
    for j, page in ipairs(self.pages) do
      page:SetShown(j == i)
      self.tabs[j]:SetEnabled(j ~= i)
    end
    self:RefreshPage()
  end

  function f:RefreshPage()
    self.sub:SetText(UnitName("player") .. "  -  " .. ns.Achievements.RankColored(ns.Achievements.MyRank()))
    if self.current then self.pages[self.current]:Refresh() end
  end

  -- Called every second while open, for the pages with live numbers
  local LIVE = { [1] = true, [ns.CHALLENGES_TAB] = true, [ns.SOCIAL_TAB] = true }
  function f:RefreshLive()
    if LIVE[self.current] then self:RefreshPage() end
  end

  f:SetScript("OnShow", function(self) self:RefreshPage() end)
  f.current = 1
  ns.Window = f
end

function ns.ToggleWindow(tab)
  if not ns.cdb then return end
  if not ns.Window then CreateWindow() end
  local f = ns.Window
  if f:IsShown() and not tab then
    f:Hide()
  else
    f:Show()
    f:SelectTab(tab or f.current or 1)
  end
end
