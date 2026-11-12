local _, ns = ...
local L = ns.L
local F = ns.F

local WIDTH, HEIGHT = 640, 610
local TABS = { "Home", "Activities", "Challenges", "Trophies", "Leaderboard" }
ns.CHALLENGES_TAB, ns.TROPHIES_TAB, ns.SOCIAL_TAB, ns.SETTINGS_TAB = 3, 4, 5, 6

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
ns.StatTile = Tile

local function Text(parent, font, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  return fs
end

local WHITE = "Interface\\Buttons\\WHITE8X8"

---------------------------------------------------------------------------
-- Home: today in big, the week, weekly challenges, then the feed
---------------------------------------------------------------------------
local function BuildHome(page)
  local o = {}

  -- Hero: today's steps
  o.today = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  o.today:SetFont(STANDARD_TEXT_FONT, 34, "OUTLINE")
  o.today:SetPoint("TOPLEFT", 0, -2)
  o.todayLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  o.todayLabel:SetPoint("TOPLEFT", o.today, "BOTTOMLEFT", 2, -4)
  o.todayLabel:SetTextColor(0.65, 0.65, 0.65)

  o.week = Tile(page, 330, -4, L["This week"])
  o.streak = Tile(page, 460, -4, L["Streak"])

  -- The walk in progress, on one line
  o.sessDot = page:CreateTexture(nil, "OVERLAY")
  o.sessDot:SetTexture(WHITE)
  o.sessDot:SetSize(7, 7)
  o.sessDot:SetPoint("TOPLEFT", 2, -67)
  o.session = Text(page, "GameFontHighlightSmall", 14, -64)
  o.share = ns.SmallButton(page, L["Share"], 64, function() ns.QuickShare.Open(o.share) end)
  o.share:SetPoint("TOPRIGHT", -24, -60)

  -- 7-day chart
  Header(page, 0, -88, L["Last 7 days"])
  local chart = CreateFrame("Frame", nil, page)
  chart:SetPoint("TOPLEFT", 0, -106)
  chart:SetSize(580, 96)
  local CH = 64
  o.bars = {}
  for i = 1, 7 do
    local x = (i - 1) * 84 + 8
    local bg = chart:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetVertexColor(1, 1, 1, 0.025)
    bg:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", x, 16)
    bg:SetSize(52, CH)
    local bar = chart:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(WHITE)
    bar:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
    bar:SetSize(52, 1)
    local day = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    day:SetPoint("TOP", bg, "BOTTOM", 0, -3)
    local val = chart:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    o.bars[i] = { bar = bar, day = day, val = val }
  end

  -- Weekly challenges strip: click it to open the Challenges tab
  local strip = CreateFrame("Button", nil, page)
  strip:SetPoint("TOPLEFT", 0, -210)
  strip:SetSize(580, 34)
  local sbg = strip:CreateTexture(nil, "BACKGROUND")
  sbg:SetAllPoints()
  sbg:SetTexture(WHITE)
  sbg:SetVertexColor(1, 1, 1, 0.04)
  local shl = strip:CreateTexture(nil, "HIGHLIGHT")
  shl:SetAllPoints()
  shl:SetTexture(WHITE)
  shl:SetVertexColor(1, 1, 1, 0.05)
  o.medals = {}
  for i = 1, 3 do
    local m = strip:CreateTexture(nil, "ARTWORK")
    m:SetSize(24, 24)
    m:SetPoint("LEFT", 8 + (i - 1) * 28, 0)
    m:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    o.medals[i] = m
  end
  o.weeklyText = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  o.weeklyText:SetPoint("LEFT", 100, 0)
  o.champText = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  o.champText:SetPoint("RIGHT", -12, 0)
  strip:SetScript("OnClick", function() ns.Window:SelectTab(ns.CHALLENGES_TAB) end)

  -- Feed
  Header(page, 0, -258, L["Feed"])
  local feed = CreateFrame("Frame", nil, page)
  feed:SetPoint("TOPLEFT", 0, -276)
  feed:SetPoint("BOTTOMRIGHT")
  ns.BuildFeed(feed)
  local feedEmpty = Text(page, "GameFontDisable", 4, -286)
  feedEmpty:SetWidth(570)
  feedEmpty:SetText(L["Nothing here yet. Activities, challenges and achievements from you and your friends show up here."])

  -- The feed and challenge progress are the heavy parts: on the 1 s live
  -- refresh they update every 5 s; switching to the tab updates them at once.
  local heavyAt = 0
  function page:Refresh(live)
    local now = GetTime()
    local heavy = not live or now - heavyAt >= 5
    if heavy then heavyAt = now end

    local days = ns.LastDays(7)
    local today = days[7]
    o.today:SetText(F.Number(today.s))
    o.todayLabel:SetText(L["steps today"] .. "   |cffffffff" .. F.Distance(today.d) .. "|r")
    o.week:SetText(F.Number(ns.Challenges.WeekSteps()))
    local cur = ns.Streaks()
    o.streak:SetText(cur .. (cur == 1 and L[" day"] or L[" days"]))

    local s = ns.cdb.current
    if s then
      local key, label = ns.Status()
      o.sessDot:SetVertexColor(unpack(ns.StatusColor(key)))
      o.sessDot:Show()
      o.share:Show()
      o.session:SetText(("%s     |cffaaaaaa%s:|r  %s%s   |   %s   |   %s   |   %s"):format(label, L["This session"],
        F.Number(s.steps), L[" steps"], F.Distance(s.distance), F.Time(s.moving), F.Pace(s.moving, s.distance)))
    else
      o.sessDot:Hide()
      o.share:Hide()
      o.session:SetText("")
    end

    local max = 1
    for _, d in ipairs(days) do if d.s > max then max = d.s end end
    for i, d in ipairs(days) do
      local b = o.bars[i]
      b.bar:SetHeight(math.max(1, CH * d.s / max))
      if i == 7 then b.bar:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 1)
      else b.bar:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.55) end
      b.bar:SetShown(d.s >= 1)
      b.day:SetText(i == 7 and L["Today"] or date("%a", d.ts))
      if d.s >= 1000 then b.val:SetText(("%.1fk"):format(d.s / 1000))
      elseif d.s >= 1 then b.val:SetText(F.Number(d.s))
      else b.val:SetText("") end
    end

    if not heavy then return end

    local list, week = ns.Challenges.Active()
    for i = 1, 3 do
      local e = list[i]
      local isWeekly = e and e.period.key == week.key
      o.medals[i]:SetShown(isWeekly)
      if isWeekly then
        o.medals[i]:SetTexture(ns.Challenges.TIERS[e.ch.tier].icon)
        o.medals[i]:SetDesaturated(not e.done)
        o.medals[i]:SetAlpha(e.done and 1 or 0.45)
      end
    end
    o.weeklyText:SetText(("%s   |cffffd100%d / 3|r"):format(L["Weekly challenges"],
      ns.Challenges.WeekChallengesDone(week.key)))
    o.champText:SetText((ns.Challenges.ChampionText(week.key)))

    feedEmpty:SetShown(feed:Refresh() == 0)
  end
end

---------------------------------------------------------------------------
-- Activities (session history), one card per walk
---------------------------------------------------------------------------
local ROW_W, ROW_H = 570, 44

StaticPopupDialogs["AWS_DELETE_SESSION"] = {
  text = "Delete this activity from your history?\n(All-time totals are not changed.)",
  button1 = YES, button2 = NO,
  OnAccept = function(_, activity) ns.DeleteSession(activity) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- "Afternoon walk in The Barrens", the way Strava names your runs
function ns.ActivityTitle(s)
  local h = tonumber(date("%H", s.start or time())) or 12
  local part
  if h >= 5 and h < 12 then part = L["Morning walk"]
  elseif h >= 12 and h < 17 then part = L["Afternoon walk"]
  elseif h >= 17 and h < 22 then part = L["Evening walk"]
  else part = L["Night walk"] end
  local zone = s.zones and s.zones[1]
  return zone and (L["%s in %s"]):format(part, zone) or part
end

local function ShowSessionTooltip(row, s)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.ActivityTitle(s), unpack(ns.ORANGE))
  GameTooltip:AddLine(F.Date(s.start) .. (s.auto and L["  (auto)"] or L["  (manual)"]), 0.7, 0.7, 0.7)
  GameTooltip:AddDoubleLine(L["Steps"], F.Number(s.steps), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Distance"], F.Distance(s.distance), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Moving time"], F.Time(s.moving), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Elapsed time"], F.Time(s.elapsed), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Avg pace"], F.Pace(s.moving, s.distance), 0.7, 0.7, 0.7, 1, 1, 1)
  GameTooltip:AddDoubleLine(L["Ended"], F.Date(s.finish), 0.7, 0.7, 0.7, 1, 1, 1)
  if s.zones and #s.zones > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Zones: "] .. table.concat(s.zones, ", "), 1, 1, 1, true)
  end
  if s.kudos and #s.kudos > 0 then
    local names = {}
    for _, g in ipairs(s.kudos) do table.insert(names, ns.Social.ColoredName(g)) end
    GameTooltip:AddLine(L["Kudos from: "] .. table.concat(names, ", "), 0.99, 0.6, 0.3, true)
  end
  GameTooltip:AddLine(" ")
  if ns.Routes.Has(s) then
    GameTooltip:AddLine(L["Click: view route   Right-click: more"], 0.5, 0.5, 0.5)
  else
    GameTooltip:AddLine(L["Click: Quick Share   Right-click: more"], 0.5, 0.5, 0.5)
  end
  GameTooltip:AddLine(L["Shift-click: edit in chat box"], 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function ActivityMenu(owner, a)
  local actions = {}
  if ns.Routes.Has(a) then
    table.insert(actions, { L["View route"], function() ns.RouteViewer.Open(a) end })
  end
  table.insert(actions, { L["Quick Share"], function() ns.QuickShare.Open(owner, ns.QuickShare.ActivityText(a)) end })
  table.insert(actions, { L["Edit in chat box"], function() ns.Social.ShareToChat(a) end })
  table.insert(actions, { L["Delete"], function()
    StaticPopupDialogs["AWS_DELETE_SESSION"].text =
      L["Delete this activity from your history?\n(All-time totals are not changed.)"]
    StaticPopup_Show("AWS_DELETE_SESSION", nil, nil, a) -- the activity itself, not its place
  end })
  ns.ContextMenu(owner, ns.ActivityTitle(a), actions)
end

local function BuildActivities(page)
  local _, content = ns.MakeScroll(page, "AWSActivitiesScroll", 0)

  local empty = Text(page, "GameFontDisable", 4, -10)
  empty:SetText(L["No activities yet. Finish a session to see it here."])

  local rows = {}
  local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = ns.RowBase(content, i, ROW_H, ROW_W)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(30, 30)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.title = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.title:SetPoint("TOPLEFT", 46, -6)
    r.title:SetWidth(390)
    r.title:SetJustifyH("LEFT")
    r.title:SetWordWrap(false)
    r.stats = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.stats:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
    r.stats:SetTextColor(0.7, 0.7, 0.7)
    r.when = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.when:SetPoint("TOPRIGHT", -8, -7)
    r.kudos = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.kudos:SetPoint("BOTTOMRIGHT", -8, 8)
    r.kudos:SetTextColor(unpack(ns.ORANGE))
    r:SetScript("OnEnter", function(self) ShowSessionTooltip(self, ns.cdb.history[self.index]) end)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      local a = ns.cdb.history[self.index]
      if not a then return end
      if button == "RightButton" then ActivityMenu(self, a)
      elseif IsShiftKeyDown() then ns.Social.ShareToChat(a)
      elseif ns.Routes.Has(a) then ns.RouteViewer.Open(a)
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
      r.icon:SetTexture(ns.Routes.Has(s) and "Interface\\Icons\\INV_Misc_Map_01" or "Interface\\Icons\\Ability_Rogue_Sprint")
      r.title:SetText(ns.ActivityTitle(s))
      r.stats:SetText(("%s%s     %s     %s     %s"):format(F.Number(s.steps), L[" steps"],
        F.Distance(s.distance), F.Time(s.moving), F.Pace(s.moving, s.distance)))
      r.when:SetText(date("%b %d  %H:%M", s.start))
      local n = s.kudos and #s.kudos or 0
      r.kudos:SetText(n > 0 and (n .. L[" kudos"]) or "")
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
  Header(page, 0, y, L["Tracking"])
  y = y - 18
  Check(L["Auto mode: start a session on login, end it on logout"], "autoMode", function(on) ns.SetAutoMode(on) end)
  y = y - 24
  Check(L["Show mini tracker"], "trackerShown", function(on) s.trackerShown = on; ns.ApplyTrackerSettings() end)
  Check(L["Lock mini tracker"], "trackerLocked", function(on) s.trackerLocked = on end, 300)
  y = y - 24
  Check(L["Banners and toasts"], "banners", function(on) s.banners = on end)
  Check(L["Sounds"], "sounds", function(on) s.sounds = on end, 300)
  y = y - 24
  Check(L["Show minimap button"], "minimapShown", function(on) s.minimapShown = on; ns.MinimapButton.Apply() end)
  y = y - 30

  Header(page, 0, y, L["Social"])
  y = y - 18
  Check(L["Share my stats and activities with guild and friends"], "shareEnabled", function(on)
    s.shareEnabled = on
    if on then ns.Social.BroadcastStats(true) end
  end)
  y = y - 24
  Check(L["Join the Everyone leaderboard (all players with the addon)"], "globalBoard", function(on)
    ns.Social.SetGlobalBoard(on)
  end)
  y = y - 24
  Check(L["Chat message when a friend finishes something"], "socialChat", function(on) s.socialChat = on end)
  y = y - 30

  Header(page, 0, y, L["Display"])
  y = y - 20
  local updaters = {}
  local function Round(v) return math.floor(v * 100 + 0.5) / 100 end
  table.insert(updaters, Stepper(L["Distance units"],
    function() return s.units == "mi" and L["Miles"] or L["Kilometers"] end,
    function() s.units = (s.units == "mi") and "km" or "mi"; page:Refresh(); ns.RefreshUI() end,
    function() s.units = (s.units == "mi") and "km" or "mi"; page:Refresh(); ns.RefreshUI() end))
  table.insert(updaters, Stepper(L["Tracker size"],
    function() return ("%d%%"):format(s.trackerScale * 100 + 0.5) end,
    function() s.trackerScale = math.max(0.6, Round(s.trackerScale - 0.1)); ns.ApplyTrackerSettings(); page:Refresh() end,
    function() s.trackerScale = math.min(2.0, Round(s.trackerScale + 0.1)); ns.ApplyTrackerSettings(); page:Refresh() end))

  y = y - 6
  local resetPos = ns.SmallButton(page, L["Reset tracker position"], 180, function()
    s.trackerPoint = nil
    ns.ApplyTrackerSettings()
  end)
  resetPos:SetPoint("TOPLEFT", 0, y)
  local test = ns.SmallButton(page, L["Test banner"], 120, function() ns.Banner.Test() end)
  test:SetPoint("LEFT", resetPos, "RIGHT", 8, 0)
  local resetChar = ns.SmallButton(page, L["Reset character data"], 180, function()
    StaticPopupDialogs["AWS_RESET_CHAR"].text = L["Reset ALL Azeroth Walking Simulator data for this character?\n" ..
      "(Totals, history, challenges and achievements. This cannot be undone.)"]
    StaticPopup_Show("AWS_RESET_CHAR")
  end)
  resetChar:SetPoint("LEFT", test, "RIGHT", 8, 0)
  y = y - 32

  local help = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", 0, y)
  help:SetWidth(WIDTH - 50)
  help:SetJustifyH("LEFT")
  help:SetText(L["Steps only count while you hold movement keys (or both mouse buttons) and really move: not auto-run, walls, mounted, flight paths, vehicles, swimming, dead or /follow. Step length is the same for everyone (1.4 yd walking, 2.0 yd running) so all leaderboards are fair."] ..
    "\n" .. L["Commands"] .. ": /aws, /aws start | pause | resume | stop, /aws auto on|off, /aws tracker, " ..
    "/aws stats, /aws challenges, /aws trophies, /aws social, /aws share, /aws route, /aws options, " ..
    "/aws minimap. " .. L["Right-click the tracker to open."])

  function page:Refresh()
    for key, cb in pairs(checks) do cb:SetChecked(s[key]) end
    for _, u in ipairs(updaters) do u() end
  end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
-- The same settings page is used in the game's Options panel (UI/Options.lua)
ns.BuildSettingsPage = BuildSettings

local BUILDERS = {
  BuildHome,
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

  -- Settings is a gear next to the close button, not a tab
  local gear = CreateFrame("Button", nil, f)
  gear:SetSize(20, 20)
  gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
  gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
  gear:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93)
  gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  gear:SetScript("OnClick", function() f:SelectTab(ns.SETTINGS_TAB) end)
  gear:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Settings"])
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function() GameTooltip:Hide() end)
  gear.line = gear:CreateTexture(nil, "OVERLAY")
  gear.line:SetTexture(WHITE)
  gear.line:SetVertexColor(unpack(ns.ORANGE))
  gear.line:SetPoint("TOPLEFT", gear, "BOTTOMLEFT", 0, -2)
  gear.line:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 0, -2)
  gear.line:SetHeight(2)
  function gear:SetSelected(on) self.line:SetShown(on) end

  local divider = f:CreateTexture(nil, "ARTWORK")
  divider:SetTexture(WHITE)
  divider:SetVertexColor(1, 1, 1, 0.12)
  divider:SetPoint("TOPLEFT", 14, -64)
  divider:SetPoint("TOPRIGHT", -14, -64)
  divider:SetHeight(1)

  f.pages, f.tabs = {}, {}
  for i = 1, #BUILDERS do
    local tab
    if TABS[i] then
      tab = ns.TabButton(f, L[TABS[i]], function() f:SelectTab(i) end)
      if i == 1 then tab:SetPoint("BOTTOMLEFT", divider, "TOPLEFT", 0, 0)
      else tab:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 4, 0) end
    else
      tab = gear
    end
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
      self.tabs[j]:SetSelected(j == i)
    end
    self:RefreshPage()
  end

  -- live = a timed refresh (pages may skip their slow parts)
  function f:RefreshPage(live)
    self.sub:SetText(UnitName("player") .. "  -  " .. ns.Achievements.RankColored(ns.Achievements.MyRank()))
    if self.current then self.pages[self.current]:Refresh(live) end
  end

  -- Called every second while open, for the pages with live numbers
  local LIVE = { [1] = true, [ns.CHALLENGES_TAB] = true, [ns.SOCIAL_TAB] = true }
  function f:RefreshLive()
    if LIVE[self.current] then self:RefreshPage(true) end
  end

  f:SetScript("OnShow", function(self) self:RefreshPage() end)
  f.current = 1
  ns.Window = f
end

-- Open what a banner or toast is about. open = { tab = n, ach | ch | tier |
-- rank | champion } or { profile = guid }. The page highlights the item.
function ns.ShowUnlocked(open)
  if not open or not ns.cdb then return end
  if open.profile then
    if ns.ShowProfile then ns.ShowProfile(open.profile) end
    return
  end
  if not open.tab then return end
  ns.ToggleWindow(open.tab)
  local page = ns.Window and ns.Window.pages[open.tab]
  -- next frame, once the page has laid itself out (scroll ranges)
  if page and page.Highlight then C_Timer.After(0, function() page:Highlight(open) end) end
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
