local _, ns = ...
local F = ns.F

-- Strava-style route card: your route drawn over the zone map, with stats,
-- a screenshot button and Quick Share. (The regular world map is left alone,
-- so it works with any map addon.)
local V = {}
ns.RouteViewer = V

local CANVAS_W, CANVAS_H, PAD = 500, 280, 24
local MAX_ZOOM = 3          -- don't blow the map art up more than this (it gets blurry)
local GREEN, WHITE = { 0.2, 0.9, 0.3 }, { 1, 1, 1 }

local IsSecret = issecretvalue or function() return false end
local function Plain(v) return type(v) == "number" and not IsSecret(v) end

---------------------------------------------------------------------------
-- Line pools (outline lines are drawn on a lower layer than the route)
---------------------------------------------------------------------------
local function NewPool(parent, layer, sublevel)
  return { parent = parent, layer = layer, sub = sublevel, items = {}, used = 0 }
end

local function PoolLine(pool, thickness, color, alpha)
  pool.used = pool.used + 1
  local line = pool.items[pool.used]
  if not line then
    if pool.parent.CreateLine then
      line = pool.parent:CreateLine(nil, pool.layer, nil, pool.sub)
    else
      line = pool.parent:CreateTexture(nil, pool.layer, nil, pool.sub) -- fallback: dots
      line.isDot = true
    end
    pool.items[pool.used] = line
  end
  if line.isDot then line:SetSize(thickness, thickness) else line:SetThickness(thickness) end
  line:SetColorTexture(color[1], color[2], color[3], alpha or 1)
  line:Show()
  return line
end

local function PoolReset(pool)
  for i = 1, pool.used do pool.items[i]:Hide() end
  pool.used = 0
end

-- (x, y) measured from the frame's top-left, y going down
local function Segment(pool, frame, x1, y1, x2, y2, thickness, color, alpha)
  local line = PoolLine(pool, thickness, color, alpha)
  if line.isDot then
    line:ClearAllPoints()
    line:SetPoint("CENTER", frame, "TOPLEFT", x2, -y2)
  else
    line:SetStartPoint("TOPLEFT", frame, x1, -y1)
    line:SetEndPoint("TOPLEFT", frame, x2, -y2)
  end
end

local function Marker(frame, color)
  local m = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  m:SetTexture("Interface\\Buttons\\WHITE8X8")
  m:SetSize(10, 10)
  m:SetVertexColor(unpack(color))
  local border = frame:CreateTexture(nil, "OVERLAY", nil, 6)
  border:SetTexture("Interface\\Buttons\\WHITE8X8")
  border:SetVertexColor(0, 0, 0, 1)
  border:SetPoint("TOPLEFT", m, -2, 2)
  border:SetPoint("BOTTOMRIGHT", m, 2, -2)
  m.border = border
  return m
end

local function ShowMarker(m, frame, x, y)
  m:ClearAllPoints()
  m:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
  m:Show(); m.border:Show()
end

local function HideMarker(m) m:Hide(); m.border:Hide() end

---------------------------------------------------------------------------
-- Map helpers: which map to show, and its picture
---------------------------------------------------------------------------
-- Bounds of the route in a map's 0..1 coordinates (only segments on that continent)
local function MapBounds(route, cont, toMap)
  local minX, maxX, minY, maxY, other
  for _, seg in ipairs(route.segs) do
    if seg.inst == nil or seg.inst == cont then
      for i = 1, #seg.pts, 2 do
        local x, y = toMap(seg.pts[i], seg.pts[i + 1])
        minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
        minY, maxY = math.min(minY or y, y), math.max(maxY or y, y)
      end
    else
      other = true
    end
  end
  return minX, maxX, minY, maxY, other
end

-- Start at the zone where most of the walk was; go up to the region map if
-- the route doesn't fit in that zone.
local function PickMap(route)
  local main
  for _, seg in ipairs(route.segs) do
    if not main or #seg.pts > #main.pts then main = seg end
  end
  local mapID, fallback = main and main.map, nil
  for _ = 1, 4 do
    if not mapID then break end
    local cont, toMap = ns.Routes.MapTransform(mapID)
    if cont and (main.inst == nil or cont == main.inst) then
      local minX, maxX, minY, maxY, other = MapBounds(route, cont, toMap)
      local pick = { mapID = mapID, cont = cont, toMap = toMap, minX = minX, maxX = maxX, minY = minY,
                     maxY = maxY, other = other }
      fallback = fallback or pick
      if minX and minX >= -0.02 and maxX <= 1.02 and minY >= -0.02 and maxY <= 1.02 then return pick end
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    mapID = ok and info and Plain(info.parentMapID) and info.parentMapID > 0 and info.parentMapID or nil
  end
  return fallback
end

-- The map picture as a list of tiles: { file, x, y, w, h } plus its full size
local function MapArt(mapID)
  local M = C_Map
  if not (M and M.GetMapArtLayers and M.GetMapArtLayerTextures) then return nil end
  local ok, layers = pcall(M.GetMapArtLayers, mapID)
  local L = ok and layers and layers[1]
  if not L or not Plain(L.layerWidth) or not Plain(L.tileWidth) or L.tileWidth <= 0 then return nil end
  local ok2, textures = pcall(M.GetMapArtLayerTextures, mapID, 1)
  if not ok2 or not textures or #textures == 0 then return nil end
  local cols = math.ceil(L.layerWidth / L.tileWidth)
  local rows = math.ceil(L.layerHeight / L.tileHeight)
  local tiles = {}
  for r = 1, rows do
    for c = 1, cols do
      local file = textures[(r - 1) * cols + c]
      if file then
        tiles[#tiles + 1] = { file = file, x = (c - 1) * L.tileWidth, y = (r - 1) * L.tileHeight,
                              w = L.tileWidth, h = L.tileHeight }
      end
    end
  end
  return tiles, L.layerWidth, L.layerHeight
end

---------------------------------------------------------------------------
-- The card
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

  -- Canvas: dark background with a faint grid (used when no map is available)
  local canvas = CreateFrame("Frame", nil, card)
  canvas:SetSize(CANVAS_W, CANVAS_H)
  canvas:SetPoint("TOPLEFT", 20, -70)
  if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
  local bg = canvas:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.09, 0.10, 0.12, 1)
  card.grid = {}
  for i = 1, 9 do
    local v = canvas:CreateTexture(nil, "BORDER")
    v:SetTexture("Interface\\Buttons\\WHITE8X8")
    v:SetVertexColor(1, 1, 1, 0.04)
    v:SetSize(1, CANVAS_H)
    v:SetPoint("TOPLEFT", i * CANVAS_W / 10, 0)
    card.grid[#card.grid + 1] = v
  end
  for i = 1, 5 do
    local h = canvas:CreateTexture(nil, "BORDER")
    h:SetTexture("Interface\\Buttons\\WHITE8X8")
    h:SetVertexColor(1, 1, 1, 0.04)
    h:SetSize(CANVAS_W, 1)
    h:SetPoint("TOPLEFT", 0, -i * CANVAS_H / 6)
    card.grid[#card.grid + 1] = h
  end
  card.canvas = canvas

  -- Map picture layer (zone art tiles), slightly darkened so the route stands out
  local mapLayer = CreateFrame("Frame", nil, canvas)
  mapLayer:SetPoint("TOPLEFT")
  mapLayer:SetSize(1, 1)
  card.mapLayer = mapLayer
  card.tiles = {}
  local shade = mapLayer:CreateTexture(nil, "ARTWORK") -- above the map tiles
  shade:SetAllPoints(canvas)
  shade:SetTexture("Interface\\Buttons\\WHITE8X8")
  shade:SetVertexColor(0, 0, 0, 0.25)
  card.shade = shade

  -- Route layer above the map
  local lines = CreateFrame("Frame", nil, canvas)
  lines:SetAllPoints()
  lines:SetFrameLevel(mapLayer:GetFrameLevel() + 5)
  card.lines = lines
  card.outline = NewPool(lines, "ARTWORK", 1)
  card.route = NewPool(lines, "OVERLAY", 1)
  card.startMark = Marker(lines, GREEN)
  card.endMark = Marker(lines, WHITE)
  card.empty = lines:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  card.empty:SetPoint("CENTER")
  card.empty:SetWidth(CANVAS_W - 40)
  card.note = lines:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  card.note:SetPoint("BOTTOMRIGHT", -6, 5)

  card.dist = Stat(card, 20, "Distance")
  card.steps = Stat(card, 150, "Steps")
  card.time = Stat(card, 270, "Moving time")
  card.pace = Stat(card, 390, "Avg pace")

  card.shotBtn = ns.SmallButton(card, "Screenshot", 120, function() V.Screenshot() end)
  card.shotBtn:SetPoint("BOTTOMLEFT", 20, 14)
  card.shareBtn = ns.SmallButton(card, "Quick Share", 120, function()
    ns.QuickShare.Open(card.shareBtn, ns.QuickShare.ActivityText(card.activity))
  end)
  card.shareBtn:SetPoint("LEFT", card.shotBtn, "RIGHT", 8, 0)
end

local function ClearCard()
  PoolReset(card.outline)
  PoolReset(card.route)
  HideMarker(card.startMark)
  HideMarker(card.endMark)
  for _, t in ipairs(card.tiles) do t:Hide() end
  card.shade:Hide()
  card.note:SetText("")
  for _, g in ipairs(card.grid) do g:Show() end
end

-- Draw the route through toXY(a, b) -> canvas x, y
local function DrawLines(route, toXY, onlyCont)
  local first, last
  for pass = 1, 2 do
    for _, seg in ipairs(route.segs) do
      if not onlyCont or seg.inst == nil or seg.inst == onlyCont then
        local pts = seg.pts
        local px, py = toXY(pts[1], pts[2])
        if pass == 2 and not first then first = { px, py } end
        for i = 3, #pts, 2 do
          local x, y = toXY(pts[i], pts[i + 1])
          if pass == 1 then
            Segment(card.outline, card.lines, px, py, x, y, 7, { 0, 0, 0 }, 0.75)
          else
            Segment(card.route, card.lines, px, py, x, y, 3.5, ns.ORANGE, 1)
          end
          px, py = x, y
        end
        if pass == 2 then last = { px, py } end
      end
    end
  end
  if first then ShowMarker(card.startMark, card.lines, first[1], first[2]) end
  if last then ShowMarker(card.endMark, card.lines, last[1], last[2]) end
end

-- Route on top of the zone map. Returns false if the map can't be used.
local function DrawOnZoneMap(route)
  local pick = PickMap(route)
  if not pick or not pick.minX then return false end
  local tiles, artW, artH = MapArt(pick.mapID)
  if not tiles then return false end

  -- Zoom so the route fills the card, but keep the map covering the whole card
  local spanX = math.max((pick.maxX - pick.minX) * artW, 1)
  local spanY = math.max((pick.maxY - pick.minY) * artH, 1)
  local zoom = math.min((CANVAS_W - PAD * 2) / spanX, (CANVAS_H - PAD * 2) / spanY, MAX_ZOOM)
  zoom = math.max(zoom, CANVAS_W / artW, CANVAS_H / artH)
  local mapW, mapH = artW * zoom, artH * zoom
  local cx = (pick.minX + pick.maxX) / 2 * mapW
  local cy = (pick.minY + pick.maxY) / 2 * mapH
  local offX = math.min(0, math.max(CANVAS_W - mapW, CANVAS_W / 2 - cx))
  local offY = math.min(0, math.max(CANVAS_H - mapH, CANVAS_H / 2 - cy))

  local layer = card.mapLayer
  layer:ClearAllPoints()
  layer:SetPoint("TOPLEFT", card.canvas, "TOPLEFT", offX, -offY)
  layer:SetSize(mapW, mapH)
  for i, t in ipairs(tiles) do
    local tex = card.tiles[i]
    if not tex then
      tex = layer:CreateTexture(nil, "BACKGROUND")
      card.tiles[i] = tex
    end
    tex:SetTexture(t.file)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", layer, "TOPLEFT", t.x * zoom, -t.y * zoom)
    tex:SetSize(t.w * zoom, t.h * zoom)
    tex:Show()
  end
  for _, g in ipairs(card.grid) do g:Hide() end
  card.shade:Show()

  local toMap = pick.toMap
  DrawLines(route, function(a, b)
    local nx, ny = toMap(a, b)
    return offX + nx * mapW, offY + ny * mapH
  end, pick.cont)
  local name = ""
  local ok, info = pcall(C_Map.GetMapInfo, pick.mapID)
  if ok and info and type(info.name) == "string" then name = info.name end
  card.note:SetText(name .. (pick.other and "  (part of this walk was on another continent)" or ""))
  return true
end

-- Fallback: just the route's shape on the dark grid
local function DrawShapeOnly(route)
  local minA, maxA, minB, maxB = ns.Routes.Bounds(route)
  local spanA, spanB = math.max(maxA - minA, 1), math.max(maxB - minB, 1)
  local scale = math.min((CANVAS_W - PAD * 2) / spanB, (CANVAS_H - PAD * 2) / spanA)
  local offX = (CANVAS_W - spanB * scale) / 2
  local offY = (CANVAS_H - spanA * scale) / 2
  DrawLines(route, function(a, b) return offX + (maxB - b) * scale, offY + (maxA - a) * scale end)
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

  ClearCard()
  if not ns.Routes.Has(s) then
    card.empty:SetText("No route for this activity.\nRoutes are recorded outdoors only: the game hides your " ..
      "position in dungeons. Older activities keep only their numbers.")
    card.empty:Show()
  else
    card.empty:Hide()
    if not DrawOnZoneMap(s.route) then DrawShapeOnly(s.route) end
  end
  card:Show()
end

-- Screenshot of the card (buttons hidden for a clean picture)
function V.Screenshot()
  if not card or not card:IsShown() then return end
  if not Screenshot then return ns.Print("Screenshots aren't available on this client.") end
  local buttons = { card.shotBtn, card.shareBtn, card.close }
  for _, b in ipairs(buttons) do b:Hide() end
  C_Timer.After(0.1, function()
    Screenshot()
    C_Timer.After(0.3, function() for _, b in ipairs(buttons) do b:Show() end end)
    ns.Print("Screenshot saved to your WoW Screenshots folder.")
  end)
end
