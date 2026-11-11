local _, ns = ...

-- Translations. English text is the key: L["Today"] returns the translation
-- for the game's language, or the English text if there isn't one.
-- The language always follows the game client. It's applied when saved
-- settings load (ns.ApplyLanguage), so L[...] must only be read inside
-- functions, never while files load.

-- Game client language -> our translation. WoW's only Portuguese client is
-- ptBR; it gets the European Portuguese (pt-PT) translation.
local FROM_GAME = {
  ptBR = "ptPT", ptPT = "ptPT",
  esES = "esES", esMX = "esES",
  frFR = "frFR", deDE = "deDE", itIT = "itIT",
}

local tables = {}   -- [code] = { [english] = translation }
local active = {}

function ns.RegisterLocale(code, strings)
  tables[code] = strings
end

ns.L = setmetatable({}, {
  __index = function(_, key)
    return active[key] or key
  end,
})

-- The translation code for the game's language ("enUS" = English)
function ns.ResolveLanguage()
  local game = GetLocale and GetLocale() or "enUS"
  return FROM_GAME[game] or "enUS"
end

function ns.ApplyLanguage()
  local code = ns.ResolveLanguage()
  active = tables[code] or {}
  ns.languageCode = code
end
