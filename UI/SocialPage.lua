local _, ns = ...
local F = ns.F

local CONTENT_W = 570
local GRAY = { 0.7, 0.7, 0.7 }

local function AddLine(label, value)
  GameTooltip:AddDoubleLine(label, value, GRAY[1], GRAY[2], GRAY[3], 1, 1, 1)
end

function ns.MakeScroll(parent, name, top)
  local sf = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 0, top)
  sf:SetPoint("BOTTOMRIGHT", -24, 0)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(CONTENT_W, 1)
  sf:SetScrollChild(content)
  return sf, content
end

function ns.RowBase(content, i, height, width)
  local r = CreateFrame("Button", nil, content)
  r:SetSize(width or CONTENT_W, height)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * height)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(1, 1, 1, 0.08)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return r
end

local function Cell(r, font, x, width)
  local fs = r:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint("LEFT", x, 0)
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------
local PERIODS = { { "today", "Today" }, { "week", "Week" }, { "month", "Month" }, { "all", "All-time" } }
local BOARD_COLS = { { "#", 14, 22 }, { "Name", 38, 140 }, { "Rank", 182, 150 }, { "Steps", 336, 85 },
                     { "Trophies", 425, 60 }, { "Streak", 490, 60 } }

local function BoardTooltip(row, d)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.Social.ColoredName(d.guid) .. (d.me and "  (you)" or ""))
  GameTooltip:AddLine(ns.Achievements.RankColored(d.rank))
  if d.active then
    GameTooltip:AddLine(("Walking now: %s steps this session"):format(F.Number(d.sessionSteps or 0)), 0.2, 0.9, 0.3)
  elseif d.online then
    GameTooltip:AddLine("Online", 0.9, 0.8, 0.2)
  elseif d.e and d.e.updated then
    GameTooltip:AddLine("Last seen " .. F.Date(d.e.updated), 0.6, 0.6, 0.6)
  end
  AddLine("Today", F.Number(d.today) .. " steps")
  AddLine("This week", F.Number(d.week) .. " steps")
  AddLine("This month", F.Number(d.month) .. " steps")
  AddLine("All-time", F.Number(d.all) .. " steps")
  AddLine("Weekly challenges", (d.weekDone or 0) .. " / 3")
  AddLine("Trophies", d.trophies or 0)
  AddLine("Streak", (d.streak or 0) .. " days")
  if d.e and d.e.since and d.e.since > 0 then AddLine("Walking since", F.Day(d.e.since)) end
  GameTooltip:Show()
end

local function BuildBoard(box)
  for _, c in ipairs(BOARD_COLS) do
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", c[2], 0)
    h:SetText(c[1])
  end
  local _, content = ns.MakeScroll(box, "AWSBoardScroll", -16)
  local rows = {}

  local MEDALS = { { 1, 0.82, 0 }, { 0.78, 0.78, 0.85 }, { 0.8, 0.5, 0.2 } }

  local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = ns.RowBase(content, i, 22)
    r.dot = r:CreateTexture(nil, "OVERLAY")
    r.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    r.dot:SetSize(7, 7)
    r.dot:SetPoint("LEFT", 4, 0)
    r.cells = {}
    for c, col in ipairs(BOARD_COLS) do r.cells[c] = Cell(r, "GameFontHighlightSmall", col[2], col[3]) end
    r:SetScript("OnEnter", function(self) BoardTooltip(self, self.data) end)
    rows[i] = r
    return r
  end

  function box:Refresh(period, category)
    local list = ns.Social.Leaderboard(period, category)
    for i, d in ipairs(list) do
      local r = GetRow(i)
      r.data = d
      if d.active then r.dot:SetVertexColor(0.2, 0.9, 0.3)
      elseif d.online then r.dot:SetVertexColor(0.9, 0.8, 0.2)
      else r.dot:SetVertexColor(0.35, 0.35, 0.35) end
      local medal = MEDALS[i]
      r.cells[1]:SetText(i)
      if medal and d.value > 0 then r.cells[1]:SetTextColor(unpack(medal)) else r.cells[1]:SetTextColor(1, 1, 1) end
      r.cells[2]:SetText(ns.Social.ColoredName(d.guid) .. (d.me and " |cff888888(you)|r" or ""))
      r.cells[3]:SetText(ns.Achievements.RankColored(d.rank))
      r.cells[4]:SetText(F.Number(d.value))
      r.cells[5]:SetText(d.trophies or 0)
      r.cells[6]:SetText((d.streak or 0) .. "d")
      if d.me then r.bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.12)
      else r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0) end
      r:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #list * 22))
  end
end

---------------------------------------------------------------------------
-- Feed
---------------------------------------------------------------------------
local function FeedTooltip(row, it)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.Social.ColoredName(it.from) .. "  " .. F.Date(it.finish))
  if it.event then
    GameTooltip:AddLine(it.text, 1, 1, 1, true)
    GameTooltip:Show()
    return
  end
  AddLine("Steps", F.Number(it.steps))
  AddLine("Distance", F.Distance(it.distance))
  AddLine("Moving time", F.Time(it.moving))
  AddLine("Elapsed time", F.Time(it.elapsed))
  AddLine("Avg pace", F.Pace(it.moving, it.distance))
  if it.zones and #it.zones > 0 then
    GameTooltip:AddLine("Zones: " .. table.concat(it.zones, ", "), 1, 1, 1, true)
  end
  if it.mine and it.kudosList and #it.kudosList > 0 then
    local names = {}
    for _, g in ipairs(it.kudosList) do table.insert(names, ns.Social.ColoredName(g)) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Kudos from: " .. table.concat(names, ", "), 0.99, 0.6, 0.3, true)
  end
  GameTooltip:Show()
end

local function BuildFeed(box)
  local _, content = ns.MakeScroll(box, "AWSFeedScroll", 0)
  local rows = {}

  local function GetRow(i)
    if rows[i] then return rows[i] end
    local r = ns.RowBase(content, i, 40)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.top = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.top:SetPoint("TOPLEFT", 42, -4)
    r.top:SetWidth(420)
    r.top:SetJustifyH("LEFT")
    r.top:SetWordWrap(false)
    r.bottom = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.bottom:SetPoint("TOPLEFT", r.top, "BOTTOMLEFT", 0, -3)
    r.bottom:SetWidth(420)
    r.bottom:SetJustifyH("LEFT")
    r.bottom:SetWordWrap(false)

    r.btn = ns.SmallButton(r, "Kudos", 72, function()
      local it = r.item
      if it.mine then ns.QuickShare.Open(r.btn, ns.QuickShare.ActivityText(it.src))
      else ns.Social.GiveKudos(it) end
    end)
    r.btn:SetPoint("RIGHT", -4, 0)
    r.kudos = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.kudos:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
    r.kudos:SetTextColor(unpack(ns.ORANGE))

    r:SetScript("OnEnter", function(self) FeedTooltip(self, self.item) end)
    rows[i] = r
    return r
  end

  function box:Refresh()
    local items = ns.Social.Feed()
    for i, it in ipairs(items) do
      local r = GetRow(i)
      r.item = it
      local when = date("%b %d %H:%M", it.finish or 0)
      if it.event then
        r.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_Coin_01")
        r.top:SetText(("%s  |cff888888%s|r"):format(ns.Social.ColoredName(it.from), when))
        r.bottom:SetText(it.text)
        r.bg:SetVertexColor(1, 0.82, 0, 0.08)
        r.btn:Hide()
        r.kudos:SetText("")
      else
        r.icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
        local zone = it.zones and it.zones[1]
        r.top:SetText(("%s  |cff888888%s%s|r"):format(ns.Social.ColoredName(it.from), when,
          zone and ("  -  " .. zone) or ""))
        r.bottom:SetText(("|cffccccccsteps|r %s   |cffcccccc%s   %s   %s|r"):format(F.Number(it.steps),
          F.Distance(it.distance), F.Time(it.moving), F.Pace(it.moving, it.distance)))
        r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        r.btn:Show()
        if it.mine then
          r.btn:SetText("Share")
          r.btn:SetEnabled(true)
          local n = it.kudosList and #it.kudosList or 0
          r.kudos:SetText(n > 0 and (n .. " kudos") or "")
        else
          r.btn:SetText(it.kudos and "Sent" or "Kudos")
          r.btn:SetEnabled(not it.kudos)
          r.kudos:SetText("")
        end
      end
      r:Show()
    end
    for i = #items + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #items * 40))
    return #items
  end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local CATEGORIES = { { "friends", "Friends" }, { "guild", "Guild" }, { "everyone", "Everyone" } }
local CATEGORY_EMPTY = {
  friends = "None of your friends use Azeroth Walking Simulator yet (or they haven't been online with you).\n" ..
    "Friends list and Battle.net friends playing WoW Forever show up here.",
  guild = "No guildies with Azeroth Walking Simulator yet. Tell your guild to install it!",
  everyone = "No other walkers seen yet. Everyone with the addon (and the Everyone leaderboard turned on in " ..
    "Settings) shows up here once you've both been online.",
}

function ns.BuildSocialPage(page)
  local board = CreateFrame("Frame", nil, page)
  board:SetPoint("TOPLEFT", 0, -60)
  board:SetPoint("BOTTOMRIGHT")
  BuildBoard(board)

  local feed = CreateFrame("Frame", nil, page)
  feed:SetPoint("TOPLEFT", 0, -32)
  feed:SetPoint("BOTTOMRIGHT")
  BuildFeed(feed)

  local info = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  info:SetPoint("TOPLEFT", 214, -6)

  local empty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  empty:SetPoint("TOPLEFT", 4, -118)
  empty:SetWidth(CONTENT_W)
  empty:SetJustifyH("LEFT")

  page.mode, page.period, page.category = "board", "week", "friends"
  local boardBtn = ns.SmallButton(page, "Leaderboard", 100, function() page.mode = "board"; page:Refresh() end)
  boardBtn:SetPoint("TOPLEFT", 0, 0)
  local feedBtn = ns.SmallButton(page, "Feed", 100, function() page.mode = "feed"; page:Refresh() end)
  feedBtn:SetPoint("LEFT", boardBtn, "RIGHT", 4, 0)

  -- Second row: which leaderboard (left) and which period (right)
  local catBtns = {}
  for i, c in ipairs(CATEGORIES) do
    local key = c[1]
    local b = ns.SmallButton(page, c[2], 84, function() page.category = key; page:Refresh() end)
    if i == 1 then b:SetPoint("TOPLEFT", 0, -28)
    else b:SetPoint("LEFT", catBtns[i - 1], "RIGHT", 2, 0) end
    b.key, b.label = key, c[2]
    catBtns[i] = b
  end

  local periodBtns = {}
  for i = #PERIODS, 1, -1 do
    local key, label = PERIODS[i][1], PERIODS[i][2]
    local b = ns.SmallButton(page, label, 68, function() page.period = key; page:Refresh() end)
    if i == #PERIODS then b:SetPoint("TOPRIGHT", -24, -28)
    else b:SetPoint("RIGHT", periodBtns[i + 1], "LEFT", -2, 0) end
    b.key = key
    periodBtns[i] = b
  end

  function page:Refresh()
    local isBoard = self.mode == "board"
    board:SetShown(isBoard)
    feed:SetShown(not isBoard)
    boardBtn:SetEnabled(not isBoard)
    feedBtn:SetEnabled(isBoard)
    for _, b in ipairs(periodBtns) do
      b:SetShown(isBoard)
      b:SetEnabled(b.key ~= self.period)
    end
    for _, b in ipairs(catBtns) do
      b:SetShown(isBoard)
      b:SetEnabled(b.key ~= self.category)
      local n = ns.Social.FriendCount(b.key)
      b:SetText(n > 0 and (b.label .. " (" .. n .. ")") or b.label)
    end

    board:Refresh(self.period, self.category)
    local items = feed:Refresh()
    local others = ns.Social.FriendCount(self.category)
    local warn = ""
    if not ns.settings.shareEnabled then warn = "|cffff5555Sharing is OFF|r"
    elseif self.category == "everyone" and not ns.settings.globalBoard then warn = "|cffff5555Everyone board is OFF|r" end
    info:SetText(warn)

    if isBoard and others == 0 then
      empty:SetText(CATEGORY_EMPTY[self.category])
      empty:Show()
    elseif not isBoard and items == 0 then
      empty:SetText("Nothing here yet. Activities, challenges and achievements from you and your friends show up here.")
      empty:Show()
    else
      empty:Hide()
    end
  end
end
