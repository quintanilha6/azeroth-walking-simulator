local _, ns = ...

-- Routes: the path you walked, recorded from your world position outdoors.
-- A route is stored on its activity as:
--   s.route = { segs = { { inst = continent, map = uiMapID, v = 2, pts = { a1, b1, band1, a2, b2, band2, ... } } } }
-- (a, b) are the first two values of UnitPosition("player"); band is the
-- speed band (walk, run, fast, mount 60%, mount 100%). Routes saved before
-- 2.4.0 have no v and store only a, b.
-- A new segment starts after a big jump (flight path, hearthstone, portal).

local R = {}
ns.Routes = R

local MIN_GAP = 8          -- yards between saved points
local BREAK_GAP = 150      -- a jump bigger than this starts a new segment
local MAX_POINTS = 6000    -- per activity while recording
local MAX_SEGMENTS = 60
local SIMPLIFY_TOLERANCE = 2.5 -- yards; how much detail to drop on finish
local SHARE_POINTS = 200   -- routes sent to friends are simplified to about this many points
local KEEP_ROUTES = 30     -- only the newest activities keep their route

local Plain = ns.Plain

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

---------------------------------------------------------------------------
-- Speed bands (yards per second), the same for everyone
---------------------------------------------------------------------------
R.BANDS = {
  { max = 4,    key = "walk",    label = "Walking",            color = { 1.00, 0.85, 0.20 } },
  { max = 8,    key = "run",     label = "Running",            color = { 0.99, 0.45, 0.05 } },
  { max = 10.5, key = "fast",    label = "Fast on foot",       color = { 0.90, 0.15, 0.15 } },
  { max = 12.5, key = "mount60", label = "Mount (60%)",        color = { 0.25, 0.55, 1.00 } },
  { max = 1e9,  key = "mount100", label = "Mount (100%)",      color = { 0.70, 0.35, 1.00 } },
  -- not a speed: moving without your own input (drawn dashed, never counted as steps)
  { key = "auto", label = "Auto-run / follow", color = { 0.30, 0.85, 1.00 }, dashed = true },
}
R.SPEED_BANDS = 5
R.AUTO_BAND = 6
local RUN_BAND = 2

function R.Band(speed)
  if not Plain(speed) then return RUN_BAND end
  for i = 1, R.SPEED_BANDS do
    if speed <= R.BANDS[i].max then return i end
  end
  return R.SPEED_BANDS
end

function R.BandColor(band) return (R.BANDS[band or RUN_BAND] or R.BANDS[RUN_BAND]).color end

-- Values stored per point in this segment (old routes: 2, new: 3)
function R.Stride(seg) return seg.v == 2 and 3 or 2 end

-- Band of the point starting at index i (old routes: running)
function R.PointBand(seg, i)
  if seg.v == 2 then return seg.pts[i + 2] or RUN_BAND end
  return RUN_BAND
end

local function BestMap()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and Plain(id) then return id end
  return nil
end

---------------------------------------------------------------------------
-- Recording (walking: from the step counter; mounted: drawn only, no steps)
---------------------------------------------------------------------------
-- band: optional, e.g. R.AUTO_BAND for auto-run; otherwise from the speed
function R.Record(s, a, b, inst, speed, band)
  if not s or not Plain(a) or not Plain(b) then return end
  s.route = s.route or { segs = {}, n = 0 }
  local route = s.route
  -- Long walks: simplify what's recorded so far instead of stopping
  if (route.n or 0) >= MAX_POINTS then
    R.Compact(route)
    if route.n >= MAX_POINTS * 0.8 then return end -- couldn't free enough room
  end

  band = band or R.Band(speed)
  local segs = route.segs
  local seg = segs[#segs]
  if seg and seg.inst == inst and seg.v == 2 then
    local pts = seg.pts
    local la, lb, lband = pts[#pts - 2], pts[#pts - 1], pts[#pts]
    local d = math.sqrt((a - la) ^ 2 + (b - lb) ^ 2)
    if d > BREAK_GAP then
      seg = nil
    elseif d < MIN_GAP and band == lband then
      return
    end
  else
    seg = nil
  end
  if not seg then
    if #segs >= MAX_SEGMENTS then return end
    seg = { inst = inst, map = BestMap(), v = 2, pts = {} }
    table.insert(segs, seg)
  end
  local pts = seg.pts
  pts[#pts + 1] = Round(a)
  pts[#pts + 1] = Round(b)
  pts[#pts + 1] = band
  route.n = (route.n or 0) + 1
end

---------------------------------------------------------------------------
-- Simplify (Douglas-Peucker). Points where the speed band changes are always
-- kept, so the colors stay in the right places.
---------------------------------------------------------------------------
local function PerpDistSq(pa, pb, aa, ab, ba, bb)
  local da, db = ba - aa, bb - ab
  local len = da * da + db * db
  if len == 0 then return (pa - aa) ^ 2 + (pb - ab) ^ 2 end
  local t = ((pa - aa) * da + (pb - ab) * db) / len
  t = math.max(0, math.min(1, t))
  local qa, qb = aa + t * da, ab + t * db
  return (pa - qa) ^ 2 + (pb - qb) ^ 2
end

-- looseBands: allow dropping points where the speed band changes (for sharing)
local function Simplify(pts, tol, stride, looseBands)
  local n = #pts / stride
  if n <= 2 then return pts end
  local function A(i) return pts[(i - 1) * stride + 1] end
  local function B(i) return pts[(i - 1) * stride + 2] end
  local keep = { [1] = true, [n] = true }
  if stride == 3 and not looseBands then
    for i = 2, n - 1 do
      local band = pts[(i - 1) * 3 + 3]
      if band ~= pts[(i - 2) * 3 + 3] or band ~= pts[i * 3 + 3] then keep[i] = true end
    end
  end
  local stack = { { 1, n } }
  local tolSq = tol * tol
  while #stack > 0 do
    local range = table.remove(stack)
    local first, last = range[1], range[2]
    local maxD, idx = 0, nil
    local aa, ab, ba, bb = A(first), B(first), A(last), B(last)
    for i = first + 1, last - 1 do
      local d = PerpDistSq(A(i), B(i), aa, ab, ba, bb)
      if d > maxD then maxD, idx = d, i end
    end
    if idx and maxD > tolSq then
      keep[idx] = true
      table.insert(stack, { first, idx })
      table.insert(stack, { idx, last })
    end
  end
  local out = {}
  for i = 1, n do
    if keep[i] then
      for k = 1, stride do out[#out + 1] = pts[(i - 1) * stride + k] end
    end
  end
  return out
end

-- Simplify a route that's still being recorded, and recount its points
function R.Compact(route)
  local n = 0
  for _, seg in ipairs(route.segs) do
    local stride = R.Stride(seg)
    seg.pts = Simplify(seg.pts, SIMPLIFY_TOLERANCE, stride)
    n = n + #seg.pts / stride
  end
  route.n = n
end

-- Called when an activity is saved to history
function R.Finish(s)
  local route = s.route
  if not route then return end
  local segs = {}
  for _, seg in ipairs(route.segs or {}) do
    local stride = R.Stride(seg)
    if #seg.pts >= stride * 2 then
      seg.pts = Simplify(seg.pts, SIMPLIFY_TOLERANCE, stride)
      table.insert(segs, seg)
    end
  end
  if #segs == 0 then s.route = nil return end
  route.segs, route.n = segs, nil
end

-- Drop routes from older activities to keep saved data small
function R.Trim(history)
  for i = KEEP_ROUTES + 1, #history do history[i].route = nil end
end

-- True if any part of the route has at least two points (a line to draw)
function R.Has(s)
  if not (s and s.route and s.route.segs) then return false end
  for _, seg in ipairs(s.route.segs) do
    if #seg.pts >= R.Stride(seg) * 2 then return true end
  end
  return false
end

-- All points of a route as one bounding box (in a/b world coordinates)
function R.Bounds(route, filter)
  local minA, maxA, minB, maxB
  for _, seg in ipairs(route.segs) do
    if not filter or filter(seg) then
      local stride = R.Stride(seg)
      for i = 1, #seg.pts, stride do
        local a, b = seg.pts[i], seg.pts[i + 1]
        minA, maxA = math.min(minA or a, a), math.max(maxA or a, a)
        minB, maxB = math.min(minB or b, b), math.max(maxB or b, b)
      end
    end
  end
  return minA, maxA, minB, maxB
end

---------------------------------------------------------------------------
-- Sharing: a compact text version of a route for addon messages.
-- Segments are separated by "/", each is "inst:map:" followed by
-- comma-separated base-36 numbers: first point absolute, then differences,
-- each point as a, b, band. Coordinates are rounded to whole yards.
---------------------------------------------------------------------------
local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

local function To36(n)
  n = math.floor(n + 0.5)
  if n == 0 then return "0" end
  local neg = n < 0
  if neg then n = -n end
  local s = ""
  while n > 0 do
    local d = n % 36
    s = DIGITS:sub(d + 1, d + 1) .. s
    n = math.floor(n / 36)
  end
  return neg and ("-" .. s) or s
end

-- (tonumber with a base doesn't handle "-" reliably in WoW's Lua, so do it here)
local function From36(s)
  local neg = s:sub(1, 1) == "-"
  local v = tonumber(neg and s:sub(2) or s, 36)
  if not v then return nil end
  return neg and -v or v
end

-- Copy of the route simplified until it has at most SHARE_POINTS points.
-- A very stop-and-go walk has many speed changes; after a few tries those
-- points may be dropped too, so the route can always be shared.
local function ShareCopy(route)
  local tol = 10
  for try = 1, 10 do
    local segs, n = {}, 0
    for _, seg in ipairs(route.segs) do
      local stride = R.Stride(seg)
      if #seg.pts >= stride * 2 then
        local pts = Simplify(seg.pts, tol, stride, try > 4)
        segs[#segs + 1] = { inst = seg.inst, map = seg.map, stride = stride, pts = pts }
        n = n + #pts / stride
      end
    end
    if n <= SHARE_POINTS or try == 10 then return segs end
    tol = tol * 1.8
  end
end

function R.Encode(route)
  local segs = route and ShareCopy(route)
  if not segs or #segs == 0 then return nil end
  local parts = {}
  for _, seg in ipairs(segs) do
    local nums = {}
    local pa, pb = 0, 0
    for i = 1, #seg.pts, seg.stride do
      local a, b = math.floor(seg.pts[i] + 0.5), math.floor(seg.pts[i + 1] + 0.5)
      local band = seg.stride == 3 and seg.pts[i + 2] or RUN_BAND
      nums[#nums + 1] = To36(a - pa)
      nums[#nums + 1] = To36(b - pb)
      nums[#nums + 1] = To36(band)
      pa, pb = a, b
    end
    parts[#parts + 1] = (seg.inst and To36(seg.inst) or "") .. ":" .. (seg.map and To36(seg.map) or "") .. ":" ..
      table.concat(nums, ",")
  end
  return table.concat(parts, "/")
end

function R.Decode(text)
  if type(text) ~= "string" or text == "" then return nil end
  local segs = {}
  for part in text:gmatch("[^/]+") do
    local inst, map, data = part:match("^([^:]*):([^:]*):(.*)$")
    if data then
      local seg = { inst = inst ~= "" and From36(inst) or nil, map = map ~= "" and From36(map) or nil, v = 2, pts = {} }
      local vals = {}
      for num in data:gmatch("[^,]+") do vals[#vals + 1] = From36(num) end
      local a, b = 0, 0
      for i = 1, #vals - 2, 3 do
        if not (vals[i] and vals[i + 1] and vals[i + 2]) then break end
        a, b = a + vals[i], b + vals[i + 1]
        seg.pts[#seg.pts + 1] = a
        seg.pts[#seg.pts + 1] = b
        seg.pts[#seg.pts + 1] = math.max(1, math.min(#R.BANDS, vals[i + 2]))
      end
      if #seg.pts >= 6 then segs[#segs + 1] = seg end
    end
  end
  if #segs == 0 then return nil end
  return { segs = segs }
end

---------------------------------------------------------------------------
-- World map: convert world coordinates to a map's 0..1 coordinates
---------------------------------------------------------------------------
function R.MapTransform(mapID)
  local M = C_Map
  if not (mapID and M and M.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local ok1, cont1, topLeft = pcall(M.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
  local ok2, _, bottomRight = pcall(M.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
  if not (ok1 and ok2 and topLeft and bottomRight) then return nil end
  local top, left = topLeft:GetXY()
  local bottom, right = bottomRight:GetXY()
  if not (Plain(top) and Plain(left) and Plain(bottom) and Plain(right)) then return nil end
  if left == right or top == bottom then return nil end
  return cont1, function(a, b)
    return (left - b) / (left - right), (top - a) / (top - bottom)
  end
end
