local _, ns = ...

-- Routes: the path you walked, recorded from your world position outdoors.
-- A route is stored on its activity as:
--   s.route = { segs = { { inst = continent, map = uiMapID, pts = { a1, b1, a2, b2, ... } }, ... } }
-- where (a, b) are the first two values of UnitPosition("player").
-- A new segment starts after a big jump (flight path, mount, teleport).

local R = {}
ns.Routes = R

local MIN_GAP = 8          -- yards between saved points while walking
local BREAK_GAP = 150      -- a jump bigger than this starts a new segment
local MAX_POINTS = 6000    -- per activity while recording
local MAX_SEGMENTS = 60
local SIMPLIFY_TOLERANCE = 2.5 -- yards; how much detail to drop on finish
local KEEP_ROUTES = 30     -- only the newest activities keep their route

local Plain = ns.Plain

local function Round(v) return math.floor(v * 10 + 0.5) / 10 end

local function BestMap()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and Plain(id) then return id end
  return nil
end

---------------------------------------------------------------------------
-- Recording (called from the step counter for every counted outdoor move)
---------------------------------------------------------------------------
function R.Record(s, a, b, inst)
  if not s or not Plain(a) or not Plain(b) then return end
  s.route = s.route or { segs = {}, n = 0 }
  local route = s.route
  -- Long walks: simplify what's recorded so far instead of stopping
  if (route.n or 0) >= MAX_POINTS then
    R.Compact(route)
    if route.n >= MAX_POINTS * 0.8 then return end -- couldn't free enough room
  end

  local segs = route.segs
  local seg = segs[#segs]
  if seg and seg.inst == inst then
    local pts = seg.pts
    local la, lb = pts[#pts - 1], pts[#pts]
    local d = math.sqrt((a - la) ^ 2 + (b - lb) ^ 2)
    if d < MIN_GAP then return end
    if d > BREAK_GAP then seg = nil end
  else
    seg = nil
  end
  if not seg then
    if #segs >= MAX_SEGMENTS then return end
    seg = { inst = inst, map = BestMap(), pts = {} }
    table.insert(segs, seg)
  end
  seg.pts[#seg.pts + 1] = Round(a)
  seg.pts[#seg.pts + 1] = Round(b)
  route.n = (route.n or 0) + 1
end

---------------------------------------------------------------------------
-- Simplify (Douglas-Peucker) so long routes stay small in saved data
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

local function Simplify(pts, tol)
  local n = #pts / 2
  if n <= 2 then return pts end
  local keep = { [1] = true, [n] = true }
  local stack = { { 1, n } }
  local tolSq = tol * tol
  while #stack > 0 do
    local range = table.remove(stack)
    local first, last = range[1], range[2]
    local maxD, idx = 0, nil
    local aa, ab = pts[first * 2 - 1], pts[first * 2]
    local ba, bb = pts[last * 2 - 1], pts[last * 2]
    for i = first + 1, last - 1 do
      local d = PerpDistSq(pts[i * 2 - 1], pts[i * 2], aa, ab, ba, bb)
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
      out[#out + 1] = pts[i * 2 - 1]
      out[#out + 1] = pts[i * 2]
    end
  end
  return out
end

-- Simplify a route that's still being recorded, and recount its points
function R.Compact(route)
  local n = 0
  for _, seg in ipairs(route.segs) do
    seg.pts = Simplify(seg.pts, SIMPLIFY_TOLERANCE)
    n = n + #seg.pts / 2
  end
  route.n = n
end

-- Called when an activity is saved to history
function R.Finish(s)
  local route = s.route
  if not route then return end
  local segs = {}
  for _, seg in ipairs(route.segs or {}) do
    if #seg.pts >= 4 then
      seg.pts = Simplify(seg.pts, SIMPLIFY_TOLERANCE)
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
    if #seg.pts >= 4 then return true end
  end
  return false
end

-- All points of a route as one bounding box (in a/b world coordinates)
function R.Bounds(route)
  local minA, maxA, minB, maxB
  for _, seg in ipairs(route.segs) do
    for i = 1, #seg.pts, 2 do
      local a, b = seg.pts[i], seg.pts[i + 1]
      minA, maxA = math.min(minA or a, a), math.max(maxA or a, a)
      minB, maxB = math.min(minB or b, b), math.max(maxB or b, b)
    end
  end
  return minA, maxA, minB, maxB
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
