local _, ns = ...
local L = ns.L
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
local BOARD_COLS = { { "#", 14, 22 }, { "Name", 38, 140 }, { "Rank", 182, 132 }, { "Steps", 336, 85 },
                     { "Trophies", 425, 60 }, { "Streak", 490, 60 } }

local function BoardTooltip(row, d)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.Social.ColoredName(d.guid) .. (d.me and L["  (you)"] or ""))
  local A = ns.Achievements
  GameTooltip:AddLine((L["%s  |cff888888(rank %d of %d)|r"]):format(A.RankColored(d.rank), d.rank or 1, #A.RANKS))
  local nextText = A.NextRankText(d.all or 0)
  if nextText then GameTooltip:AddLine(nextText, 0.99, 0.6, 0.3) end
  if d.active then
    GameTooltip:AddLine((L["Walking now: %s steps this session"]):format(F.Number(d.sessionSteps or 0)), 0.2, 0.9, 0.3)
  elseif d.online then
    GameTooltip:AddLine(L["Online"], 0.9, 0.8, 0.2)
  elseif d.e and d.e.updated then
    GameTooltip:AddLine(L["Last seen "] .. F.Date(d.e.updated), 0.6, 0.6, 0.6)
  end
  AddLine(L["Today"], F.Number(d.today) .. L[" steps"])
  AddLine(L["This week"], F.Number(d.week) .. L[" steps"])
  AddLine(L["This month"], F.Number(d.month) .. L[" steps"])
  AddLine("All-time", F.Number(d.all) .. L[" steps"])
  AddLine(L["Weekly challenges"], (d.weekDone or 0) .. " / 3")
  AddLine(L["Trophies"], d.trophies or 0)
  AddLine(L["Streak"], (d.streak or 0) .. L[" days"])
  if d.e and d.e.since and d.e.since > 0 then AddLine(L["Walking since"], F.Day(d.e.since)) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L["Ranks come from all-time steps. See them all in the Trophies tab."], 0.5, 0.5, 0.5, true)
  if not d.me then GameTooltip:AddLine(L["Right-click: whisper, invite to party..."], 0.5, 0.5, 0.5) end
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Right-click menu on a player: whisper, invite, ask to join, add friend
---------------------------------------------------------------------------
local menuFrame

local function Call(...)
  for i = 1, select("#", ...) do
    local f = select(i, ...)
    if f then return f end
  end
end

local function PlayerActions(d)
  local full = d.e and d.e.name
  if not full then return nil end
  local target = Ambiguate and Ambiguate(full, "none") or full -- no realm when it's yours
  local list = {
    { L["Whisper"], function()
      if ChatFrame_SendTell then ChatFrame_SendTell(target)
      elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. target .. " ") end
    end },
  }
  -- One party option: ask to join if they're already in a group, otherwise
  -- invite them; nothing if they're in your group already
  local invite = Call(C_PartyInfo and C_PartyInfo.InviteUnit, InviteUnit)
  local ask = Call(C_PartyInfo and C_PartyInfo.RequestInviteFromUnit, RequestInviteFromUnit)
  local withMe = (UnitInParty and UnitInParty(target)) or (UnitInRaid and UnitInRaid(target))
  if withMe then
    -- already together
  elseif d.e.inGroup and ask then
    table.insert(list, { L["Ask to join their party"], function() ask(target) end })
  elseif invite then
    table.insert(list, { L["Invite to party"], function() invite(target) end })
  end
  if C_FriendList and C_FriendList.AddFriend and not ns.Social.IsFriend(d.e) then
    table.insert(list, { L["Add friend"], function() C_FriendList.AddFriend(target) end })
  end
  return list
end

local function OpenPlayerMenu(owner, d)
  if not d or d.me then return end
  local actions = PlayerActions(d)
  if not actions then return end
  GameTooltip:Hide()
  local title = ns.Social.ColoredName(d.guid) .. (d.online and "" or L[" |cff888888(offline)|r"])

  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(title)
      for _, a in ipairs(actions) do
        local b = root:CreateButton(a[1], a[2])
        if not d.online and b.SetEnabled then b:SetEnabled(false) end
      end
    end)
    return
  end

  if not (UIDropDownMenu_Initialize and ToggleDropDownMenu) then return end
  menuFrame = menuFrame or CreateFrame("Frame", "AWSPlayerMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(menuFrame, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text, info.isTitle, info.notCheckable = title, true, true
    UIDropDownMenu_AddButton(info, level)
    for _, a in ipairs(actions) do
      info = UIDropDownMenu_CreateInfo()
      info.text, info.func, info.notCheckable, info.disabled = a[1], a[2], true, not d.online
      UIDropDownMenu_AddButton(info, level)
    end
    info = UIDropDownMenu_CreateInfo()
    info.text, info.notCheckable, info.func = CANCEL or L["Cancel"], true, function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
  end, "MENU")
  ToggleDropDownMenu(1, nil, menuFrame, "cursor", 0, 0)
end

local function BuildBoard(box)
  for _, c in ipairs(BOARD_COLS) do
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", c[2], 0)
    h:SetText(L[c[1]])
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
    -- ▲/▼ when this player just moved up or down
    r.arrow = r:CreateTexture(nil, "OVERLAY")
    r.arrow:SetSize(14, 14)
    r.arrow:SetPoint("LEFT", 320, 0)
    r.arrow:Hide()
    r:SetScript("OnEnter", function(self) if self.data then BoardTooltip(self, self.data) end end)
    r:RegisterForClicks("RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then OpenPlayerMenu(self, self.data) end
    end)
    rows[i] = r
    return r
  end

  -- Remember positions to show movement arrows (reset when the view changes)
  local lastPos, arrowUntil, arrowUp, lastView = {}, {}, {}, nil

  -- What to show: the top TOP_N, then (if you're further down) a gap and the
  -- players around you. Searching shows every match, wherever they are.
  -- Everyone keeps their real place on the full board.
  local TOP_N, AROUND = 50, 2
  local GAP = { gap = true }

  local function NameOf(d)
    local name = d.me and UnitName("player") or (d.e and d.e.name) or ""
    return strlower(name:match("^([^-]+)") or name)
  end

  local function Visible(full, search, onlineOnly)
    local list = {}
    for i, d in ipairs(full) do
      d.place = i
      if (not onlineOnly or d.online or d.me) and (search == "" or NameOf(d):find(search, 1, true)) then
        list[#list + 1] = d
      end
    end
    if search ~= "" then
      for i = TOP_N + 1, #list do list[i] = nil end
      return list
    end
    local mine
    for i, d in ipairs(list) do if d.me then mine = i end end
    local shown = {}
    for i = 1, math.min(#list, TOP_N) do shown[#shown + 1] = list[i] end
    if mine and mine > TOP_N then
      local from = math.max(TOP_N + 1, mine - AROUND)
      if from > TOP_N + 1 then shown[#shown + 1] = GAP end
      for i = from, math.min(#list, mine + AROUND) do shown[#shown + 1] = list[i] end
    end
    return shown
  end

  -- returns how many rows are shown
  function box:Refresh(period, category, search, onlineOnly)
    search = strlower(strtrim(search or ""))
    local list = Visible(ns.Social.Leaderboard(period, category), search, onlineOnly)
    local view, now = period .. ":" .. category, GetTime()
    local fresh = view ~= lastView
    if fresh then wipe(lastPos); wipe(arrowUntil); lastView = view end
    local pulse = 0.55 + 0.45 * math.sin(now * 5)

    for i, d in ipairs(list) do
      local r = GetRow(i)
      if d.gap then
        -- "..." between the top and the players around you
        r.data = nil
        r.dot:SetAlpha(0)
        r.arrow:Hide()
        for c = 1, #r.cells do r.cells[c]:SetText("") end
        r.cells[2]:SetText("|cff888888...|r")
        r.bg:SetVertexColor(1, 1, 1, 0)
        r:Show()
      else
      local place = d.place
      r.data = d
      if d.walking then
        r.dot:SetVertexColor(0.2, 0.9, 0.3)
        r.dot:SetAlpha(pulse)
      else
        r.dot:SetAlpha(1)
        if d.active then r.dot:SetVertexColor(0.2, 0.9, 0.3)
        elseif d.online then r.dot:SetVertexColor(0.9, 0.8, 0.2)
        else r.dot:SetVertexColor(0.35, 0.35, 0.35) end
      end

      local prev = lastPos[d.guid]
      if not fresh and prev and prev ~= place then
        arrowUntil[d.guid], arrowUp[d.guid] = now + 6, place < prev
      end
      lastPos[d.guid] = place
      if (arrowUntil[d.guid] or 0) > now then
        local up = arrowUp[d.guid]
        r.arrow:SetTexture(up and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
        if up then r.arrow:SetVertexColor(0.2, 1, 0.3) else r.arrow:SetVertexColor(1, 0.3, 0.3) end
        r.arrow:Show()
      else
        r.arrow:Hide()
      end
      local medal = MEDALS[place]
      r.cells[1]:SetText(place)
      if medal and d.value > 0 then r.cells[1]:SetTextColor(unpack(medal)) else r.cells[1]:SetTextColor(1, 1, 1) end
      r.cells[2]:SetText(ns.Social.ColoredName(d.guid) .. (d.me and L[" |cff888888(you)|r"] or ""))
      r.cells[3]:SetText(ns.Achievements.RankColored(d.rank))
      r.cells[4]:SetText(F.Number(d.value))
      r.cells[5]:SetText(d.trophies or 0)
      r.cells[6]:SetText((d.streak or 0) .. "d")
      if d.me then r.bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.12)
      else r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0) end
      r:Show()
      end
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    content:SetHeight(math.max(1, #list * 22))
    return #list
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
  AddLine(L["Steps"], F.Number(it.steps))
  AddLine(L["Distance"], F.Distance(it.distance))
  AddLine(L["Moving time"], F.Time(it.moving))
  AddLine(L["Elapsed time"], F.Time(it.elapsed))
  AddLine(L["Avg pace"], F.Pace(it.moving, it.distance))
  if it.zones and #it.zones > 0 then
    GameTooltip:AddLine(L["Zones: "] .. table.concat(it.zones, ", "), 1, 1, 1, true)
  end
  if it.mine and it.kudosList and #it.kudosList > 0 then
    local names = {}
    for _, g in ipairs(it.kudosList) do table.insert(names, ns.Social.ColoredName(g)) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Kudos from: "] .. table.concat(names, ", "), 0.99, 0.6, 0.3, true)
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

    r.btn = ns.SmallButton(r, L["Kudos"], 72, function()
      local it = r.item
      if it.mine then ns.QuickShare.Open(r.btn, ns.QuickShare.ActivityText(it.src))
      else ns.Social.GiveKudos(it) end
    end)
    r.btn:SetPoint("RIGHT", -4, 0)

    -- Map icon: your route, or ask the friend for theirs
    r.map = CreateFrame("Button", nil, r)
    r.map:SetSize(18, 18)
    r.map:SetPoint("RIGHT", r.btn, "LEFT", -6, 0)
    r.map:SetNormalTexture("Interface\\Icons\\INV_Misc_Map_01")
    r.map:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    r.map:SetScript("OnClick", function()
      local it = r.item
      if it.mine then
        ns.RouteViewer.Open(it.src)
      else
        local e = ns.db.social.people[it.from]
        ns.RouteViewer.OpenFriend(it, ns.Social.Short(e and e.name or "?"))
      end
    end)
    r.map:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L["View route"])
      GameTooltip:Show()
    end)
    r.map:SetScript("OnLeave", function() GameTooltip:Hide() end)

    r.kudos = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.kudos:SetPoint("RIGHT", r.map, "LEFT", -6, 0)
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
        r.map:Hide()
        r.kudos:SetText("")
      else
        r.map:SetShown(not it.mine or ns.Routes.Has(it.src))
        r.icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
        local zone = it.zones and it.zones[1]
        r.top:SetText(("%s  |cff888888%s%s|r"):format(ns.Social.ColoredName(it.from), when,
          zone and ("  -  " .. zone) or ""))
        r.bottom:SetText((L["|cffccccccsteps|r %s   |cffcccccc%s   %s   %s|r"]):format(F.Number(it.steps),
          F.Distance(it.distance), F.Time(it.moving), F.Pace(it.moving, it.distance)))
        r.bg:SetVertexColor(1, 1, 1, i % 2 == 0 and 0.03 or 0)
        r.btn:Show()
        if it.mine then
          r.btn:SetText(L["Share"])
          r.btn:SetEnabled(true)
          local n = it.kudosList and #it.kudosList or 0
          r.kudos:SetText(n > 0 and (n .. L[" kudos"]) or "")
        else
          r.btn:SetText(it.kudos and L["Sent"] or L["Kudos"])
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
  -- (one string each: these are also the translation keys)
  friends = "None of your friends use Azeroth Walking Simulator yet (or they haven't been online with you).\nFriends list and Battle.net friends playing WoW Forever show up here.",
  guild = "No guildies with Azeroth Walking Simulator yet. Tell your guild to install it!",
  everyone = "No other walkers seen yet. Everyone with the addon (and the Everyone leaderboard turned on in Settings) shows up here once you've both been online.",
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
  local boardBtn = ns.SmallButton(page, L["Leaderboard"], 100, function() page.mode = "board"; page:Refresh() end)
  boardBtn:SetPoint("TOPLEFT", 0, 0)
  local feedBtn = ns.SmallButton(page, L["Feed"], 100, function() page.mode = "feed"; page:Refresh() end)
  feedBtn:SetPoint("LEFT", boardBtn, "RIGHT", 4, 0)

  -- Second row: which leaderboard (left) and which period (right)
  local catBtns = {}
  for i, c in ipairs(CATEGORIES) do
    local key = c[1]
    local b = ns.SmallButton(page, L[c[2]], 84, function() page.category = key; page:Refresh() end)
    if i == 1 then b:SetPoint("TOPLEFT", 0, -28)
    else b:SetPoint("LEFT", catBtns[i - 1], "RIGHT", 2, 0) end
    b.key, b.label = key, L[c[2]]
    catBtns[i] = b
  end

  -- Top row, right: "Online now" filter and a name search (leaderboard only)
  local ok, search = pcall(CreateFrame, "EditBox", "AWSBoardSearch", page, "SearchBoxTemplate")
  if not ok then search = CreateFrame("EditBox", "AWSBoardSearch", page, "InputBoxTemplate") end
  search:SetSize(110, 20)
  search:SetPoint("TOPRIGHT", -24, 0)
  search:SetAutoFocus(false)
  search:SetMaxLetters(24)
  if search.Instructions then search.Instructions:SetText(L["Search name"]) end
  search:HookScript("OnTextChanged", function(self)
    page.search = self:GetText() or ""
    page:Refresh()
  end)
  search:HookScript("OnEnterPressed", function(self) self:ClearFocus() end)
  search:HookScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local online = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
  online:SetSize(22, 22)
  online:SetPoint("RIGHT", search, "LEFT", -76, 0)
  -- warnings ("Sharing is OFF") sit just left of the filter
  info:ClearAllPoints()
  info:SetPoint("RIGHT", online, "LEFT", -6, 0)
  info:SetJustifyH("RIGHT")
  local onlineLabel = online:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  onlineLabel:SetPoint("LEFT", online, "RIGHT", 0, 1)
  onlineLabel:SetText(L["Online now"])
  online:SetScript("OnClick", function(self)
    page.onlineOnly = self:GetChecked() and true or false
    page:Refresh()
  end)

  local periodBtns = {}
  for i = #PERIODS, 1, -1 do
    local key, label = PERIODS[i][1], L[PERIODS[i][2]]
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
    search:SetShown(isBoard)
    online:SetShown(isBoard)
    for _, b in ipairs(catBtns) do
      b:SetShown(isBoard)
      b:SetEnabled(b.key ~= self.category)
      local n = ns.Social.FriendCount(b.key)
      b:SetText(n > 0 and (b.label .. " (" .. n .. ")") or b.label)
    end

    local shown = board:Refresh(self.period, self.category, self.search, self.onlineOnly)
    local items = feed:Refresh()
    local others = ns.Social.FriendCount(self.category)
    local warn = ""
    if not ns.settings.shareEnabled then warn = L["|cffff5555Sharing is OFF|r"]
    elseif self.category == "everyone" and not ns.settings.globalBoard then warn = L["|cffff5555Everyone board is OFF|r"] end
    info:SetText(warn)

    local searching = strtrim(self.search or "") ~= ""
    if isBoard and searching and shown == 0 then
      empty:SetText((L["No player named \"%s\" on this leaderboard."]):format(strtrim(self.search)))
      empty:Show()
    elseif isBoard and others == 0 and not searching then
      empty:SetText(L[CATEGORY_EMPTY[self.category]])
      empty:Show()
    elseif not isBoard and items == 0 then
      empty:SetText(L["Nothing here yet. Activities, challenges and achievements from you and your friends show up here."])
      empty:Show()
    else
      empty:Hide()
    end
  end
end
