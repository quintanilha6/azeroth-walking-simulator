local _, ns = ...
local F = ns.F

-- Strava-style route card for an activity, a "Show on world map" overlay,
-- and a screenshot button.
local V = {}
ns.RouteViewer = V

local CANVAS_W, CANVAS_H, PAD = 500, 280, 18
local GREEN, WHITE = { 0.2, 0.9, 0.3 }, { 1, 1, 1 }

---------------------------------------------------------------------------
-- Line drawing with a reusable pool
---------------------------------------------------------------------------
local function NewPool(parent)
  return { parent = parent, items = {}, used = 0 }
end

local function PoolLine(pool, thickness, r, g, b, a)
  pool.used = pool.used + 1
  local line = pool.items[pool.used]
  if not line then
    if pool.parent.CreateLine then
      line = pool.parent:CreateLine(nil, "ARTWORK")
    else
      line = pool.parent:CreateTexture(nil, "ARTWORK") -- fallback: dots only
      line.isDot = true
    end
    pool.items[pool.used] = line
  end
  if line.isDot then
    line:SetSize(thickness, thickness)
  else
    line:SetThickness(thickness)
  end
  line:SetColorTexture(r, g, b, a or 1)
  line:Show()
  return line
end

local function PoolReset(pool)
  for i = 1, pool.used do pool.items[i]:Hide() end
  pool.used = 0
end

-- Draw from (x1,y1) to (x2,y2), coordinates from the parent's top-left (y down)
local function Segment(pool, frame, x1, y1, x2, y2, thickness, color, alpha)
  local line = PoolLine(pool, thickness, color[1], color[2], color[3], alpha)
  if line.isDot then
    line:ClearAllPoints()
    line:SetPoint("CENTER", frame, "TOPLEFT", x2, -y2)
  else
    line:SetStartPoint("TOPLEFT", frame, x1, -y1)
    line:SetEndPoint("TOPLEFT", frame, x2, -y2)
  end
end

local function Marker(frame, color)
  local m = frame:CreateTexture(nil, "OVERLAY")
  m:SetTexture("Interface\\Buttons\\WHITE8X8")
  m:SetSize(10, 10)
  m:SetVertexColor(unpack(color))
  local border = frame:CreateTexture(nil, "OVERLAY", nil, -1)
  border:SetTexture("Interface\\Buttons\\WHITE8X8")
  border:SetVertexColor(0, 0, 0, 1)
  border:SetPoint("TOPLEFT", m, -2, 2)
  border:SetPoint("BOTTOMRIGHT", m, 2, -2)
  m.border = border
  return m
end

local function PlaceMarker(m, frame, x, y)
  m:ClearAllPoints()
  m:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
  m:Show()
  m.border:Show()
end

---------------------------------------------------------------------------
-- The route card window
---------------------------------------------------------------------------
local card

local function Stat(parent, x, label)
  local l = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  l:SetPoint("TOPLEFT", x, -(70 + CANVAS_H + 14))
  l:SetText(label)
  local v = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
  return v
end

local function BuildCard()
  card = ns.CreatePanel("AWSRouteCard")
  card:SetSize(CANVAS_W + 40, CANVAS_H + 190)
  card:SetPoint("CENTER")
  card:SetFrameStrata("DIALOG")
  card:SetToplevel(true)
  card:SetClampedToScreen(true)
  card:SetMovable(true)
  card:EnableMouse(true)
  card:RegisterForDrag("LeftButton")
  card:SetScript("OnDragStart", card.StartMoving)
  card:SetScript("OnDragStop", card.StopMovingOrSizing)
  card:Hide()
  tinsert(UISpecialFrames, "AWSRouteCard")

  card.brand = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  card.brand:SetPoint("TOPLEFT", 20, -14)
  card.brand:SetTextColor(unpack(ns.ORANGE))
  card.brand:SetText("AZEROTH WALKING SIMULATOR")
  card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  card.title:SetPoint("TOPLEFT", card.brand, "BOTTOMLEFT", 0, -6)
  card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
  card.sub:SetWidth(CANVAS_W)
  card.sub:SetJustifyH("LEFT")
  card.sub:SetWordWrap(false)
  card.sub:SetTextColor(0.75, 0.75, 0.75)

  card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
  card.close:SetPoint("TOPRIGHT", -2, -2)

  -- Map-like dark canvas with the route on it
  local canvas = CreateFrame("Frame", nil, card)
  canvas:SetSize(CANVAS_W, CANVAS_H)
  canvas:SetPoint("TOPLEFT", 20, -70)
  local bg = canvas:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.09, 0.10, 0.12, 1)
  -- faint grid, like a map
  for i = 1, 9 do
    local v = canvas:CreateTexture(nil, "BORDER")
    v:SetTexture("Interface\\Buttons\\WHITE8X8")
    v:SetVertexColor(1, 1, 1, 0.04)
    v:SetSize(1, CANVAS_H)
    v:SetPoint("TOPLEFT", i * CANVAS_W / 10, 0)
  end
  for i = 1, 5 do
    local h = canvas:CreateTexture(nil, "BORDER")
    h:SetTexture("Interface\\Buttons\\WHITE8X8")
    h:SetVertexColor(1, 1, 1, 0.04)
    h:SetSize(CANVAS_W, 1)
    h:SetPoint("TOPLEFT", 0, -i * CANVAS_H / 6)
  end
  card.canvas = canvas
  card.pool = NewPool(canvas)
  card.startMark = Marker(canvas, GREEN)
  card.endMark = Marker(canvas, WHITE)
  card.empty = canvas:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  card.empty:SetPoint("CENTER")
  card.empty:SetWidth(CANVAS_W - 40)

  card.dist = Stat(card, 20, "Distance")
  card.steps = Stat(card, 150, "Steps")
  card.time = Stat(card, 270, "Moving time")
  card.pace = Stat(card, 390, "Avg pace")

  card.mapBtn = ns.SmallButton(card, "Show on world map", 150, function() V.ShowOnMap(card.activity) end)
  card.mapBtn:SetPoint("BOTTOMLEFT", 20, 14)
  card.shotBtn = ns.SmallButton(card, "Screenshot", 110, function() V.Screenshot() end)
  card.shotBtn:SetPoint("LEFT", card.mapBtn, "RIGHT", 8, 0)
  card.shareBtn = ns.SmallButton(card, "Quick Share", 110, function()
    ns.QuickShare.Open(card.shareBtn, ns.QuickShare.ActivityText(card.activity))
  end)
  card.shareBtn:SetPoint("LEFT", card.shotBtn, "RIGHT", 8, 0)
end

local function DrawCardRoute(s)
  local canvas, pool = card.canvas, card.pool
  PoolReset(pool)
  card.startMark:Hide(); card.startMark.border:Hide()
  card.endMark:Hide(); card.endMark.border:Hide()

  if not ns.Routes.Has(s) then
    card.empty:SetText("No route for this activity.\nRoutes are recorded outdoors only: the game hides your " ..
      "position in dungeons. Older activities keep only their numbers.")
    card.empty:Show()
    return
  end
  card.empty:Hide()

  -- Fit the whole route in the canvas, keeping its shape (north up, like the map)
  local minA, maxA, minB, maxB = ns.Routes.Bounds(s.route)
  local spanA, spanB = math.max(maxA - minA, 1), math.max(maxB - minB, 1)
  local scale = math.min((CANVAS_W - PAD * 2) / spanB, (CANVAS_H - PAD * 2) / spanA)
  local offX = (CANVAS_W - spanB * scale) / 2
  local offY = (CANVAS_H - spanA * scale) / 2
  local function XY(a, b) return offX + (maxB - b) * scale, offY + (maxA - a) * scale end

  local firstX, firstY, lastX, lastY
  for pass = 1, 2 do -- dark outline first, then the orange route on top
    for _, seg in ipairs(s.route.segs) do
      local pts = seg.pts
      local px, py = XY(pts[1], pts[2])
      if pass == 2 and not firstX then firstX, firstY = px, py end
      for i = 3, #pts, 2 do
        local x, y = XY(pts[i], pts[i + 1])
        if pass == 1 then
          Segment(pool, canvas, px, py, x, y, 7, { 0, 0, 0 }, 0.7)
        else
          Segment(pool, canvas, px, py, x, y, 3.5, ns.ORANGE, 1)
        end
        px, py = x, y
      end
      if pass == 2 then lastX, lastY = px, py end
    end
  end
  PlaceMarker(card.startMark, canvas, firstX, firstY)
  PlaceMarker(card.endMark, canvas, lastX, lastY)
end

function V.Open(s)
  if not s then return ns.Print("No activity to show yet.") end
  if not card then BuildCard() end
  card.activity = s
  local live = s == ns.cdb.current
  card.title:SetText(UnitName("player") .. (live and "  -  walking now" or ""))
  local zones = s.zones and #s.zones > 0 and table.concat(s.zones, ", ") or "Azeroth"
  card.sub:SetText(F.Date(s.start) .. "   " .. zones)
  card.dist:SetText(F.Distance(s.distance))
  card.steps:SetText(F.Number(s.steps))
  card.time:SetText(F.Time(s.moving))
  card.pace:SetText(F.Pace(s.moving, s.distance))
  DrawCardRoute(s)
  card.mapBtn:SetEnabled(ns.Routes.Has(s))
  card:Show()
end

-- Screenshot of the card (buttons hidden for a clean picture)
function V.Screenshot()
  if not card or not card:IsShown() then return end
  if not Screenshot then return ns.Print("Screenshots aren't available on this client.") end
  local buttons = { card.mapBtn, card.shotBtn, card.shareBtn, card.close }
  for _, b in ipairs(buttons) do b:Hide() end
  C_Timer.After(0.1, function()
    Screenshot()
    C_Timer.After(0.3, function() for _, b in ipairs(buttons) do b:Show() end end)
    ns.Print("Screenshot saved to your WoW Screenshots folder.")
  end)
end

---------------------------------------------------------------------------
-- World map overlay
---------------------------------------------------------------------------
local overlay, overlayPool, mapRoute, hooked
local mapStart, mapEnd

local function MapCanvas()
  return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

function V.DrawOnMap()
  if not overlay then return end
  PoolReset(overlayPool)
  mapStart:Hide(); mapStart.border:Hide()
  mapEnd:Hide(); mapEnd.border:Hide()
  local canvas = MapCanvas()
  if not mapRoute or not canvas or not WorldMapFrame:IsShown() then return end
  local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local cont, toMap = ns.Routes.MapTransform(mapID)
  if not toMap then return end

  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local thick = math.max(2, 4 / (canvas:GetScale() or 1))
  local function In(nx, ny) return nx > -0.05 and nx < 1.05 and ny > -0.05 and ny < 1.05 end
  local first, last
  for _, seg in ipairs(mapRoute.segs) do
    if seg.inst == nil or seg.inst == cont then
      local pts = seg.pts
      local px, py = toMap(pts[1], pts[2])
      first = first or { px, py }
      for i = 3, #pts, 2 do
        local nx, ny = toMap(pts[i], pts[i + 1])
        if In(px, py) or In(nx, ny) then
          Segment(overlayPool, overlay, px * w, py * h, nx * w, ny * h, thick * 2, { 0, 0, 0 }, 0.6)
          Segment(overlayPool, overlay, px * w, py * h, nx * w, ny * h, thick, ns.ORANGE, 1)
        end
        px, py = nx, ny
      end
      last = { px, py }
    end
  end
  if first and In(first[1], first[2]) then PlaceMarker(mapStart, overlay, first[1] * w, first[2] * h) end
  if last and In(last[1], last[2]) then PlaceMarker(mapEnd, overlay, last[1] * w, last[2] * h) end
end

local function SetupMap()
  local canvas = MapCanvas()
  if not canvas then return false end
  if not overlay then
    overlay = CreateFrame("Frame", nil, canvas)
    overlay:SetAllPoints(canvas)
    overlay:SetFrameLevel(math.min(canvas:GetFrameLevel() + 2000, 9000))
    overlayPool = NewPool(overlay)
    mapStart = Marker(overlay, GREEN)
    mapEnd = Marker(overlay, WHITE)
  end
  if not hooked then
    hooked = true
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", V.DrawOnMap) end
    WorldMapFrame:HookScript("OnShow", V.DrawOnMap)
    WorldMapFrame:HookScript("OnHide", function()
      mapRoute = nil
      V.DrawOnMap()
    end)
  end
  return true
end

function V.ShowOnMap(s)
  if not ns.Routes.Has(s) then return ns.Print("This activity has no route.") end
  if InCombatLockdown() then return ns.Print("Can't open the map in combat. Try again after the fight.") end
  if not SetupMap() then return ns.Print("The world map isn't available on this client.") end
  local mapID = s.route.segs[1].map
  if not mapID or not ns.Routes.MapTransform(mapID) then
    return ns.Print("This client doesn't let addons draw on the world map here. The route card still works.")
  end
  mapRoute = s.route
  if OpenWorldMap then OpenWorldMap(mapID)
  elseif ToggleWorldMap and not WorldMapFrame:IsShown() then ToggleWorldMap() end
  if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  C_Timer.After(0, V.DrawOnMap)
end
