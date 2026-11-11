local _, ns = ...
local L = ns.L
local F = ns.F

-- Strava-style route card with its own interactive map (the game's world map
-- is left alone, so this works with any map addon):
--   mouse wheel = zoom, drag = move, left-click = zoom into the zone under
--   the cursor, right-click = go up (zone -> continent -> world).
-- Every part of the route is drawn on whatever map you're looking at; jumps
-- between parts (hearthstone, portals, zeppelins, mounts) are dashed lines.
local V = {}
ns.RouteViewer = V

local CW, CH, PAD = 640, 400, 30   -- map area size and padding when fitting
local MAX_ZOOM = 8                 -- zoom relative to "map fills the card"
local MIN_STEP = 2                 -- pixels: skip route points closer than this on screen
local GREEN, WHITE = { 0.2, 0.9, 0.3 }, { 1, 1, 1 }
local JUMP_COLOR = { 0.9, 0.9, 1.0 }

local Plain = ns.Plain
local BLACK = { 0, 0, 0 }

---------------------------------------------------------------------------
-- Line pools
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
      line = pool.parent:CreateTexture(nil, pool.layer, nil, pool.sub)
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

-- (x, y) from the frame's top-left, y going down
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

local function Dashed(pool, frame, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return end
  local DASH, GAP = 9, 6
  local count = math.min(math.floor(len / (DASH + GAP)) + 1, 200)
  local step = len / count
  for i = 0, count - 1 do
    local t1 = (i * step) / len
    local t2 = math.min((i * step + math.min(DASH, step * 0.6)) / len, 1)
    Segment(pool, frame, x1 + dx * t1, y1 + dy * t1, x1 + dx * t2, y1 + dy * t2, 2, JUMP_COLOR, 0.85)
  end
end

local function Marker(frame, color, size)
  local m = frame:CreateTexture(nil, "OVERLAY", nil, 7)
  m:SetTexture("Interface\\Buttons\\WHITE8X8")
  m:SetSize(size, size)
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
-- Map math (results cached while a card is open)
---------------------------------------------------------------------------
local cache = {}

local function MapInfo(id)
  if not (id and C_Map and C_Map.GetMapInfo) then return nil end
  local key = "i" .. id
  if cache[key] == nil then
    local ok, info = pcall(C_Map.GetMapInfo, id)
    cache[key] = (ok and type(info) == "table") and info or false
  end
  return cache[key] or nil
end

local function ParentOf(id)
  local info = MapInfo(id)
  local p = info and info.parentMapID
  if Plain(p) and p > 0 and p ~= id then return p end
  return nil
end

local function MapName(id)
  local info = MapInfo(id)
  return info and type(info.name) == "string" and info.name or "?"
end

-- World position -> this zone's 0..1 coordinates
local function ZoneTransform(id)
  local key = "z" .. id
  if cache[key] == nil then
    local cont, fn = ns.Routes.MapTransform(id)
    cache[key] = cont and { cont, fn } or false
  end
  local z = cache[key]
  if z then return z[1], z[2] end
end

-- Where a child map sits inside another map (0..1 rectangle)
local function RectOn(child, parent)
  if child == parent then return 0, 1, 0, 1 end
  if not (C_Map and C_Map.GetMapRectOnMap) then return nil end
  local key = "r" .. child .. ">" .. parent
  if cache[key] == nil then
    local ok, x1, x2, y1, y2 = pcall(C_Map.GetMapRectOnMap, child, parent)
    if ok and Plain(x1) and Plain(x2) and Plain(y1) and Plain(y2) and x1 ~= x2 and y1 ~= y2 then
      cache[key] = { x1, x2, y1, y2 }
    else
      cache[key] = false
    end
  end
  local r = cache[key]
  if r then return r[1], r[2], r[3], r[4] end
end

-- The map picture as tiles, plus its size in pixels
local function MapArt(id)
  local key = "a" .. id
  if cache[key] == nil then
    cache[key] = false
    local M = C_Map
    if M and M.GetMapArtLayers and M.GetMapArtLayerTextures then
      local ok, layers = pcall(M.GetMapArtLayers, id)
      local L = ok and layers and layers[1]
      if L and Plain(L.layerWidth) and Plain(L.tileWidth) and L.tileWidth > 0 and L.tileHeight > 0 then
        local ok2, textures = pcall(M.GetMapArtLayerTextures, id, 1)
        if ok2 and textures and #textures > 0 then
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
          cache[key] = { tiles = tiles, w = L.layerWidth, h = L.layerHeight }
        end
      end
    end
  end
  return cache[key] or nil
end

-- Explored areas: the detailed map pieces drawn on top of the blank base map
-- (exactly like the game map; unexplored areas stay blank there too)
local TILE = 256
local function TileFileSize(pixels)
  local size = 16
  while size < pixels do size = size * 2 end
  return size
end

local function Explored(id)
  local key = "e" .. id
  if cache[key] == nil then
    cache[key] = false
    local E = C_MapExplorationInfo
    if E and E.GetExploredMapTextures then
      local ok, list = pcall(E.GetExploredMapTextures, id)
      if ok and type(list) == "table" then
        local pieces = {}
        for _, info in ipairs(list) do
          local w, h, ox, oy = info.textureWidth, info.textureHeight, info.offsetX, info.offsetY
          if not info.isShownByMouseOver and Plain(w) and Plain(h) and Plain(ox) and Plain(oy)
             and type(info.fileDataIDs) == "table" then
            local cols, rows = math.ceil(w / TILE), math.ceil(h / TILE)
            for r = 1, rows do
              for c = 1, cols do
                local file = info.fileDataIDs[(r - 1) * cols + c]
                if file then
                  local pw = (c < cols) and TILE or (w % TILE == 0 and TILE or w % TILE)
                  local ph = (r < rows) and TILE or (h % TILE == 0 and TILE or h % TILE)
                  local fw = (c < cols) and TILE or TileFileSize(pw)
                  local fh = (r < rows) and TILE or TileFileSize(ph)
                  pieces[#pieces + 1] = { file = file, x = ox + (c - 1) * TILE, y = oy + (r - 1) * TILE,
                                          w = pw, h = ph, u = pw / fw, v = ph / fh }
                end
              end
            end
          end
        end
        cache[key] = pieces
      end
    end
  end
  return cache[key] or nil
end

-- A function that puts this route part's points on map M (0..1), or nil
local function SegMapper(seg, M)
  if not seg.map then return nil end
  local cont, toZone = ZoneTransform(seg.map)
  if not toZone or (seg.inst and cont ~= seg.inst) then return nil end
  if seg.map == M then return toZone end
  local x1, x2, y1, y2 = RectOn(seg.map, M)
  if not x1 then return nil end
  return function(a, b)
    local zx, zy = toZone(a, b)
    return x1 + zx * (x2 - x1), y1 + zy * (y2 - y1)
  end
end

-- Bounds of everything drawable on map M; also says whether all parts fit
local function RouteOnMap(route, M)
  local minX, maxX, minY, maxY
  local all = true
  for _, seg in ipairs(route.segs) do
    local f = SegMapper(seg, M)
    if f then
      for i = 1, #seg.pts, ns.Routes.Stride(seg) do
        local x, y = f(seg.pts[i], seg.pts[i + 1])
        minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
        minY, maxY = math.min(minY or y, y), math.max(maxY or y, y)
      end
    else
      all = false
    end
  end
  if minX and (minX < -0.02 or maxX > 1.02 or minY < -0.02 or maxY > 1.02) then all = false end
  return minX, maxX, minY, maxY, all
end

-- Smallest map (zone, then region, continent, world) that shows the whole route
local function DefaultMap(route)
  local main
  for _, seg in ipairs(route.segs) do
    if seg.map and (not main or #seg.pts > #main.pts) then main = seg end
  end
  local M, lastGood = main and main.map, nil
  for _ = 1, 6 do
    if not M then break end
    if MapArt(M) then
      local minX, _, _, _, all = RouteOnMap(route, M)
      if minX then lastGood = M end
      if all then return M end
    end
    M = ParentOf(M)
  end
  return lastGood
end

---------------------------------------------------------------------------
-- The card
---------------------------------------------------------------------------
local card
local view = {} -- mapID, zoom, cx, cy (center in 0..1 of the map)

-- Legend in the bottom-right: only the speed colors this route uses
local function UpdateLegend()
  local y = 6
  for i = #ns.Routes.BANDS, 1, -1 do
    local row = card.legend[i]
    if card.bandsShown and card.bandsShown[i] then
      row:ClearAllPoints()
      row:SetPoint("BOTTOMRIGHT", card.over, "BOTTOMRIGHT", -8, y)
      row:Show()
      y = y + 14
    else
      row:Hide()
    end
  end
end

-- Draw every route part that toPixel can place. toPixel(seg) returns a
-- function (a, b) -> x, y in pixels, or nil if that part can't be shown.
-- Parts in a row are joined by dashed "jump" lines. Returns the skipped parts.
local function DrawRoute(route, toPixel)
  PoolReset(card.outline)
  PoolReset(card.route)
  PoolReset(card.jumps)
  HideMarker(card.startMark)
  HideMarker(card.endMark)

  local layer = card.lineLayer
  local firstPt, lastPt, prevEnd
  local skipped = {}
  local R = ns.Routes
  card.bandsShown = {}
  for si, seg in ipairs(route.segs) do
    local stride = R.Stride(seg)
    local f = #seg.pts >= stride and toPixel(seg)
    if f then
      local pts = seg.pts
      local px, py = f(pts[1], pts[2])
      if si == 1 then firstPt = { px, py } end
      if prevEnd then Dashed(card.jumps, layer, prevEnd[1], prevEnd[2], px, py) end
      local lastStart = #pts - stride + 1
      for i = 1 + stride, #pts, stride do
        local x, y = f(pts[i], pts[i + 1])
        local band = R.PointBand(seg, i)
        local nextBand = i < lastStart and R.PointBand(seg, i + stride) or band
        -- skip points too close together on screen (keeps long routes fast),
        -- but never where the color changes
        if (x - px) ^ 2 + (y - py) ^ 2 >= MIN_STEP * MIN_STEP or i >= lastStart or nextBand ~= band then
          Segment(card.outline, layer, px, py, x, y, 7, BLACK, 0.7)
          Segment(card.route, layer, px, py, x, y, 3.5, R.BandColor(band), 1)
          card.bandsShown[band] = true
          px, py = x, y
        end
      end
      prevEnd = { px, py }
      if si == #route.segs then lastPt = prevEnd end
    else
      prevEnd = nil -- not on this map: no jump line across the gap
      skipped[#skipped + 1] = seg
    end
  end
  if firstPt then ShowMarker(card.startMark, layer, firstPt[1], firstPt[2]) end
  if lastPt then ShowMarker(card.endMark, layer, lastPt[1], lastPt[2]) end
  UpdateLegend()
  return skipped
end

local function Stat(parent, x, label)
  local l = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  l:SetPoint("TOPLEFT", x, -(70 + CH + 14))
  l:SetText(label)
  local v = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
  return v
end

local function CursorInCanvas()
  local x, y = GetCursorPosition()
  local s = card.canvas:GetEffectiveScale()
  return x / s - card.canvas:GetLeft(), card.canvas:GetTop() - y / s
end

-- Size and position of the map for the current view (clamped so it fills the card)
local function Layout()
  local art = MapArt(view.mapID)
  local base = math.max(CW / art.w, CH / art.h)
  local scale = base * view.zoom
  local mapW, mapH = art.w * scale, art.h * scale
  local offX = math.min(0, math.max(CW - mapW, CW / 2 - view.cx * mapW))
  local offY = math.min(0, math.max(CH - mapH, CH / 2 - view.cy * mapH))
  view.cx, view.cy = (CW / 2 - offX) / mapW, (CH / 2 - offY) / mapH
  return art, scale, mapW, mapH, offX, offY
end

local function PlaceContent()
  local _, _, mapW, mapH, offX, offY = Layout()
  local content = card.content
  content:ClearAllPoints()
  content:SetPoint("TOPLEFT", card.canvas, "TOPLEFT", offX, -offY)
  content:SetSize(mapW, mapH)
end

-- Draw tiles, route parts and jumps for the current map and zoom
local EMPTY_ROUTE = { segs = {} }

-- The zone you're standing in (if its map can be drawn)
local function PlayerZone()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and Plain(id) and MapArt(id) then return id end
end

-- Where you are on map M (0..1), or nil (e.g. hidden in dungeons)
local function PlayerOnMap(M)
  local zone = PlayerZone()
  if not zone or not C_Map.GetPlayerMapPosition then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, zone, "player")
  if not ok or type(pos) ~= "table" or not Plain(pos.x) or not Plain(pos.y) then return nil end
  if zone == M then return pos.x, pos.y end
  local x1, x2, y1, y2 = RectOn(zone, M)
  if not x1 then return nil end
  return x1 + pos.x * (x2 - x1), y1 + pos.y * (y2 - y1)
end

-- Yellow "you are here" marker
local function UpdateMe()
  if not card.interactive or not view.mapID then HideMarker(card.meMark) return end
  local x, y = PlayerOnMap(view.mapID)
  if not x then HideMarker(card.meMark) return end
  local _, _, mapW, mapH = Layout()
  ShowMarker(card.meMark, card.lineLayer, x * mapW, y * mapH)
end

local function Render()
  local route = card.activity.route or EMPTY_ROUTE
  local art, scale, mapW, mapH = Layout()
  PlaceContent()

  for i, t in ipairs(art.tiles) do
    local tex = card.tiles[i]
    if not tex then
      tex = card.content:CreateTexture(nil, "BACKGROUND")
      card.tiles[i] = tex
    end
    tex:SetTexture(t.file)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", card.content, "TOPLEFT", t.x * scale, -t.y * scale)
    tex:SetSize(t.w * scale, t.h * scale)
    tex:Show()
  end
  for i = #art.tiles + 1, #card.tiles do card.tiles[i]:Hide() end

  -- explored areas on top of the base map
  local pieces = Explored(view.mapID) or {}
  for i, p in ipairs(pieces) do
    local tex = card.explored[i]
    if not tex then
      tex = card.content:CreateTexture(nil, "BORDER")
      card.explored[i] = tex
    end
    tex:SetTexture(p.file)
    tex:SetTexCoord(0, p.u, 0, p.v)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", card.content, "TOPLEFT", p.x * scale, -p.y * scale)
    tex:SetSize(p.w * scale, p.h * scale)
    tex:Show()
  end
  for i = #pieces + 1, #card.explored do card.explored[i]:Hide() end

  local skipped = DrawRoute(route, function(seg)
    local f = SegMapper(seg, view.mapID)
    if not f then return nil end
    return function(a, b)
      local nx, ny = f(a, b)
      return nx * mapW, ny * mapH
    end
  end)

  -- Breadcrumb: World > Kalimdor > Durotar
  local names, id = {}, view.mapID
  for _ = 1, 6 do
    if not id then break end
    table.insert(names, 1, MapName(id))
    id = ParentOf(id)
  end
  card.mapName:SetText(table.concat(names, "  >  "))
  -- Only mention parts that a bigger map could actually show
  local canGoUp = ParentOf(view.mapID) ~= nil
  local others = 0
  for _, seg in ipairs(skipped) do if seg.map then others = others + 1 end end
  card.hidden:SetText((others > 0 and canGoUp) and
    (others == 1 and L["1 part of this walk is on another map. Right-click to zoom out."] or
      (L["%d parts of this walk are on another map. Right-click to zoom out."]):format(others)) or "")
  card.upBtn:SetEnabled(canGoUp)
  UpdateMe()
end

-- Zoom so everything drawable on this map fits
local function FitRoute()
  local minX, maxX, minY, maxY = RouteOnMap(card.activity.route or EMPTY_ROUTE, view.mapID)
  local art = MapArt(view.mapID)
  if not minX then view.zoom, view.cx, view.cy = 1, 0.5, 0.5 return end
  local base = math.max(CW / art.w, CH / art.h)
  local spanX = math.max((maxX - minX) * art.w * base, 1)
  local spanY = math.max((maxY - minY) * art.h * base, 1)
  view.zoom = math.max(1, math.min(MAX_ZOOM, (CW - PAD * 2) / spanX, (CH - PAD * 2) / spanY))
  view.cx, view.cy = (minX + maxX) / 2, (minY + maxY) / 2
end

local function GoToMap(id, cx, cy, fit)
  if not id or not MapArt(id) then return false end
  view.mapID, view.zoom, view.cx, view.cy = id, 1, cx or 0.5, cy or 0.5
  if fit then FitRoute() end
  Render()
  return true
end

local function ZoomBy(factor, aroundX, aroundY)
  local _, _, mapW, mapH, offX, offY = Layout()
  aroundX, aroundY = aroundX or CW / 2, aroundY or CH / 2
  local px, py = (aroundX - offX) / mapW, (aroundY - offY) / mapH
  local newZoom = math.max(1, math.min(MAX_ZOOM, view.zoom * factor))
  if newZoom == view.zoom then return end
  local ratio = newZoom / view.zoom
  view.zoom = newZoom
  -- keep the point under the cursor in place
  local newW, newH = mapW * ratio, mapH * ratio
  local newOffX, newOffY = aroundX - px * newW, aroundY - py * newH
  view.cx, view.cy = (CW / 2 - newOffX) / newW, (CH / 2 - newOffY) / newH
  Render()
end

local function ZoomOutToParent()
  local parent = ParentOf(view.mapID)
  if not parent or not MapArt(parent) then return end
  local x1, x2, y1, y2 = RectOn(view.mapID, parent)
  if x1 then
    GoToMap(parent, x1 + view.cx * (x2 - x1), y1 + view.cy * (y2 - y1))
  else
    GoToMap(parent)
  end
end

local function ZoomIntoChildAt(cx, cy)
  local _, _, mapW, mapH, offX, offY = Layout()
  local nx, ny = (cx - offX) / mapW, (cy - offY) / mapH
  if not (C_Map and C_Map.GetMapInfoAtPosition) then return ZoomBy(1.6, cx, cy) end
  local ok, info = pcall(C_Map.GetMapInfoAtPosition, view.mapID, nx, ny)
  local child = ok and info and Plain(info.mapID) and info.mapID
  if child and child ~= view.mapID and MapArt(child) then
    local x1, x2, y1, y2 = RectOn(child, view.mapID)
    if x1 then
      return GoToMap(child, (nx - x1) / (x2 - x1), (ny - y1) / (y2 - y1))
    end
    return GoToMap(child)
  end
  ZoomBy(1.6, cx, cy)
end

local function WorldMap()
  local id, top = view.mapID, view.mapID
  for _ = 1, 6 do
    local p = ParentOf(id)
    if not p or not MapArt(p) then break end
    top, id = p, p
  end
  if top ~= view.mapID then GoToMap(top, nil, nil, true) end
end

local function BuildCard()
  card = ns.CreatePanel("AWSRouteCard")
  card:SetSize(CW + 40, CH + 190)
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
  card.sub:SetWidth(CW)
  card.sub:SetJustifyH("LEFT")
  card.sub:SetWordWrap(false)
  card.sub:SetTextColor(0.75, 0.75, 0.75)

  card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
  card.close:SetPoint("TOPRIGHT", -2, -2)

  -- Map area
  local canvas = CreateFrame("Frame", nil, card)
  canvas:SetSize(CW, CH)
  canvas:SetPoint("TOPLEFT", 20, -70)
  if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
  local bg = canvas:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.09, 0.10, 0.12, 1)
  card.canvas = canvas

  local content = CreateFrame("Frame", nil, canvas)
  content:SetPoint("TOPLEFT")
  content:SetSize(CW, CH)
  card.content = content
  card.tiles = {}
  card.explored = {}
  local shade = content:CreateTexture(nil, "ARTWORK")
  shade:SetAllPoints()
  shade:SetTexture("Interface\\Buttons\\WHITE8X8")
  shade:SetVertexColor(0, 0, 0, 0.2)

  local lineLayer = CreateFrame("Frame", nil, content)
  lineLayer:SetAllPoints()
  lineLayer:SetFrameLevel(content:GetFrameLevel() + 5)
  card.lineLayer = lineLayer
  card.jumps = NewPool(lineLayer, "ARTWORK", 0)
  card.outline = NewPool(lineLayer, "ARTWORK", 2)
  card.route = NewPool(lineLayer, "OVERLAY", 1)
  card.startMark = Marker(lineLayer, GREEN, 10)
  card.endMark = Marker(lineLayer, WHITE, 10)
  card.meMark = Marker(lineLayer, { 1, 0.82, 0 }, 9)

  -- Overlay: map name, hint, controls
  local over = CreateFrame("Frame", nil, canvas)
  over:SetAllPoints()
  over:SetFrameLevel(lineLayer:GetFrameLevel() + 10)
  card.over = over
  local nameBg = over:CreateTexture(nil, "BACKGROUND")
  nameBg:SetTexture("Interface\\Buttons\\WHITE8X8")
  nameBg:SetVertexColor(0, 0, 0, 0.55)
  nameBg:SetPoint("TOPLEFT")
  nameBg:SetPoint("TOPRIGHT")
  nameBg:SetHeight(22)
  card.mapName = over:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  card.mapName:SetPoint("TOPLEFT", 8, -4)
  card.hint = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  card.hint:SetPoint("BOTTOMLEFT", 8, 6)
  card.hint:SetText(L["Scroll: zoom   Drag: move   Click: zoom into zone   Right-click: zoom out"])
  card.hint:SetTextColor(0.85, 0.85, 0.85)
  card.hidden = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  card.hidden:SetPoint("BOTTOMLEFT", card.hint, "TOPLEFT", 0, 3)
  card.hidden:SetTextColor(1, 0.82, 0)
  card.legend = {}
  for i, band in ipairs(ns.Routes.BANDS) do
    local row = CreateFrame("Frame", nil, over)
    row:SetSize(140, 12)
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT")
    label:SetText(L[band.label])
    local swatch = row:CreateTexture(nil, "OVERLAY")
    swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
    swatch:SetSize(16, 4)
    swatch:SetPoint("RIGHT", label, "LEFT", -5, 0)
    swatch:SetVertexColor(unpack(band.color))
    row.label = label
    row:Hide()
    card.legend[i] = row
  end
  card.empty = over:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  card.empty:SetPoint("CENTER")
  card.empty:SetWidth(CW - 60)

  local function Ctl(text, width, fn)
    local b = ns.SmallButton(over, text, width, fn)
    b:SetHeight(18)
    return b
  end
  card.worldBtn = Ctl(L["World"], 56, WorldMap)
  card.worldBtn:SetPoint("TOPRIGHT", -4, -2)
  card.upBtn = Ctl(L["Up"], 40, ZoomOutToParent)
  card.upBtn:SetPoint("RIGHT", card.worldBtn, "LEFT", -2, 0)
  card.fitBtn = Ctl(L["Fit route"], 70, function() FitRoute() Render() end)
  card.fitBtn:SetPoint("RIGHT", card.upBtn, "LEFT", -2, 0)
  card.plusBtn = Ctl("+", 24, function() ZoomBy(1.5) end)
  card.plusBtn:SetPoint("RIGHT", card.fitBtn, "LEFT", -2, 0)
  card.minusBtn = Ctl("-", 24, function() ZoomBy(1 / 1.5) end)
  card.minusBtn:SetPoint("RIGHT", card.plusBtn, "LEFT", -2, 0)
  -- Target icon: back to the zone you're in, centered on you
  local zoneBtn = CreateFrame("Button", nil, over)
  zoneBtn:SetSize(20, 20)
  zoneBtn:SetPoint("RIGHT", card.minusBtn, "LEFT", -4, 0)
  local zbg = zoneBtn:CreateTexture(nil, "BACKGROUND")
  zbg:SetAllPoints()
  zbg:SetTexture("Interface\\Buttons\\WHITE8X8")
  zbg:SetVertexColor(0, 0, 0, 0.6)
  zoneBtn:SetNormalTexture("Interface\\CURSOR\\Crosshairs")
  zoneBtn:GetNormalTexture():SetVertexColor(1, 0.82, 0)
  zoneBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  zoneBtn:SetScript("OnClick", function() V.GoToMyZone() end)
  zoneBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(L["Go to my position"])
    GameTooltip:Show()
  end)
  zoneBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  card.zoneBtn = zoneBtn
  card.controls = { card.worldBtn, card.upBtn, card.fitBtn, card.plusBtn, card.minusBtn, card.zoneBtn }

  -- Mouse: wheel zoom, drag to move, click to zoom in, right-click to zoom out
  canvas:EnableMouse(true)
  canvas:EnableMouseWheel(true)
  canvas:SetScript("OnMouseWheel", function(_, delta)
    if not card.interactive then return end
    local x, y = CursorInCanvas()
    ZoomBy(delta > 0 and 1.25 or 1 / 1.25, x, y)
  end)
  canvas:SetScript("OnMouseDown", function(self, button)
    if not card.interactive or button ~= "LeftButton" then return end
    local x, y = CursorInCanvas()
    self.drag = { x = x, y = y, cx = view.cx, cy = view.cy, moved = false }
    self:SetScript("OnUpdate", function()
      local d = self.drag
      if not d then return end
      local nx, ny = CursorInCanvas()
      if math.abs(nx - d.x) + math.abs(ny - d.y) > 4 then d.moved = true end
      if d.moved then
        local _, _, mapW, mapH = Layout()
        view.cx = d.cx - (nx - d.x) / mapW
        view.cy = d.cy - (ny - d.y) / mapH
        PlaceContent()
      end
    end)
  end)
  canvas:SetScript("OnMouseUp", function(self, button)
    if not card.interactive then return end
    if button == "RightButton" then ZoomOutToParent() return end
    local d = self.drag
    self.drag = nil
    self:SetScript("OnUpdate", nil)
    if d and not d.moved then ZoomIntoChildAt(d.x, d.y) end
  end)

  card.dist = Stat(card, 20, L["Distance"])
  card.steps = Stat(card, 180, L["Steps"])
  card.time = Stat(card, 340, L["Moving time"])
  card.pace = Stat(card, 500, L["Avg pace"])

  card.shotBtn = ns.SmallButton(card, L["Screenshot"], 120, function() V.Screenshot() end)
  card.shotBtn:SetPoint("BOTTOMLEFT", 20, 14)
  card.shareBtn = ns.SmallButton(card, L["Quick Share"], 120, function()
    ns.QuickShare.Open(card.shareBtn, ns.QuickShare.ActivityText(card.activity))
  end)
  card.shareBtn:SetPoint("LEFT", card.shotBtn, "RIGHT", 8, 0)
end

-- No usable map on this client: draw just the route's shape, scaled to fit
local function DrawShapeOnly(route)
  card.content:ClearAllPoints()
  card.content:SetPoint("TOPLEFT")
  card.content:SetSize(CW, CH)
  for _, t in ipairs(card.tiles) do t:Hide() end
  for _, t in ipairs(card.explored) do t:Hide() end

  -- Coordinates only line up within one continent, so show the main one
  local main
  for _, seg in ipairs(route.segs) do
    if not main or #seg.pts > #main.pts then main = seg end
  end
  local function Same(seg) return seg.inst == main.inst end
  local minA, maxA, minB, maxB = ns.Routes.Bounds(route, Same)
  local spanA, spanB = math.max(maxA - minA, 1), math.max(maxB - minB, 1)
  local scale = math.min((CW - PAD * 2) / spanB, (CH - PAD * 2) / spanA)
  local offX, offY = (CW - spanB * scale) / 2, (CH - spanA * scale) / 2
  local function toXY(a, b) return offX + (maxB - b) * scale, offY + (maxA - a) * scale end

  DrawRoute(route, function(seg) return Same(seg) and toXY or nil end)
  card.mapName:SetText(L["Route shape (map not available)"])
end

local function FillStats(s)
  local live = s == ns.cdb.current
  card.title:SetText((card.owner or UnitName("player")) .. (live and L["  -  walking now"] or ""))
  local zones = s.zones and #s.zones > 0 and table.concat(s.zones, ", ") or "Azeroth"
  card.sub:SetText(F.Date(s.start or s.id) .. "   " .. zones)
  card.dist:SetText(F.Distance(s.distance))
  card.steps:SetText(F.Number(s.steps))
  card.time:SetText(F.Time(s.moving))
  card.pace:SetText(F.Pace(s.moving, s.distance))
end

-- While the card shows the walk in progress: stats every second, and the
-- route redrawn every few seconds as it grows (not while you drag the map)
local liveAcc, routeAcc = 0, 0
local function LiveUpdate(_, elapsed)
  local s = card.activity
  liveAcc, routeAcc = liveAcc + elapsed, routeAcc + elapsed
  if liveAcc >= 1 then
    liveAcc = 0
    UpdateMe() -- your position marker follows you
    if s and s == ns.cdb.current then FillStats(s) end
  end
  if not s or s ~= ns.cdb.current then return end
  if routeAcc >= 5 and not card.canvas.drag and ns.Routes.Has(s) then
    routeAcc = 0
    local n = s.route.n or 0
    if n ~= card.drawnPoints then
      card.drawnPoints = n
      if card.interactive then Render() else V.Open(s) end
    end
  end
end

-- Stop a map drag if the card closes mid-drag
local function OnCardHide()
  card.canvas.drag = nil
  card.canvas:SetScript("OnUpdate", nil)
end

-- owner: a friend's display name (nil = your own activity).
-- emptyText: message shown on the map when there's no route (yet).
function V.Open(s, owner, emptyText)
  if not s then return ns.Print(L["No activity to show yet."]) end
  if not card then
    BuildCard()
    card:SetScript("OnUpdate", LiveUpdate)
    card:SetScript("OnHide", OnCardHide)
  end
  wipe(cache)
  card.activity, card.owner = s, owner
  card.drawnPoints = s.route and s.route.n
  FillStats(s)

  PoolReset(card.outline); PoolReset(card.route); PoolReset(card.jumps)
  HideMarker(card.startMark); HideMarker(card.endMark); HideMarker(card.meMark)
  card.hidden:SetText("")
  card.interactive = false

  local hasRoute = ns.Routes.Has(s)
  -- Your own walks open on the zone you're in; a friend's route opens fitted
  -- to their walk. Without a zone (e.g. in a dungeon) fit the route.
  local zone = not (owner and hasRoute) and PlayerZone() or nil
  local M = zone or (hasRoute and DefaultMap(s.route))
  local function Controls(show)
    for _, b in ipairs(card.controls) do b:SetShown(show) end
    card.hint:SetShown(show)
  end

  if M then
    card.interactive = true
    Controls(true)
    card.empty:SetText(emptyText or L["No route recorded for this activity.\nRoutes are recorded outdoors only."])
    card.empty:SetShown(not hasRoute)
    if zone then GoToMap(zone, PlayerOnMap(zone)) else GoToMap(M, nil, nil, true) end
  elseif hasRoute then
    card.empty:Hide()
    Controls(false)
    DrawShapeOnly(s.route)
  else
    for _, t in ipairs(card.tiles) do t:Hide() end
    for _, t in ipairs(card.explored) do t:Hide() end
    card.mapName:SetText("")
    card.empty:SetText(emptyText or L["No route for this activity.\nRoutes are recorded outdoors only: the game hides your position in dungeons. Older activities keep only their numbers."])
    card.empty:Show()
    Controls(false)
  end
  card:Show()
end

-- A friend's activity from the Feed: ask them for the route if we don't have it
function V.OpenFriend(item, owner)
  if ns.Routes.Has(item) then return V.Open(item, owner) end
  V.Open(item, owner, (L["Loading route from %s..."]):format(owner))
  ns.Social.RequestRoute(item,
    function(got, total)
      if card.activity == item and card:IsShown() then
        card.empty:SetText((L["Loading route from %s...  %d / %d"]):format(owner, got, total))
      end
    end,
    function(route, reason)
      if card.activity ~= item or not card:IsShown() then return end
      if route then return V.Open(item, owner) end
      if reason == "offline" then
        V.Open(item, owner, (L["%s isn't online right now, so the route can't be loaded.\nTry again when they are."]):format(owner))
      else
        V.Open(item, owner, (L["%s has no route for this activity.\n(Walked in a dungeon, or before version 2.3.)"]):format(owner))
      end
    end)
end

-- "My zone" button: back to the zone you're in, centered on you
function V.GoToMyZone()
  if not card or not card.interactive then return end
  local zone = PlayerZone()
  if not zone then
    return ns.Print(L["Your current zone's map isn't available here (for example inside dungeons)."])
  end
  GoToMap(zone, PlayerOnMap(zone))
end

-- Screenshot of the card (buttons and hints hidden for a clean picture)
function V.Screenshot()
  if not card or not card:IsShown() then return end
  if not Screenshot then return ns.Print(L["Screenshots aren't available on this client."]) end
  local hide = { card.shotBtn, card.shareBtn, card.close, card.hint }
  for _, b in ipairs(card.controls) do hide[#hide + 1] = b end
  local wasShown = {}
  for i, f in ipairs(hide) do wasShown[i] = f:IsShown(); f:Hide() end
  C_Timer.After(0.1, function()
    Screenshot()
    C_Timer.After(0.3, function()
      for i, f in ipairs(hide) do if wasShown[i] then f:Show() end end
    end)
    ns.Print(L["Screenshot saved to your WoW Screenshots folder."])
  end)
end
