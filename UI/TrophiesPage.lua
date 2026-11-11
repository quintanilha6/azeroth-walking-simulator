local _, ns = ...
local L = ns.L
local F = ns.F

local TILE_W, TILE_H = 284, 48

function ns.BuildTrophiesPage(page)
  local A = ns.Achievements

  -- Rank card
  local rank = CreateFrame("Frame", nil, page)
  rank:SetSize(580, 66)
  rank:SetPoint("TOPLEFT")
  local bg = rank:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.10)
  local icon = rank:CreateTexture(nil, "ARTWORK")
  icon:SetSize(46, 46)
  icon:SetPoint("LEFT", 10, 0)
  icon:SetTexture("Interface\\Icons\\Ability_Rogue_Sprint")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local kicker = rank:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  kicker:SetPoint("TOPLEFT", 66, -8)
  local name = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  name:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
  name:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -2)
  local bar = CreateFrame("StatusBar", nil, rank)
  bar:SetPoint("TOPLEFT", 66, -46)
  bar:SetSize(300, 10)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(unpack(ns.ORANGE))
  bar:SetMinMaxValues(0, 1)
  local barBg = bar:CreateTexture(nil, "BACKGROUND")
  barBg:SetAllPoints()
  barBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  barBg:SetVertexColor(0, 0, 0, 0.5)
  local next = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  next:SetPoint("LEFT", bar, "RIGHT", 8, 0)

  local counts = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  counts:SetPoint("TOPLEFT", 4, -74)

  rank:EnableMouse(true)
  rank:SetScript("OnEnter", function(self) A.ShowRankTooltip(self) end)
  rank:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Scrolling area: rank list, achievements grid, then personal records
  local _, content = ns.MakeScroll(page, "AWSTrophyScroll", -94)

  local function SectionHeader(y, text)
    local h = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 0, y)
    h:SetTextColor(unpack(ns.ORANGE))
    h:SetText(text)
  end

  -- Walker ranks: all nine, with what each needs
  local RANK_ROW = 18
  SectionHeader(0, L["Walker ranks"])
  local rankNote = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  rankNote:SetPoint("TOPLEFT", 0, -17)
  rankNote:SetText(L["Earned from all-time steps on this character. Each rank up shows a banner and tells your friends."])
  local rankRows = {}
  for i, r in ipairs(A.RANKS) do
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(560, RANK_ROW)
    row:SetPoint("TOPLEFT", 0, -34 - (i - 1) * RANK_ROW)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.mark:SetPoint("LEFT", 4, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", 24, 0)
    row.name:SetText(("%d.  %s"):format(i, A.RankColored(i)))
    row.need = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.need:SetPoint("LEFT", 270, 0)
    row.need:SetText(F.Number(r[1]) .. L[" steps"])
    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", 390, 0)
    rankRows[i] = row
  end
  local GRID_TOP = -34 - #A.RANKS * RANK_ROW - 14

  SectionHeader(GRID_TOP, L["Achievements"])
  GRID_TOP = GRID_TOP - 20

  local tiles = {}
  for i, a in ipairs(A.LIST) do
    local t = CreateFrame("Frame", nil, content)
    t:SetSize(TILE_W - 4, TILE_H - 4)
    t:SetPoint("TOPLEFT", ((i - 1) % 2) * TILE_W, GRID_TOP - math.floor((i - 1) / 2) * TILE_H)
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(36, 36)
    t.icon:SetPoint("LEFT", 4, 0)
    t.icon:SetTexture(a.icon)
    t.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.name:SetPoint("TOPLEFT", 46, -4)
    t.name:SetText(L[a.name])
    t.line1 = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.line1:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -2)
    t.line1:SetWidth(TILE_W - 56)
    t.line1:SetJustifyH("LEFT")
    t.line1:SetWordWrap(false)
    t.line2 = t:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t.line2:SetPoint("TOPLEFT", t.line1, "BOTTOMLEFT", 0, -1)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(L[a.name], 1, 0.82, 0)
      GameTooltip:AddLine(L[a.desc], 1, 1, 1, true)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t.a = a
    tiles[i] = t
  end

  local gridH = -GRID_TOP + math.ceil(#A.LIST / 2) * TILE_H
  local recHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  recHeader:SetPoint("TOPLEFT", 0, -gridH - 10)
  recHeader:SetTextColor(unpack(ns.ORANGE))
  recHeader:SetText(L["Personal records"])
  local recLabels = { L["Most steps in one activity"], L["Longest distance"], L["Longest moving time"], L["Best day"],
                      L["Longest streak"], L["Zones walked in"] }
  local recValues = {}
  for i, label in ipairs(recLabels) do
    local y = -gridH - 30 - (i - 1) * 20
    local l = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    l:SetPoint("TOPLEFT", 4, y)
    l:SetText(label)
    recValues[i] = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    recValues[i]:SetPoint("TOPLEFT", 210, y)
  end
  content:SetHeight(gridH + 40 + #recLabels * 20)

  local function SessionText(s, value)
    if not s then return "-" end
    return value .. "   |cff888888" .. F.Day(s.start) .. "|r"
  end

  function page:Refresh()
    local c = ns.cdb
    local steps = c.total.steps
    local idx = A.MyRank()
    kicker:SetText((L["RANK %d OF %d"]):format(idx, #A.RANKS))
    name:SetText(A.RankColored(idx))
    local nextRank = A.RANKS[idx + 1]
    if nextRank then
      local from = A.RANKS[idx][1]
      bar:SetValue((steps - from) / (nextRank[1] - from))
      next:SetText((L["%s / %s steps to %s"]):format(F.Number(steps), F.Number(nextRank[1]), L[nextRank[2]]))
    else
      bar:SetValue(1)
      next:SetText(L["Max rank. Legendary walker!"])
    end

    for i, row in ipairs(rankRows) do
      if i == idx then
        row.bg:SetVertexColor(ns.ORANGE[1], ns.ORANGE[2], ns.ORANGE[3], 0.18)
        row.mark:SetText(A.CHECK)
        row.status:SetText(L["You are here"])
      elseif i < idx then
        row.bg:SetVertexColor(1, 1, 1, 0.03)
        row.mark:SetText(A.CHECK)
        row.status:SetText("|cff33dd55Reached|r")
      else
        row.bg:SetVertexColor(1, 1, 1, 0)
        row.mark:SetText("")
        row.status:SetText(i == idx + 1 and ("|cffaaaaaa" .. A.NextRankText(steps) .. "|r") or "")
      end
    end

    local w, m, champ = ns.Challenges.Counts()
    counts:SetText((L["|cffffd100Achievements|r %d/%d     |cffffd100Weekly challenges|r %d     "] ..
      L["|cffffd100Monthly|r %d     |cffffd100Weekly Champion|r x%d"]):format(A.Count(), #A.LIST, w, m, champ))

    for _, t in ipairs(tiles) do
      local earned = c.achievements[t.a.id]
      t.icon:SetDesaturated(not earned)
      t.icon:SetAlpha(earned and 1 or 0.5)
      if earned then
        t.bg:SetVertexColor(1, 0.82, 0, 0.10)
        t.name:SetTextColor(1, 0.82, 0)
        t.line1:SetText(L[t.a.desc])
        t.line2:SetText(L["Earned "] .. F.Day(earned))
      else
        t.bg:SetVertexColor(1, 1, 1, 0.03)
        t.name:SetTextColor(0.6, 0.6, 0.6)
        t.line1:SetText(L[t.a.desc])
        local value, goal = t.a.check(c)
        t.line2:SetText(A.ProgressText(t.a, value, goal))
      end
    end

    local r = ns.Records()
    recValues[1]:SetText(SessionText(r.steps, r.steps and F.Number(r.steps.steps)))
    recValues[2]:SetText(SessionText(r.distance, r.distance and F.Distance(r.distance.distance)))
    recValues[3]:SetText(SessionText(r.moving, r.moving and F.Time(r.moving.moving)))
    if r.dayKey and r.daySteps >= 1 then
      recValues[4]:SetText((L["%s steps   |cff888888%s|r"]):format(F.Number(r.daySteps), r.dayKey))
    else
      recValues[4]:SetText("-")
    end
    local _, best = ns.Streaks()
    recValues[5]:SetText(best .. L[" days"])
    local zones = 0
    for _ in pairs(c.zones) do zones = zones + 1 end
    recValues[6]:SetText(zones)
  end
end
