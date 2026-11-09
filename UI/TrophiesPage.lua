local _, ns = ...
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

  -- Scrolling area: achievements grid, then personal records
  local _, content = ns.MakeScroll(page, "AWSTrophyScroll", -94)

  local tiles = {}
  for i, a in ipairs(A.LIST) do
    local t = CreateFrame("Frame", nil, content)
    t:SetSize(TILE_W - 4, TILE_H - 4)
    t:SetPoint("TOPLEFT", ((i - 1) % 2) * TILE_W, -math.floor((i - 1) / 2) * TILE_H)
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
    t.name:SetText(a.name)
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
      GameTooltip:AddLine(a.name, 1, 0.82, 0)
      GameTooltip:AddLine(a.desc, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    t.a = a
    tiles[i] = t
  end

  local gridH = math.ceil(#A.LIST / 2) * TILE_H
  local recHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  recHeader:SetPoint("TOPLEFT", 0, -gridH - 10)
  recHeader:SetTextColor(unpack(ns.ORANGE))
  recHeader:SetText("Personal records")
  local recLabels = { "Most steps in one activity", "Longest distance", "Longest moving time", "Best day",
                      "Longest streak", "Zones walked in" }
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
    kicker:SetText(("RANK %d OF %d"):format(idx, #A.RANKS))
    name:SetText(A.RankColored(idx))
    local nextRank = A.RANKS[idx + 1]
    if nextRank then
      local from = A.RANKS[idx][1]
      bar:SetValue((steps - from) / (nextRank[1] - from))
      next:SetText(("%s / %s steps to %s"):format(F.Number(steps), F.Number(nextRank[1]), nextRank[2]))
    else
      bar:SetValue(1)
      next:SetText("Max rank. Legendary walker!")
    end

    local w, m, champ = ns.Challenges.Counts()
    counts:SetText(("|cffffd100Achievements|r %d/%d     |cffffd100Weekly challenges|r %d     " ..
      "|cffffd100Monthly|r %d     |cffffd100Weekly Champion|r x%d"):format(A.Count(), #A.LIST, w, m, champ))

    for _, t in ipairs(tiles) do
      local earned = c.achievements[t.a.id]
      t.icon:SetDesaturated(not earned)
      t.icon:SetAlpha(earned and 1 or 0.5)
      if earned then
        t.bg:SetVertexColor(1, 0.82, 0, 0.10)
        t.name:SetTextColor(1, 0.82, 0)
        t.line1:SetText(t.a.desc)
        t.line2:SetText("Earned " .. F.Day(earned))
      else
        t.bg:SetVertexColor(1, 1, 1, 0.03)
        t.name:SetTextColor(0.6, 0.6, 0.6)
        t.line1:SetText(t.a.desc)
        local value, goal = t.a.check(c)
        t.line2:SetText(A.ProgressText(t.a, value, goal))
      end
    end

    local r = ns.Records()
    recValues[1]:SetText(SessionText(r.steps, r.steps and F.Number(r.steps.steps)))
    recValues[2]:SetText(SessionText(r.distance, r.distance and F.Distance(r.distance.distance)))
    recValues[3]:SetText(SessionText(r.moving, r.moving and F.Time(r.moving.moving)))
    if r.dayKey and r.daySteps >= 1 then
      recValues[4]:SetText(("%s steps   |cff888888%s|r"):format(F.Number(r.daySteps), r.dayKey))
    else
      recValues[4]:SetText("-")
    end
    local _, best = ns.Streaks()
    recValues[5]:SetText(best .. " days")
    local zones = 0
    for _ in pairs(c.zones) do zones = zones + 1 end
    recValues[6]:SetText(zones)
  end
end
