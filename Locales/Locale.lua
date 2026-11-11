local _, ns = ...

-- Translations. English text is the key: L["Today"] returns the translation
-- for the chosen language, or the English text if there isn't one.
-- The language is chosen when saved settings load (ns.ApplyLanguage), so
-- L[...] must only be read inside functions, never while files load.

ns.LANGUAGES = {
  { code = "auto", name = "Auto (game language)" },
  { code = "enUS", name = "English" },
  { code = "ptPT", name = "Português (Portugal)" },
  { code = "esES", name = "Español" },
  { code = "frFR", name = "Français" },
  { code = "deDE", name = "Deutsch" },
  { code = "itIT", name = "Italiano" },
  { code = "fiFI", name = "Suomi" },
  { code = "svSE", name = "Svenska" },
}

-- Game client language -> our translation. WoW has no Finnish, Swedish or
-- European Portuguese client: Portuguese clients get Portuguese (Portugal),
-- Finnish and Swedish players pick their language in Settings.
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

-- Which language code a setting value means right now
function ns.ResolveLanguage(setting)
  if setting and setting ~= "auto" and (tables[setting] or setting == "enUS") then return setting end
  local game = GetLocale and GetLocale() or "enUS"
  return FROM_GAME[game] or "enUS"
end

function ns.ApplyLanguage(setting)
  local code = ns.ResolveLanguage(setting)
  active = tables[code] or {}
  ns.languageCode = code
end
