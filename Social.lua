local _, ns = ...
local L = ns.L
local F = ns.F

-- Friends and guildies with the addon swap stats, activities and achievements
-- through hidden addon messages: guild channel, whispers to online friends, and
-- Battle.net game data for Battle.net friends on the same game.
--
-- Every message carries the sender's character GUID. People are keyed by GUID,
-- so name formats (WoW Forever "First Second" names, realms, Battle.net vs
-- guild) can't create duplicates, and your own echoed messages are ignored.

local PREFIX = "AWS"
local VERSION = "2"
-- Hidden channel for the "Everyone" leaderboard. Anyone can join a custom
-- channel, and its owner can lock it with a password or ban people, so if a
-- name can't be joined the addon moves on to the next one.
local CHANNEL_NAMES = { "AWSWalkers", "AWSWalkers2", "AWSWalkers3", "AWSWalkers4", "AWSWalkers5", "AWSWalkers6" }
local channelIdx = 1
local function ChannelName() return CHANNEL_NAMES[channelIdx] end
local PEOPLE_CAP = 1000
local SEND_INTERVAL = 1.0      -- seconds between outgoing messages (server throttle)
local BROADCAST_INTERVAL = 5   -- friends/guild: check for changed stats this often (only sends if changed)
local CHANNEL_INTERVAL = 30    -- the Everyone channel gets updates at most this often
local LIVE_WINDOW = 12         -- max seconds to keep counting a friend's steps up without a new update
local HEARTBEAT = 240          -- resend stats even if unchanged, so you show as online
local FEED_CAP = 200
ns.SOCIAL_ONLINE_WINDOW = 330  -- seconds since last message to count as online

local S = {}
ns.Social = S

local guildSet, friendSet = {}, {}
local lastStats, lastStatsTime, lastChannelTime = nil, 0, 0

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
local function CleanRealm(realm)
  return (realm:gsub("[%s%-]", ""))
end

local function MyRealm()
  local r = GetNormalizedRealmName and GetNormalizedRealmName()
  if r and r ~= "" then return r end
  return CleanRealm(GetRealmName() or "")
end

function S.FullName(name, realm)
  if not name or name == "" then return nil end
  if name:find("-", 1, true) then return name end
  if realm and realm ~= "" then return name .. "-" .. CleanRealm(realm) end
  return name .. "-" .. MyRealm()
end

function S.MyGUID() return UnitGUID("player") end

function S.Short(full)
  if not full then return "?" end
  if Ambiguate then return Ambiguate(full, "short") end
  return (full:match("^[^-]+")) or full
end

local function ClassColored(name, class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c and c.colorStr then return ("|c%s%s|r"):format(c.colorStr, name) end
  return name
end

-- Display name for a GUID (you or a friend)
function S.ColoredName(guid)
  if guid == S.MyGUID() then return ClassColored(UnitName("player"), select(2, UnitClass("player"))) end
  local e = ns.db.social.people[guid]
  if not e then return "?" end
  return ClassColored(S.Short(e.name), e.class)
end

---------------------------------------------------------------------------
-- Outgoing queue (one message per SEND_INTERVAL)
---------------------------------------------------------------------------
local queue = {}

local function RawSend(msg, dest)
  if dest.kind == "BN" then
    if BNSendGameData then BNSendGameData(dest.id, PREFIX, msg) end
  elseif dest.kind == "GUILD" then
    if IsInGuild() then C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD") end
  elseif dest.kind == "CHANNEL" then
    local id = GetChannelName(ChannelName())
    if id and id > 0 then C_ChatInfo.SendAddonMessage(PREFIX, msg, "CHANNEL", id) end
  elseif dest.target then
    if S.NoteWhisper then S.NoteWhisper(dest.target) end
    C_ChatInfo.SendAddonMessage(PREFIX, msg, "WHISPER", dest.target)
  end
end

-- replaceKey: a newer message with the same key replaces a queued older one.
-- replaceKey = true: urgent (route replies), sent before normal messages and never dropped.
local function Queue(msg, dest, replaceKey)
  if replaceKey == true then
    local at = #queue + 1
    for i, q in ipairs(queue) do
      if not q.urgent then at = i; break end
    end
    table.insert(queue, at, { msg = msg, dest = dest, urgent = true })
  elseif replaceKey then
    local key = replaceKey .. ":" .. (dest.key or dest.target or tostring(dest.id))
    for _, q in ipairs(queue) do
      if q.key == key then q.msg = msg; return end
    end
    table.insert(queue, { msg = msg, dest = dest, key = key })
  else
    table.insert(queue, { msg = msg, dest = dest })
  end
  -- too many waiting: drop the oldest normal message
  while #queue > 80 do
    local dropped
    for i, q in ipairs(queue) do
      if not q.urgent then table.remove(queue, i); dropped = true; break end
    end
    if not dropped then break end
  end
end

local sender = CreateFrame("Frame")
local nextSend = 0
sender:SetScript("OnUpdate", function()
  if #queue == 0 then return end
  local now = GetTime()
  if now < nextSend then return end
  nextSend = now + SEND_INTERVAL
  local q = table.remove(queue, 1)
  RawSend(q.msg, q.dest)
end)

---------------------------------------------------------------------------
-- Who to send to: guild channel + online friends not in the guild
---------------------------------------------------------------------------
-- Realm formats differ between the friends list, guild roster, Battle.net
-- and chat, so guild/friend lookups use the name without the realm.
local function ShortName(name)
  if not name then return nil end
  return strlower(name:match("^([^-]+)") or name)
end

local function UpdateGuild()
  wipe(guildSet)
  if not IsInGuild() then return end
  for i = 1, (GetNumGuildMembers() or 0) do
    local name = ShortName((GetGuildRosterInfo(i)))
    if name then guildSet[name] = true end
  end
end

-- Hidden whispers that failed ("No player named ... is currently playing").
-- Those friends are skipped for a while instead of failing every minute.
local WHISPER_RETRY = 600
local failedWhispers = {}
local function WhisperBlocked(name)
  local t = failedWhispers[ShortName(name)]
  return t and GetTime() - t < WHISPER_RETRY
end

-- includeChannel: also send to the "Everyone" channel (stats and hellos only)
local function Recipients(includeChannel)
  local list, seen = {}, {}
  wipe(friendSet)
  if includeChannel and ns.settings.globalBoard then
    table.insert(list, { kind = "CHANNEL", key = "CHANNEL" })
  end
  if IsInGuild() then table.insert(list, { kind = "GUILD", key = "GUILD" }) end
  for name in pairs(guildSet) do seen[name] = true end
  seen[ShortName(UnitName("player"))] = true

  -- Battle.net friends first: their game account always reaches them, on any realm
  if BNGetNumFriends and BNSendGameData and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
    for i = 1, (BNGetNumFriends() or 0) do
      local acc = C_BattleNet.GetFriendAccountInfo(i)
      local g = acc and acc.gameAccountInfo
      if g and g.isOnline and g.gameAccountID and g.characterName and g.characterName ~= ""
         and g.clientProgram == BNET_CLIENT_WOW
         and (not WOW_PROJECT_ID or not g.wowProjectID or g.wowProjectID == WOW_PROJECT_ID) then
        local short = ShortName(g.characterName)
        friendSet[short] = true
        if not seen[short] then
          seen[short] = true
          table.insert(list, { kind = "BN", id = g.gameAccountID, key = S.FullName(g.characterName, g.realmName) })
        end
      end
    end
  end

  -- Character friends: whisper using exactly the name the friends list gives
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, C_FriendList.GetNumFriends() do
      local info = C_FriendList.GetFriendInfoByIndex(i)
      local short = info and ShortName(info.name)
      if short then friendSet[short] = true end
      if short and info.connected and not seen[short] and not WhisperBlocked(info.name) then
        seen[short] = true
        table.insert(list, { kind = "WHISPER", target = info.name, key = short })
      end
    end
  end
  return list
end

-- Which leaderboards a person belongs to
function S.IsGuild(e) return e and (e.viaGuild or (e.name and guildSet[ShortName(e.name)])) and true or false end
function S.IsFriend(e) return e and (e.bnFriend or (e.name and friendSet[ShortName(e.name)])) and true or false end

-- The surest way to reach one person. Guildies: the guild channel (messages
-- say who they're for, others ignore them). Friends: Battle.net, or the exact
-- name from the friends list. A whisper to the name we built ourselves is the
-- last resort: it fails for some names and realms.
function S.DestFor(e)
  if not e then return nil end
  local short = e.name and ShortName(e.name)
  if IsInGuild() and short and guildSet[short] then return { kind = "GUILD", key = "GUILD" } end
  if short then
    for _, d in ipairs(Recipients(false)) do
      if (d.kind == "BN" or d.kind == "WHISPER") and ShortName(d.key or d.target) == short then return d end
    end
  end
  return e.dest
end

-- /aws debug net: prints what route sharing and kudos send and receive
local function NetLog(fmt, ...)
  if ns.netDebug then ns.Print("|cff88ccff[net]|r " .. fmt:format(...)) end
end
S.NetLog = NetLog
local function DestText(d)
  if not d then return "nobody" end
  return d.kind .. (d.target and (" " .. d.target) or d.id and (" #" .. d.id) or "")
end

---------------------------------------------------------------------------
-- Hide "No player named X is currently playing" when it was caused by one of
-- our hidden whispers, and remember the failure.
---------------------------------------------------------------------------
local recentWhispers = {}
S.NoteWhisper = function(target) recentWhispers[ShortName(target)] = GetTime() end

local notFoundPattern
if ERR_CHAT_PLAYER_NOT_FOUND_S then
  notFoundPattern = "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    :gsub("%%%%s", "(.+)") .. "$"
end

if ChatFrame_AddMessageEventFilter and notFoundPattern then
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, msg)
    local who = type(msg) == "string" and msg:match(notFoundPattern)
    if not who then return false end
    local short = ShortName(who)
    local sent = recentWhispers[short]
    if sent and GetTime() - sent < 15 then
      failedWhispers[short] = GetTime()
      if ns.netDebug then ns.Print("|cff88ccff[net]|r hidden whisper failed: " .. who) end
      return true -- hide it: the player only sees errors from their own whispers
    end
    return false
  end)
end
-- Friends + guild: the people overtake alerts and "Top of the Pack" care about
local function InCircle(e) return S.IsGuild(e) or S.IsFriend(e) end

local function InChannel() return (GetChannelName(ChannelName()) or 0) > 0 end

local function JoinChannel()
  if not ns.settings.globalBoard or not JoinTemporaryChannel then return end
  local name = ChannelName()
  if not InChannel() then JoinTemporaryChannel(name) end
  -- keep it out of the chat windows
  if ChatFrame_RemoveChannel then
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
      local cf = _G["ChatFrame" .. i]
      if cf then ChatFrame_RemoveChannel(cf, name) end
    end
  end
  -- Locked with a password, or banned: we're still not in it after a few
  -- seconds, so try the next name
  C_Timer.After(8, function()
    if ns.settings.globalBoard and not InChannel() and channelIdx < #CHANNEL_NAMES then
      channelIdx = channelIdx + 1
      S.NetLog("Everyone channel %s can't be joined, trying %s", name, ChannelName())
      JoinChannel()
    end
  end)
end

-- Kicked or banned later on: rejoin (or move on) once a minute
local function WatchChannel()
  if ns.settings.globalBoard and JoinTemporaryChannel and not InChannel() then JoinChannel() end
end

function S.SetGlobalBoard(on)
  ns.settings.globalBoard = on
  if on then
    JoinChannel()
    C_Timer.After(3, function() S.BroadcastStats(true) end)
  elseif LeaveChannelByName then
    LeaveChannelByName(ChannelName())
  end
end

---------------------------------------------------------------------------
-- Messages (fields 1-3 are always: type ; version ; sender GUID)
-- H  hello, "send me your stats"
-- S  stats: class;level;today;todayDist;week;weekDist;month;monthDist;all;allDist;
--           sessions;streak;active;sessionSteps;since;rank;achievements;weekDone;weekKey;badges;
--           rate;features;dayKey;monthKey;inGroup;achievementMask1;achievementMask2 (hex, see Achievements.Mask)
-- A  activity: id;steps;dist;moving;elapsed;finish;zone,zone
-- K  kudos for activity id (sent only to its owner)
-- C  event: kind(c=challenge, w=weekly champion, a=achievement, r=rank);id;periodKey
---------------------------------------------------------------------------
local function Int(n) return tostring(math.floor((n or 0) + 0.5)) end
local function Msg(kind, ...) return table.concat({ kind, VERSION, S.MyGUID() or "", ... }, ";") end

-- In a party or raid? Friends see it, so their menu offers "ask to join"
local function InGroup()
  if IsInGroup then return IsInGroup() and true or false end
  return ((GetNumGroupMembers and GetNumGroupMembers()) or 0) > 0
end

local function StatsMsg()
  local c = ns.cdb
  local Ch = ns.Challenges
  local wp, mp = Ch.WeekPeriod(), Ch.MonthPeriod()
  local w, m = Ch.Gather(wp), Ch.Gather(mp)
  local today = ns.GetDay(date("%Y-%m-%d"))
  local streak = ns.Streaks()
  local s = c.current
  local _, class = UnitClass("player")
  return Msg("S", class or "", UnitLevel("player") or 0, Int(today.s), Int(today.d), Int(w.steps), Int(w.dist),
    Int(m.steps), Int(m.dist), Int(c.total.steps), Int(c.total.distance), c.total.sessions, streak,
    (s and not s.paused) and 1 or 0, s and Int(s.steps) or 0, c.since, ns.Achievements.MyRank(),
    ns.Achievements.Count(), Ch.WeekChallengesDone(wp.key), wp.key, #c.badges,
    (s and not s.paused) and math.floor((ns.state.rate or 0) * 10 + 0.5) or 0, -- steps/s x10
    S.FEATURES, date("%Y-%m-%d"), "M" .. date("%Y-%m"), InGroup() and 1 or 0,
    ns.Achievements.Mask()) -- which achievements: field 29 = first 24 (2.6.0+), field 30 = the rest (2.7.0+)
end

local function ActivityMsg(a)
  local head = Msg("A", a.start, Int(a.steps), Int(a.distance), Int(a.moving), Int(a.elapsed), a.finish or 0)
  local zones = ""
  for _, z in ipairs(a.zones or {}) do
    local add = (zones == "" and "" or ",") .. z:gsub("[;,|]", " ")
    if #head + 1 + #zones + #add > 250 then break end
    zones = zones .. add
  end
  return head .. ";" .. zones
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local function Sharing() return ns.settings and ns.settings.shareEnabled end

-- Cheap summary of what's in the stats message, so the full message (which
-- adds up your week, month and streak) is only built when something changed
local lastFingerprint
local function StatsFingerprint()
  local c, s = ns.cdb, ns.cdb.current
  return table.concat({ Int(c.total.steps), s and (s.paused and "p" or Int(s.steps)) or "-", #c.badges,
    ns.Achievements.Count(), date("%Y-%m-%d"), UnitLevel("player") or 0, InGroup() and 1 or 0,
    s and not s.paused and Int((ns.state.rate or 0) * 10) or 0 }, ":")
end

function S.BroadcastStats(force)
  if not Sharing() then return end
  local now = GetTime()
  local fp = StatsFingerprint()
  if not force and fp == lastFingerprint and now - lastStatsTime < HEARTBEAT then return end
  lastFingerprint = fp
  local msg = StatsMsg()
  lastStats, lastStatsTime = msg, now
  -- Friends and guild every time; the busy Everyone channel only every 30s
  local toChannel = force or now - lastChannelTime >= CHANNEL_INTERVAL
  if toChannel and ns.settings.globalBoard then lastChannelTime = now end
  for _, d in ipairs(Recipients(toChannel)) do Queue(msg, d, "S") end
end

function S.OnActivityFinished(a)
  if not Sharing() then return end
  local msg = ActivityMsg(a)
  for _, d in ipairs(Recipients()) do Queue(msg, d) end
  S.BroadcastStats(true)
end

-- Tell friends about a challenge / achievement / rank-up
function S.Announce(kind, id, periodKey)
  if not Sharing() then return end
  local msg = Msg("C", kind, id, periodKey or "")
  for _, d in ipairs(Recipients()) do Queue(msg, d) end
end

local function SayHello()
  if not Sharing() then return end
  for _, d in ipairs(Recipients(true)) do Queue(Msg("H"), d, "H") end
  S.BroadcastStats(true)
end

-- statsOnly: hellos from the Everyone channel just get your stats back
local function ReplyToHello(dest, statsOnly)
  if not Sharing() then return end
  Queue(StatsMsg(), dest, "S")
  if statsOnly then return end
  for i = 3, 1, -1 do
    local a = ns.cdb.history[i]
    if a then Queue(ActivityMsg(a), dest) end
  end
end

---------------------------------------------------------------------------
-- Route sharing, on demand: you ask a friend for one activity's route
-- (RQ;2;guid;activityId) and they answer only you, in chunks
-- (RP;2;guid;activityId;index;total;text). total 0 = no route.
---------------------------------------------------------------------------
local ROUTE_CHUNK = 190
local ROUTE_WAIT = 30      -- seconds without any answer before giving up
local REQUEST_COOLDOWN = 20 -- ignore the same request again this soon
local pendingRoutes = {} -- ["guid:id"] = { item, chunks, got, onProgress, onDone, deadline }
local answered = {}      -- ["requester:id"] = time we last sent that route

-- Features this version supports, sent with your stats. 1 = route sharing.
S.FEATURES = 1

-- Someone asked for one of your routes
function S.HandleRouteRequest(guid, p, dest)
  if not Sharing() then return end
  local id = tonumber(p[4])
  if not id then return end
  if p[5] and p[5] ~= "" and p[5] ~= S.MyGUID() then return end -- asked someone else (guild channel)
  dest = S.DestFor(ns.db.social.people[guid]) or dest
  local seen = guid .. ":" .. id
  if answered[seen] and GetTime() - answered[seen] < REQUEST_COOLDOWN then return end
  answered[seen] = GetTime()
  local activity
  local cur = ns.cdb.current
  if cur and cur.start == id then activity = cur end
  for _, a in ipairs(ns.cdb.history) do
    if activity then break end
    if a.start == id then activity = a end
  end
  local ok, text = pcall(ns.Routes.Encode, activity and activity.route)
  if not ok then NetLog("route encode error: %s", tostring(text)); text = nil end
  NetLog("%s asked for route %d: %s, replying via %s", S.Short(ns.db.social.people[guid].name), id,
    not activity and "no such activity" or text and (#text .. " chars") or "no route", DestText(dest))
  if not text then
    Queue(Msg("RP", id, 0, 0, ""), dest, true)
    return
  end
  local total = math.ceil(#text / ROUTE_CHUNK)
  for i = 1, total do
    Queue(Msg("RP", id, i, total, text:sub((i - 1) * ROUTE_CHUNK + 1, i * ROUTE_CHUNK)), dest, true)
  end
end

-- A chunk of a route you asked for
function S.HandleRouteReply(guid, p)
  local id = tonumber(p[4])
  local key = id and (guid .. ":" .. id)
  local req = key and pendingRoutes[key]
  if not req then return end
  local index, total = tonumber(p[5]) or 0, tonumber(p[6]) or 0
  NetLog("route piece %d / %d", index, total)
  if total == 0 then
    pendingRoutes[key] = nil
    req.onDone(nil, "none")
    return
  end
  req.deadline, req.total = GetTime() + ROUTE_WAIT, total -- still arriving: keep waiting
  if index >= 1 and index <= total and not req.chunks[index] then
    req.chunks[index] = p[7] or ""
    req.got = req.got + 1
  end
  if req.got < total then
    req.onProgress(req.got, total)
    return
  end
  pendingRoutes[key] = nil
  local route = ns.Routes.Decode(table.concat(req.chunks))
  if route then req.item.route = route end -- kept with the feed item
  req.onDone(route, route and nil or "none")
end

-- Gives up on a request once nothing has arrived for ROUTE_WAIT seconds
local function WatchRequest(key, req)
  C_Timer.After(math.max(1, req.deadline - GetTime()), function()
    if pendingRoutes[key] ~= req then return end -- finished, or replaced
    if GetTime() < req.deadline then return WatchRequest(key, req) end
    pendingRoutes[key] = nil
    local e = ns.db.social.people[req.item.from]
    NetLog("no answer for route %d after %ds", req.item.id, ROUTE_WAIT)
    -- an answer would have come from a version that can share routes
    req.onDone(nil, (e and (e.features or 0) >= 1) and "offline" or "noanswer")
  end)
end

-- Ask a friend for the route of one of their activities.
-- onProgress(got, total); onDone(route or nil, reason):
-- "none" (no route), "offline", or "noanswer" (maybe an older version)
function S.RequestRoute(item, onProgress, onDone)
  local e = ns.db.social.people[item.from]
  local dest = S.DestFor(e)
  NetLog("asking %s for route %d via %s (last heard %ss ago, features %s)", S.Short(e and e.name),
    item.id, DestText(dest), e and e.updated and (time() - e.updated) or "?", tostring(e and e.features))
  if not dest or not S.IsOnline(e) then return onDone(nil, "offline") end
  local key = item.from .. ":" .. item.id
  local req = pendingRoutes[key]
  if req then -- already asked: just show this one's progress
    req.onProgress, req.onDone = onProgress, onDone
    if req.got > 0 and req.total then onProgress(req.got, req.total) end
    return
  end
  req = { item = item, chunks = {}, got = 0, onProgress = onProgress, onDone = onDone,
          deadline = GetTime() + ROUTE_WAIT }
  pendingRoutes[key] = req
  Queue(Msg("RQ", item.id, item.from), dest, true)
  WatchRequest(key, req)
end

function S.GiveKudos(item)
  if item.kudos or item.mine or item.event then return end
  item.kudos = true
  local p = ns.db.social.people[item.from]
  local dest = S.DestFor(p)
  if not dest then return end
  NetLog("kudos to %s via %s", S.Short(p.name), DestText(dest))
  Queue(Msg("K", item.id, item.from), dest)
  ns.cdb.kudosGiven = ns.cdb.kudosGiven + 1
  ns.Achievements.Check()
  ns.OnSocialChanged()
end

---------------------------------------------------------------------------
-- Overtake alerts (this week's steps, friends seen recently)
---------------------------------------------------------------------------
function S.IsOnline(e) return e and e.updated and time() - e.updated < ns.SOCIAL_ONLINE_WINDOW end

local function FriendWeek(e, weekKey)
  if e.weekKey == weekKey then return e.week or 0 end
  return 0
end

-- Passing someone only counts with a clear gap, and each friend can trigger
-- an alert at most once every ALERT_COOLDOWN seconds (no ping-pong when you
-- walk side by side)
local OVERTAKE_MARGIN = 100
local ALERT_COOLDOWN = 15 * 60

local function CheckOvertakes(only)
  local c = ns.cdb
  local people = ns.db.social.people
  local single = only and people[only]
  if only and not (single and S.IsOnline(single) and InCircle(single)) then return end -- strangers: nothing to do
  local weekKey = ns.Challenges.WeekPeriod().key
  if not c.rivals or c.rivals.week ~= weekKey then c.rivals = { week = weekKey, rel = {} } end
  c.rivals.alerted = c.rivals.alerted or {}
  local mine = ns.Challenges.WeekSteps()
  local list = only and { [only] = single } or people
  for guid, e in pairs(list) do
    if S.IsOnline(e) and InCircle(e) then
      local theirs = FriendWeek(e, weekKey)
      local prev = c.rivals.rel[guid]
      if mine >= 1 and theirs >= 1 and (not prev or math.abs(mine - theirs) >= OVERTAKE_MARGIN) then
        local rel = mine > theirs and "ahead" or "behind"
        c.rivals.rel[guid] = rel
        local recent = time() - (c.rivals.alerted[guid] or 0) < ALERT_COOLDOWN
        if prev and prev ~= rel and not recent then
          c.rivals.alerted[guid] = time()
          local name = ns.PlayerLink(guid)
          local text
          if rel == "ahead" then
            text = (L["You passed %s on this week's leaderboard!"]):format(name)
          else
            text = (L["%s just passed you on this week's leaderboard!"]):format(name)
          end
          ns.Print(text)
          ns.Banner.Toast({ title = rel == "ahead" and L["Overtake!"] or L["You've been passed!"], text = text,
            icon = "Interface\\Icons\\Ability_Rogue_Sprint", open = { tab = ns.SOCIAL_TAB } })
        end
      end
    end
  end
end

function S.IsWeekLeader()
  local weekKey = ns.Challenges.WeekPeriod().key
  local mine, others, best = ns.Challenges.WeekSteps(), 0, 0
  for _, e in pairs(ns.db.social.people) do
    local w = InCircle(e) and FriendWeek(e, weekKey) or 0
    if w >= 1 then
      others = others + 1
      if w > best then best = w end
    end
  end
  return others >= 3 and mine > best
end

-- Your place among friends for a past week (for the weekly recap)
function S.PlaceInWeek(weekKey, mySteps)
  local place, total = 1, 1
  for _, e in pairs(ns.db.social.people) do
    local v
    if e.weekKey == weekKey then v = e.week elseif e.prevWeekKey == weekKey then v = e.prevWeek end
    if v and v >= 1 and InCircle(e) then
      total = total + 1
      if v > mySteps then place = place + 1 end
    end
  end
  return place, total
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function N(v) return tonumber(v) or 0 end

-- Text from other players is shown in the Feed and tooltips: drop WoW's
-- escape codes (|T textures, |H links, |c colors) and keep it short
local function Clean(s, maxLen)
  return ((tostring(s or ""):gsub("|", "")):sub(1, maxLen or 40))
end

-- A friend can only post a few news items a minute (activities + events);
-- anything beyond that is ignored, so nobody can flood your screen
local NEWS_PER_MINUTE = 8
local newsLog = {} -- [guid] = { times }
local function AllowNews(guid)
  local now, log = GetTime(), newsLog[guid] or {}
  newsLog[guid] = log
  while log[1] and now - log[1] > 60 do table.remove(log, 1) end
  if #log >= NEWS_PER_MINUTE then return false end
  log[#log + 1] = now
  return true
end

-- Challenge periods that can still matter: last, this and next week/month
-- (next, for friends whose new week has already started in their time zone)
local function LivePeriods()
  local Ch = ns.Challenges
  local w, m = Ch.WeekPeriod(), Ch.MonthPeriod()
  return {
    [w.key] = true, [Ch.WeekPeriod(w.startTs - 3 * 86400).key] = true, [Ch.WeekPeriod(w.endTs + 3 * 86400).key] = true,
    [m.key] = true, [Ch.MonthPeriod(m.startTs - 3 * 86400).key] = true, [Ch.MonthPeriod(m.endTs + 3 * 86400).key] = true,
  }
end

-- No one can walk more than this on foot in a day (8 yd/s for 24 h, 2 yd steps)
local DAY_MAX = 350000
local EPOCH = time({ year = 2026, month = 11, day = 1, hour = 0 }) -- before the first release

local function Plausible(p)
  local today, week, month, all = N(p[6]), N(p[8]), N(p[10]), N(p[12])
  local days = math.floor((time() - math.max(N(p[18]), EPOCH)) / 86400) + 2
  return today <= DAY_MAX and week <= 7 * DAY_MAX and month <= 31 * DAY_MAX and all <= days * DAY_MAX
    and N(p[17]) <= 7 * DAY_MAX and N(p[24]) <= 80 and today <= week + 1 and week <= all + 1
end

-- Fastest anyone can add steps (travel form/ghost wolf is about 5 a second),
-- plus room for the live updates and clock differences
local MAX_RATE, RATE_SLACK = 6, 3000

local function HandleStats(guid, p)
  local e = ns.db.social.people[guid]
  local all, now = N(p[12]), time()
  -- all-time steps can't grow faster than anyone can walk since we last saw them
  -- (the last accepted total stays as the reference, so a jump stays flagged
  -- until enough time has passed to have walked it)
  local tooFast = e.allAt and e.all and all - e.all > (now - e.allAt) * MAX_RATE + RATE_SLACK
  if tooFast or not Plausible(p) then
    e.flagged = true -- impossible numbers: kept off the leaderboards
    return
  end
  e.flagged = nil
  e.allAt = now
  local weekKey = Clean(p[22], 12)
  if e.weekKey and e.weekKey ~= weekKey then
    e.prevWeekKey, e.prevWeek = e.weekKey, e.week -- keep last week for the recap
  end
  e.class = (p[4] ~= "" and p[4]) or e.class
  e.level = N(p[5])
  e.today, e.todayDist, e.week, e.weekDist = N(p[6]), N(p[7]), N(p[8]), N(p[9])
  e.month, e.monthDist, e.all, e.allDist = N(p[10]), N(p[11]), N(p[12]), N(p[13])
  e.sessions, e.streak, e.active, e.sessionSteps = N(p[14]), N(p[15]), p[16] == "1", N(p[17])
  e.since, e.rank, e.ach, e.weekDone = N(p[18]), N(p[19]), N(p[20]), N(p[21])
  e.weekKey, e.badges = weekKey, N(p[23])
  e.rate, e.clock = N(p[24]) / 10, GetTime() -- for counting their steps up live
  e.features = N(p[25]) -- 0 = a version before 2.4.1
  e.inGroup = p[28] == "1"
  -- achievement bitmask (nil from versions before 2.6.0: count only)
  local function Hex(s) return (s and s:match("^%x%x?%x?%x?%x?%x?%x?%x?$")) and s or nil end
  e.achMask, e.achMask2 = Hex(p[29]), Hex(p[30])
  -- the sender's own day and month (older versions: the time it arrived)
  e.todayKey = (p[26] and p[26] ~= "") and Clean(p[26], 12) or date("%Y-%m-%d")
  e.monthKey = (p[27] and p[27] ~= "") and Clean(p[27], 12) or ("M" .. date("%Y-%m"))
  CheckOvertakes(guid)
end

local function HandleActivity(guid, p)
  local id = tonumber(p[4])
  if not id or ns.db.social.people[guid].flagged or N(p[5]) > 7 * DAY_MAX then return end
  local feed = ns.db.social.feed
  for _, f in ipairs(feed) do
    if f.from == guid and f.id == id and not f.event then return end
  end
  if not AllowNews(guid) then return end
  local zones = {}
  for z in (p[10] or ""):gmatch("[^,]+") do
    z = Clean(z)
    if z ~= "" and #zones < 10 then table.insert(zones, z) end
  end
  local item = { from = guid, id = id, steps = N(p[5]), distance = N(p[6]), moving = N(p[7]),
                 elapsed = N(p[8]), finish = N(p[9]), zones = zones, received = time() }
  table.insert(feed, item)
  table.sort(feed, function(a, b) return (a.finish or 0) > (b.finish or 0) end)
  while #feed > FEED_CAP do table.remove(feed) end

  -- Only announce fresh activities (not old ones sent as a hello reply)
  if ns.settings.socialChat and time() - item.finish < 600 then
    ns.Print((L["%s finished an activity: %s steps, %s in %s. Give kudos in /aws social"]):format(
      ns.PlayerLink(guid), F.Number(item.steps), F.Distance(item.distance), F.Time(item.moving)))
  end
end

local function HandleKudos(guid, p)
  if p[5] and p[5] ~= "" and p[5] ~= S.MyGUID() then return end -- for someone else (guild channel)
  local id = tonumber(p[4])
  local from = ShortName(ns.db.social.people[guid].name)
  for _, a in ipairs(ns.cdb.history) do
    if a.start == id then
      a.kudos = a.kudos or {}
      for _, n in ipairs(a.kudos) do
        local other = ns.db.social.people[n]
        if n == guid or (other and ShortName(other.name) == from) then return end -- one per person
      end
      table.insert(a.kudos, guid)
      ns.cdb.kudosReceived = ns.cdb.kudosReceived + 1
      local text = (L["%s gave you kudos for your %s-step activity!"]):format(ns.PlayerLink(guid), F.Number(a.steps))
      ns.Print(text)
      ns.Banner.Toast({ title = L["Kudos!"], text = text, icon = "Interface\\Icons\\Spell_Holy_GreaterHeal",
        open = { tab = 2 } })
      ns.Achievements.Check()
      return
    end
  end
end

-- Text for a friend's challenge/achievement/rank event, or nil if unknown
local function EventText(kind, id)
  if kind == "c" then
    local ch = ns.Challenges.ById(id)
    if ch then
      return (L["completed the %s challenge |cffffd100%s|r"]):format(ns.Challenges.TierName(ch), ns.ChallengeLink(ch)),
        ns.Challenges.TIERS[ch.tier].icon
    end
  elseif kind == "w" then
    return ns.Link("w", "champion", L["became |cffffd100Weekly Champion|r!"]), "Interface\\Icons\\INV_Misc_Head_Dragon_01"
  elseif kind == "a" then
    local a = ns.Achievements.ById(id)
    if a then return (L["earned |cffffd100%s|r"]):format(ns.AchievementLink(a)), a.icon end
  elseif kind == "r" then
    return L["ranked up to "] .. ns.Link("r", id, "[" .. ns.Achievements.RankColored(tonumber(id)) .. "]"),
      "Interface\\Icons\\Ability_Rogue_Sprint"
  end
end

local function HandleEvent(guid, p)
  local kind, id, period = p[4], p[5], p[6] or ""
  if kind == "r" then
    local r = tonumber(id)
    if not r or r < 2 or r > #ns.Achievements.RANKS or r ~= math.floor(r) then return end
  end
  if kind == "c" or kind == "w" then
    if not LivePeriods()[period] then return end -- unknown or long-gone period
  else
    period = "" -- achievements and ranks don't belong to a period
  end
  local text, icon = EventText(kind, id)
  if not text then return end

  if kind == "c" or kind == "w" then
    local comp = ns.db.social.completions
    comp[period] = comp[period] or {}
    local key = kind == "w" and "champion" or id
    comp[period][key] = comp[period][key] or {}
    comp[period][key][guid] = true
  end

  local feed = ns.db.social.feed
  for _, f in ipairs(feed) do
    if f.event and f.from == guid and f.kind == kind and f.eid == id and f.period == period then return end
  end
  if not AllowNews(guid) then return end
  table.insert(feed, 1, { event = true, from = guid, kind = kind, eid = id, period = period, finish = time(),
                          text = text, icon = icon })
  while #feed > FEED_CAP do table.remove(feed) end

  local line = ns.PlayerLink(guid) .. " " .. text
  if ns.settings.socialChat then ns.Print(line) end
  ns.Banner.Toast({ title = L["Friend news"], text = line, icon = icon, open = { profile = guid } })
end

-- via: "GUILD", "WHISPER", "CHANNEL" or "BN"
local function OnMessage(msg, name, dest, via)
  local p = { strsplit(";", msg) }
  local kind, guid = p[1], p[3]
  if p[2] ~= VERSION or not guid or guid == "" or guid == S.MyGUID() then return end
  -- From strangers on the Everyone channel, only stats and hellos are used
  if via == "CHANNEL" and kind ~= "S" and kind ~= "H" then return end
  if not guid:match("^Player%-") then return end -- only real player IDs

  local people = ns.db.social.people
  local e = people[guid]
  -- A GUID belongs to one character: ignore it coming from someone else
  -- (a renamed character is accepted once it's been quiet for a day)
  if e and e.name and name and ShortName(e.name) ~= ShortName(name) and time() - (e.updated or 0) < 86400 then
    NetLog("ignored a message claiming to be %s from %s", S.Short(e.name), S.Short(name))
    return
  end
  if not e then
    e = {}
    people[guid] = e
  end
  e.name = name or e.name
  if via ~= "CHANNEL" or not e.dest then e.dest = dest end
  e.updated = time()
  if via == "GUILD" then e.viaGuild = true end
  if via == "BN" then e.bnFriend = true end

  if kind == "H" then
    -- On the busy Everyone channel only about 1 in 5 players answer a hello;
    -- the rest reach the newcomer with their regular updates within minutes
    if via == "CHANNEL" and math.random() > 0.2 then return ns.OnSocialChanged() end
    local delay = via == "CHANNEL" and (2 + math.random() * 20) or (1 + math.random() * 4)
    C_Timer.After(delay, function() ReplyToHello(dest, via == "CHANNEL") end)
  elseif kind == "S" then
    HandleStats(guid, p)
  elseif kind == "A" then
    HandleActivity(guid, p)
  elseif kind == "K" then
    HandleKudos(guid, p)
  elseif kind == "C" then
    HandleEvent(guid, p)
  elseif kind == "RQ" then
    S.HandleRouteRequest(guid, p, dest)
    return
  elseif kind == "RP" then
    S.HandleRouteReply(guid, p)
    return
  end
  ns.OnSocialChanged()
end

---------------------------------------------------------------------------
-- Data shown in the Social tab
---------------------------------------------------------------------------
-- Does a person belong on this leaderboard? category: "friends" | "guild" | "everyone"
local function InCategory(e, category)
  if category == "friends" then return S.IsFriend(e) end
  if category == "guild" then return S.IsGuild(e) end
  return true
end

-- Steps a friend has probably walked since their last update, from the
-- walking speed they sent. Corrected by the next real update.
local function LiveExtra(e)
  if not (e.active and e.rate and e.rate > 0 and e.clock and S.IsOnline(e)) then return 0 end
  local since = GetTime() - e.clock
  if since < 0 then return 0 end -- clock from an earlier session (after /reload)
  return e.rate * math.min(since, LIVE_WINDOW)
end

-- period: "today" | "week" | "month" | "all"
local myRow, myRowKey

function S.Leaderboard(period, category)
  local Ch = ns.Challenges
  local todayKey, weekKey, monthKey = date("%Y-%m-%d"), Ch.WeekPeriod().key, "M" .. date("%Y-%m")
  local c = ns.cdb
  local cur = c.current
  -- week, month, streak and challenges only change when you walk or a day starts
  local fp = math.floor(c.total.steps) .. ":" .. todayKey .. ":" .. #c.badges
  if fp ~= myRowKey then
    myRowKey = fp
    myRow = { week = Ch.WeekSteps(), month = Ch.MonthSteps(), streak = (ns.Streaks()),
              weekDone = Ch.WeekChallengesDone() }
  end
  local me = {
    guid = S.MyGUID(), me = true, online = true, active = cur and not cur.paused, sessionSteps = cur and cur.steps or 0,
    today = ns.GetDay(todayKey).s, week = myRow.week, month = myRow.month, all = c.total.steps,
    streak = myRow.streak, rank = ns.Achievements.MyRank(), trophies = ns.Achievements.Count() + #c.badges,
    weekDone = myRow.weekDone, walking = ns.state.moving and cur and not cur.paused,
  }
  local rows = { me }
  for guid, e in pairs(ns.db.social.people) do
    if e.all and not e.flagged and InCategory(e, category or "everyone") then
      local extra = LiveExtra(e)
      local today = e.todayKey == todayKey and e.today or 0
      local week = e.weekKey == weekKey and e.week or 0
      local month = e.monthKey == monthKey and e.month or 0
      table.insert(rows, {
        guid = guid, e = e, online = S.IsOnline(e), active = S.IsOnline(e) and e.active,
        sessionSteps = (e.sessionSteps or 0) + extra, walking = extra > 0,
        today = today + extra, week = week + extra, month = month + extra, all = e.all + extra,
        streak = e.streak or 0, rank = e.rank or 1, trophies = (e.ach or 0) + (e.badges or 0),
        weekDone = e.weekKey == weekKey and e.weekDone or 0,
      })
    end
  end
  period = period or "week"
  for _, r in ipairs(rows) do r.value = r[period] or 0 end
  table.sort(rows, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.all > b.all
  end)
  return rows
end

-- Feed: friends' activities and events + your own recent activities, newest first
function S.Feed()
  local items = {}
  for _, f in ipairs(ns.db.social.feed) do table.insert(items, f) end
  local me = S.MyGUID()
  for i = 1, math.min(50, #ns.cdb.history) do
    local a = ns.cdb.history[i]
    table.insert(items, { from = me, mine = true, id = a.start, steps = a.steps, distance = a.distance,
      moving = a.moving, elapsed = a.elapsed, finish = a.finish, zones = a.zones, kudosList = a.kudos, src = a })
  end
  table.sort(items, function(a, b) return (a.finish or 0) > (b.finish or 0) end)
  return items
end

function S.FriendCount(category)
  local n = 0
  for _, e in pairs(ns.db.social.people) do
    if e.all and not e.flagged and InCategory(e, category or "everyone") then n = n + 1 end
  end
  return n
end

-- Forget strangers not seen for 60 days, and keep the list a sane size
local function Prune()
  -- friends' challenge completions: only periods that can still matter
  local live, comp = LivePeriods(), ns.db.social.completions
  for key in pairs(comp) do
    if not live[key] then comp[key] = nil end
  end

  local people, cutoff = ns.db.social.people, time() - 60 * 86400
  local list = {}
  for guid, e in pairs(people) do
    if not InCircle(e) and (e.updated or 0) < cutoff then people[guid] = nil
    else table.insert(list, { guid = guid, t = e.updated or 0, keep = InCircle(e) }) end
  end
  if #list > PEOPLE_CAP then
    table.sort(list, function(a, b) return a.t > b.t end)
    for i = PEOPLE_CAP + 1, #list do
      if not list[i].keep then people[list[i].guid] = nil end
    end
  end
end

---------------------------------------------------------------------------
-- Share an activity as a chat line (you pick the channel and press Enter)
---------------------------------------------------------------------------
function S.ShareText(a)
  local zone = a.zones and a.zones[1]
  return (L["[Azeroth Walking Simulator] %s steps, %s in %s (pace %s)%s - Rank: %s"]):format(F.Number(a.steps),
    F.Distance(a.distance), F.Time(a.moving), F.Pace(a.moving, a.distance), zone and (L[" around "] .. zone) or "",
    ns.Achievements.RankName(ns.Achievements.MyRank()))
end

function S.ShareToChat(a)
  if not a then return ns.Print(L["No activity to share yet."]) end
  local text = S.ShareText(a)
  if ChatFrame_OpenChat then ChatFrame_OpenChat(text) else ns.Print(text) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:RegisterEvent("BN_CHAT_MSG_ADDON")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    if IsInGuild() then
      if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
    end
    Recipients() -- fills the friend list cache
    Prune()
    C_Timer.After(6, JoinChannel)
    C_Timer.NewTicker(60, WatchChannel)
    C_Timer.After(10, SayHello)
    C_Timer.NewTicker(BROADCAST_INTERVAL, function()
      S.BroadcastStats(false)
      CheckOvertakes()
    end)
  elseif event == "CHAT_MSG_ADDON" then
    if a1 ~= PREFIX or not ns.db then return end
    local full = S.FullName(a4)
    OnMessage(a2, full, { kind = "WHISPER", target = full, key = full }, a3)
  elseif event == "BN_CHAT_MSG_ADDON" then
    if a1 ~= PREFIX or not ns.db then return end
    local info = C_BattleNet and C_BattleNet.GetGameAccountInfoByID and C_BattleNet.GetGameAccountInfoByID(a4)
    if not info or not info.characterName then return end
    local full = S.FullName(info.characterName, info.realmName)
    OnMessage(a2, full, { kind = "BN", id = a4, key = full }, "BN")
  else
    UpdateGuild()
  end
end)
