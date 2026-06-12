AzerColectDB = type(AzerColectDB) == "table" and AzerColectDB or {}

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_LOGOUT")

local ADDON_REVISION = "performance-2026-06-10"
local ADDON_DISPLAY_NAME = "MountAtlas"
local ROW_COUNT = 6
local FRAME_WIDTH = 1240
local FRAME_HEIGHT = 620
local SIDEBAR_WIDTH = 184
local CONTENT_LEFT = 220
local ROW_WIDTH = 640
local ROW_HEIGHT = 58
local ROW_GAP = 7
local LIST_TOP = -188
local PREVIEW_WIDTH = 354
local PREVIEW_HEIGHT = 388
local PRIORITY_RECOMMENDATION_COUNT = 3
local DEFAULT_MOUNT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_ACHIEVEMENT_ICON = "Interface\\Icons\\Achievement_General"
local MINIMAP_ICON_TEXTURE = "Interface\\AddOns\\AzerColect\\Textures\\MountAtlas"
local ACTION_ICON_DONE = "Interface\\Buttons\\UI-CheckBox-Check"
local ACTION_ICON_CLEAR = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local ACTION_ICON_FAVORITE = "Interface\\COMMON\\ReputationStar"
local ACTION_ICON_VIEW = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local READABILITY_FONT_BONUS = 2
local NEW_MOUNT_ALERT_DURATION = 7
local DAILY_ROUTE_LIMIT = 5
local AUTO_CATALOG_BATCH_SIZE = 12
local AUTO_CATALOG_BATCH_DELAY = 0.02
local currentMode = "today"
local currentPage = 1
local currentScrollOffset = 0
local filtersAdvancedOpen = false
local mainFrame
local minimapButton
local rows = {}
local lastMinimapError

local HandleSlashCommand
local RestoreMinimapButton
local RegisterSlashCommands

local RefreshWindow
local SetMode
local UpdateFilterButtons
local ShowMountPreview
local ClearMountPreview
local ExtractMountNameFromReward
local GetMountDisplayName
local ApplyModeDefaults

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. ADDON_DISPLAY_NAME .. ":|r " .. msg)
end

local function L(key, ...)
  if AzerColectText then
    return AzerColectText(key, ...)
  end

  return key
end

RegisterSlashCommands = function()
  SLASH_AZERCOLECT1 = "/azer"
  SLASH_AZERCOLECT2 = "/azercolect"
  SLASH_AZERCOLECT3 = "/azercollect"
  SLASH_AZERCOLECT4 = "/mountatlas"
  SLASH_AZERCOLECT5 = "/mounts"
  SLASH_AZERCOLECT6 = "/ma"
  SlashCmdList["AZERCOLECT"] = function(msg)
    if HandleSlashCommand then
      return HandleSlashCommand(msg)
    end

    Print("debug: " .. ADDON_REVISION .. ", slash registrado, Core.lua no termino de cargar.")
  end

  SLASH_AZERCOLECTMINIMAP1 = "/azermini"
  SLASH_AZERCOLECTMINIMAP2 = "/azerminimap"
  SLASH_AZERCOLECTMINIMAP3 = "/azericono"
  SLASH_AZERCOLECTMINIMAP4 = "/mountatlasmini"
  SlashCmdList["AZERCOLECTMINIMAP"] = function()
    if RestoreMinimapButton then
      return RestoreMinimapButton()
    end

    Print("debug: " .. ADDON_REVISION .. ", minimapa aun no disponible.")
  end
end

RegisterSlashCommands()

local resetLabels = {
  daily = L("resetDaily"),
  weekly = L("resetWeekly"),
  repeatable = L("resetRepeatable"),
  event = L("resetEvent"),
  special = L("resetSpecial"),
  catalog = L("resetCatalog")
}

local modeLabels = {
  today = L("modeToday"),
  weekly = L("modeWeekly"),
  all = L("modeAll"),
  favorites = L("modeFavorites"),
  achievements = L("modeAchievements"),
  sources = L("modeSources"),
  reputation = L("modeReputation"),
  events = L("modeEvents"),
  routes = L("modeRoutes"),
  missingEasy = L("modeMissingEasy")
}

local UI_THEME = {
  background = { 0.01, 0.014, 0.028 },
  panel = { 0.018, 0.026, 0.052 },
  panelAlt = { 0.035, 0.044, 0.076 },
  neutral = { 0.08, 0.095, 0.13 },
  gold = { 1, 0.72, 0.22 },
  goldSoft = { 0.85, 0.55, 0.16 },
  blue = { 0.08, 0.54, 1 },
  cyan = { 0.12, 0.86, 1 },
  green = { 0.26, 0.95, 0.24 },
  red = { 1, 0.24, 0.34 },
  purple = { 0.72, 0.26, 1 },
  orange = { 1, 0.48, 0.1 },
  text = { 0.93, 0.95, 1 },
  textMuted = { 0.68, 0.74, 0.86 }
}

local MODE_COLORS = {
  today = UI_THEME.cyan,
  weekly = UI_THEME.purple,
  all = UI_THEME.gold,
  favorites = { 1, 0.62, 0.08 },
  achievements = UI_THEME.green,
  sources = UI_THEME.blue,
  reputation = UI_THEME.purple,
  events = UI_THEME.red,
  routes = UI_THEME.orange,
  missingEasy = UI_THEME.green
}

local EVENT_ALIASES = {
  ["love is in the air"] = {
    "love is in the air",
    "amor en el aire"
  },
  ["hallows end"] = {
    "hallow's end",
    "hallows end",
    "halloween",
    "noche de brujas"
  },
  brewfest = {
    "brewfest",
    "fiesta de la cerveza",
    "festival de la cerveza"
  },
  timewalking = {
    "timewalking",
    "timewalking dungeon event",
    "paseo en el tiempo"
  }
}

local expansionFilterOptions = {
  { value = "all", label = L("optionAll") },
  { value = "Classic", label = "Classic" },
  { value = "Burning Crusade", label = "BC" },
  { value = "Wrath", label = "Wrath" },
  { value = "Cataclysm", label = "Cata" },
  { value = "Pandaria", label = "Pandaria" },
  { value = "Draenor", label = "Draenor" },
  { value = "Legion", label = "Legion" },
  { value = "BFA", label = "BFA" },
  { value = "Shadowlands", label = "Shadowlands" },
  { value = "Dragonflight", label = "Dragonflight" },
  { value = "The War Within", label = "TWW" },
  { value = "Midnight", label = "Midnight" }
}

local sourceFilterOptions = {
  { value = "all", label = L("optionAll") },
  { value = "Dungeon", label = L("sourceDungeon") },
  { value = "Raid", label = L("sourceRaid") },
  { value = "World boss", label = L("sourceWorldBoss") },
  { value = "World quest", label = L("sourceWorldQuest") },
  { value = "Rare", label = L("sourceRare") },
  { value = "Achievement", label = L("sourceAchievement") },
  { value = "Delves", label = L("sourceDelves") },
  { value = "Vendor", label = L("sourceVendor") },
  { value = "Quest", label = L("sourceQuest") },
  { value = "Reputation", label = L("sourceReputation") },
  { value = "Event", label = L("sourceEvent") },
  { value = "Profession", label = L("sourceProfession") },
  { value = "Secret", label = L("sourceSecret") },
  { value = "Other", label = L("sourceOther") }
}

local sourceModeOptions = {
  { value = "Vendor", label = L("sourceVendor") },
  { value = "Achievement", label = L("sourceAchievement") },
  { value = "Raid", label = L("sourceRaid") },
  { value = "Dungeon", label = L("sourceDungeon") },
  { value = "Reputation", label = L("sourceReputation") },
  { value = "Event", label = L("sourceEvent") },
  { value = "Profession", label = L("sourceProfession") },
  { value = "Other", label = L("sourceOther") },
  { value = "all", label = L("optionAll") }
}

local collectionFilterOptions = {
  { value = "missing", label = L("collectionMissing") },
  { value = "collected", label = L("collectionCollected") },
  { value = "all", label = L("collectionAll") }
}

local currentExpansionFilter = "all"
local currentSourceFilter = "all"
local currentCollectionFilter = "missing"
local currentSearchText = ""
AzerColectRuntime = AzerColectRuntime or {
  cacheRevision = 0,
  lastCharacterSnapshotAt = 0,
  CHARACTER_SNAPSHOT_THROTTLE = 8,
  SEARCH_REFRESH_DELAY = 0.15
}
AzerColectRuntime.cacheRevision = AzerColectRuntime.cacheRevision or 0
AzerColectRuntime.lastCharacterSnapshotAt = AzerColectRuntime.lastCharacterSnapshotAt or 0
AzerColectRuntime.CHARACTER_SNAPSHOT_THROTTLE = AzerColectRuntime.CHARACTER_SNAPSHOT_THROTTLE or 8
AzerColectRuntime.SEARCH_REFRESH_DELAY = AzerColectRuntime.SEARCH_REFRESH_DELAY or 0.15
local autoCatalogLoaded = false
local autoCatalogAdded = 0

local DEFAULT_OPTIONS = {
  showInactiveEvents = true,
  dailyRouteSkipAttempted = true,
  dailyRouteAutoWaypoint = true
}

local function Trim(text)
  return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function Normalize(text)
  local value = string.lower(Trim(text))

  value = value:gsub("\195\129", "a"):gsub("\195\161", "a")
  value = value:gsub("\195\137", "e"):gsub("\195\169", "e")
  value = value:gsub("\195\141", "i"):gsub("\195\173", "i")
  value = value:gsub("\195\147", "o"):gsub("\195\179", "o")
  value = value:gsub("\195\154", "u"):gsub("\195\186", "u")
  value = value:gsub("\195\156", "u"):gsub("\195\188", "u")
  value = value:gsub("\195\145", "n"):gsub("\195\177", "n")

  return value
end

local PROFESSION_ALIASES = {
  {
    label = { enUS = "Engineering", esMX = "Ingenieria" },
    aliases = { "engineering", "ingenieria", "engineer", "ingeniero", "gnomish engineering", "goblin engineering", "schematic", "esquema", "sky golem", "flying machine", "world spinner", "kyparium rocket", "mechano-hog", "mekgineer" }
  },
  {
    label = { enUS = "Tailoring", esMX = "Sastreria" },
    aliases = { "tailoring", "sastreria", "tailor", "sastre", "flying carpet", "creeping carpet" }
  },
  {
    label = { enUS = "Leatherworking", esMX = "Peleteria" },
    aliases = { "leatherworking", "peleteria", "leatherworker", "peletero" }
  },
  {
    label = { enUS = "Jewelcrafting", esMX = "Joyeria" },
    aliases = { "jewelcrafting", "joyeria", "jewelcrafter", "joyero", "jeweled panther", "onyx panther", "ruby panther", "sapphire panther", "jade panther", "sunstone panther" }
  },
  {
    label = { enUS = "Alchemy", esMX = "Alquimia" },
    aliases = { "alchemy", "alquimia", "alchemist", "alquimista", "vial of the sands", "frasco de las arenas" }
  },
  {
    label = { enUS = "Blacksmithing", esMX = "Herreria" },
    aliases = { "blacksmithing", "herreria", "blacksmith", "herrero", "steelbound devourer" }
  },
  {
    label = { enUS = "Inscription", esMX = "Inscripcion" },
    aliases = { "inscription", "inscripcion", "scribe", "escriba" }
  },
  {
    label = { enUS = "Enchanting", esMX = "Encantamiento" },
    aliases = { "enchanting", "encantamiento", "enchanter", "encantador" }
  },
  {
    label = { enUS = "Fishing", esMX = "Pesca" },
    aliases = { "fishing", "pesca", "angler", "pescador" }
  },
  {
    label = { enUS = "Archaeology", esMX = "Arqueologia" },
    aliases = { "archaeology", "arqueologia", "archaeologist", "arqueologo" }
  }
}

function InvalidateAzerColectDataCache()
  AzerColectRuntime.cacheRevision = AzerColectRuntime.cacheRevision + 1
  AzerColectRuntime.itemListCacheKey = nil
  AzerColectRuntime.itemListCacheItems = nil
  AzerColectRuntime.itemListCacheEmptyText = nil
  AzerColectRuntime.collectionStatsCacheRevision = nil
  AzerColectRuntime.collectionStatsCache = nil
  AzerColectRuntime.expansionProgressCacheRevision = nil
  AzerColectRuntime.expansionProgressOrdered = nil
  AzerColectRuntime.expansionProgressStats = nil
  AzerColectRuntime.priorityPlanCacheKey = nil
  AzerColectRuntime.priorityPlanCache = nil
end

function InvalidateMountJournalCaches()
  autoCatalogLoaded = false
  autoCatalogAdded = 0
  AzerColectRuntime.autoCatalogLoading = nil
  AzerColectRuntime.autoCatalogMountIDs = nil
  AzerColectRuntime.autoCatalogConfiguredMountIDs = nil
  AzerColectRuntime.autoCatalogIndex = nil
  AzerColectRuntime.mountJournalNameCache = nil
  AzerColectRuntime.collectedMountNameCache = nil
  AzerColectRuntime.collectedMountIDCache = nil
  AzerColectRuntime.mountDisplayNameCache = nil
  AzerColectRuntime.mountIconCache = nil
  AzerColectRuntime.mountDisplayIDCache = nil
  AzerColectRuntime.journalMountInfoCache = nil
  AzerColectRuntime.journalMountExtraCache = nil
  AzerColectRuntime.mountSearchTextCache = nil
  AzerColectRuntime.unavailableReasonCache = nil
  InvalidateAzerColectDataCache()
end

function QueueRefreshWindow(delay)
  if not mainFrame or not mainFrame:IsShown() then
    return
  end

  if AzerColectRuntime.refreshQueued then
    return
  end

  AzerColectRuntime.refreshQueued = true

  if C_Timer and C_Timer.After then
    C_Timer.After(delay or 0.05, function()
      AzerColectRuntime.refreshQueued = false

      if mainFrame and mainFrame:IsShown() and RefreshWindow then
        RefreshWindow()
      end
    end)
  else
    AzerColectRuntime.refreshQueued = false
    RefreshWindow()
  end
end

function ScheduleCharacterSnapshot(delay)
  if AzerColectRuntime.snapshotQueued then
    return
  end

  AzerColectRuntime.snapshotQueued = true

  if C_Timer and C_Timer.After then
    C_Timer.After(delay or 5, function()
      AzerColectRuntime.snapshotQueued = false
      UpdateCurrentCharacterSnapshot(true)
      QueueRefreshWindow(0.05)
    end)
  else
    AzerColectRuntime.snapshotQueued = false
    UpdateCurrentCharacterSnapshot(true)
  end
end

local zoneExpansionMap = {
  ["Stratholme"] = "Classic",
  ["Blackrock Depths"] = "Classic",
  ["Blackrock Spire"] = "Classic",
  ["Molten Core"] = "Classic",
  ["Ahn'Qiraj"] = "Classic",
  ["Ruins of Ahn'Qiraj"] = "Classic",
  ["Temple of Ahn'Qiraj"] = "Classic",
  ["Sethekk Halls"] = "Burning Crusade",
  ["Magisters' Terrace"] = "Burning Crusade",
  ["Magister's Terrace"] = "Burning Crusade",
  ["Tempest Keep"] = "Burning Crusade",
  ["Karazhan"] = "Burning Crusade",
  ["Netherstorm"] = "Burning Crusade",
  ["Terokkar Forest"] = "Burning Crusade",
  ["Isle of Quel'Danas"] = "Burning Crusade",
  ["Shattrath"] = "Burning Crusade",
  ["Outland"] = "Burning Crusade",
  ["Northrend"] = "Wrath",
  ["Rasganorte"] = "Wrath",
  ["Borean Tundra"] = "Wrath",
  ["Tundra Boreal"] = "Wrath",
  ["Howling Fjord"] = "Wrath",
  ["Fiordo Aquilonal"] = "Wrath",
  ["Dragonblight"] = "Wrath",
  ["Cementerio de Dragones"] = "Wrath",
  ["Grizzly Hills"] = "Wrath",
  ["Colinas Pardas"] = "Wrath",
  ["Zul'Drak"] = "Wrath",
  ["Sholazar Basin"] = "Wrath",
  ["Cuenca de Sholazar"] = "Wrath",
  ["Crystalsong Forest"] = "Wrath",
  ["Bosque Canto de Cristal"] = "Wrath",
  ["Wintergrasp"] = "Wrath",
  ["Conquista del Invierno"] = "Wrath",
  ["Icecrown"] = "Wrath",
  ["Corona de Hielo"] = "Wrath",
  ["Dalaran"] = "Wrath",
  ["The Oculus"] = "Wrath",
  ["El Oculus"] = "Wrath",
  ["Vault of Archavon"] = "Wrath",
  ["Camara de Archavon"] = "Wrath",
  ["Trial of the Crusader"] = "Wrath",
  ["Prueba del Cruzado"] = "Wrath",
  ["Argent Tournament"] = "Wrath",
  ["Torneo Argenta"] = "Wrath",
  ["The Storm Peaks"] = "Wrath",
  ["Las Cumbres Tormentosas"] = "Wrath",
  ["The Culling of Stratholme"] = "Wrath",
  ["La Matanza de Stratholme"] = "Wrath",
  ["Utgarde Pinnacle"] = "Wrath",
  ["Pinaculo de Utgarde"] = "Wrath",
  ["The Eye"] = "Burning Crusade",
  ["Eye of Eternity"] = "Wrath",
  ["Ojo de la Eternidad"] = "Wrath",
  ["The Obsidian Sanctum"] = "Wrath",
  ["Sagrario Obsidiana"] = "Wrath",
  ["Onyxia's Lair"] = "Wrath",
  ["Guarida de Onyxia"] = "Wrath",
  ["Ulduar"] = "Wrath",
  ["Icecrown Citadel"] = "Wrath",
  ["Ciudadela de la Corona de Hielo"] = "Wrath",
  ["Eastern Kingdoms"] = "Classic",
  ["Kalimdor"] = "Classic",
  ["Deepholm"] = "Cataclysm",
  ["Uldum"] = "Cataclysm",
  ["Mount Hyjal"] = "Cataclysm",
  ["Vashj'ir"] = "Cataclysm",
  ["Twilight Highlands"] = "Cataclysm",
  ["The Stonecore"] = "Cataclysm",
  ["The Vortex Pinnacle"] = "Cataclysm",
  ["Zul'Gurub"] = "Cataclysm",
  ["Zul'Aman"] = "Cataclysm",
  ["Throne of the Four Winds"] = "Cataclysm",
  ["Firelands"] = "Cataclysm",
  ["Dragon Soul"] = "Cataclysm",
  ["Mogu'shan Vaults"] = "Pandaria",
  ["Throne of Thunder"] = "Pandaria",
  ["Siege of Orgrimmar"] = "Pandaria",
  ["Kun-Lai Summit"] = "Pandaria",
  ["Valley of the Four Winds"] = "Pandaria",
  ["Isle of Thunder"] = "Pandaria",
  ["Isle of Giants"] = "Pandaria",
  ["Vale of Eternal Blossoms"] = "Pandaria",
  ["Timeless Isle"] = "Pandaria",
  ["Jade Forest"] = "Pandaria",
  ["Krasarang Wilds"] = "Pandaria",
  ["Townlong Steppes"] = "Pandaria",
  ["Dread Wastes"] = "Pandaria",
  ["Shrine of Two Moons"] = "Pandaria",
  ["Shrine of Seven Stars"] = "Pandaria",
  ["Draenor"] = "Draenor",
  ["Frostfire Ridge"] = "Draenor",
  ["Shadowmoon Valley"] = "Draenor",
  ["Gorgrond"] = "Draenor",
  ["Talador"] = "Draenor",
  ["Spires of Arak"] = "Draenor",
  ["Nagrand"] = "Draenor",
  ["Tanaan Jungle"] = "Draenor",
  ["Highmaul"] = "Draenor",
  ["Blackrock Foundry"] = "Draenor",
  ["Hellfire Citadel"] = "Draenor",
  ["Broken Isles"] = "Legion",
  ["Azsuna"] = "Legion",
  ["Val'sharah"] = "Legion",
  ["Highmountain"] = "Legion",
  ["Stormheim"] = "Legion",
  ["Suramar"] = "Legion",
  ["Broken Shore"] = "Legion",
  ["Argus"] = "Legion",
  ["Mac'Aree"] = "Legion",
  ["Antoran Wastes"] = "Legion",
  ["Krokuun"] = "Legion",
  ["Tomb of Sargeras"] = "Legion",
  ["Antorus"] = "Legion",
  ["Return to Karazhan"] = "Legion",
  ["Kul Tiras"] = "BFA",
  ["Zandalar"] = "BFA",
  ["Tiragarde Sound"] = "BFA",
  ["Drustvar"] = "BFA",
  ["Stormsong Valley"] = "BFA",
  ["Zuldazar"] = "BFA",
  ["Nazmir"] = "BFA",
  ["Vol'dun"] = "BFA",
  ["Nazjatar"] = "BFA",
  ["Mechagon"] = "BFA",
  ["Battle of Dazar'alor"] = "BFA",
  ["Ny'alotha"] = "BFA",
  ["Shadowlands"] = "Shadowlands",
  ["Bastion"] = "Shadowlands",
  ["Maldraxxus"] = "Shadowlands",
  ["Ardenweald"] = "Shadowlands",
  ["Revendreth"] = "Shadowlands",
  ["The Maw"] = "Shadowlands",
  ["Korthia"] = "Shadowlands",
  ["Zereth Mortis"] = "Shadowlands",
  ["Sanctum of Domination"] = "Shadowlands",
  ["Sepulcher of the First Ones"] = "Shadowlands",
  ["Dragon Isles"] = "Dragonflight",
  ["The Waking Shores"] = "Dragonflight",
  ["Ohn'ahran Plains"] = "Dragonflight",
  ["The Azure Span"] = "Dragonflight",
  ["Thaldraszus"] = "Dragonflight",
  ["Valdrakken"] = "Dragonflight",
  ["Forbidden Reach"] = "Dragonflight",
  ["The Forbidden Reach"] = "Dragonflight",
  ["Zaralek Cavern"] = "Dragonflight",
  ["Emerald Dream"] = "Dragonflight",
  ["Amirdrassil"] = "Dragonflight",
  ["Khaz Algar"] = "The War Within",
  ["Isle of Dorn"] = "The War Within",
  ["The Ringing Deeps"] = "The War Within",
  ["Hallowfall"] = "The War Within",
  ["Azj-Kahet"] = "The War Within",
  ["Dornogal"] = "The War Within",
  ["Siren Isle"] = "The War Within",
  ["Undermine"] = "The War Within",
  ["Nerub-ar Palace"] = "The War Within",
  ["Liberation of Undermine"] = "The War Within",
  ["Quel'Thalas"] = "Midnight",
  ["Eversong Woods"] = "Midnight",
  ["Silvermoon City"] = "Midnight",
  ["Harandar"] = "Midnight",
  ["Voidstorm"] = "Midnight",
  ["Midnight Delves"] = "Midnight",
  ["Midnight Dungeons"] = "Midnight",
  ["Midnight Raids"] = "Midnight"
}

function GetOptionLabel(options, value)
  for _, option in ipairs(options) do
    if option.value == value then
      return option.label
    end
  end

  return value or L("optionAll")
end

function GetSourceDisplayName(source)
  if source == "Daily quest" then
    return L("sourceDailyQuest")
  end

  if source == "Raid Achievement" then
    return L("sourceRaid") .. " " .. L("sourceAchievement")
  end

  if source == "Dungeon Achievement" then
    return L("sourceDungeon") .. " " .. L("sourceAchievement")
  end

  if source == "Delves Achievement" then
    return L("sourceDelves") .. " " .. L("sourceAchievement")
  end

  return GetOptionLabel(sourceFilterOptions, source)
end

function FindOptionValue(options, query)
  local cleanQuery = Normalize(query)

  if cleanQuery == "" then
    return nil
  end

  local aliases = {
    bc = "Burning Crusade",
    tbc = "Burning Crusade",
    wotlk = "Wrath",
    lich = "Wrath",
    cata = "Cataclysm",
    mop = "Pandaria",
    wod = "Draenor",
    warlords = "Draenor",
    bfa = "BFA",
    sl = "Shadowlands",
    df = "Dragonflight",
    tww = "The War Within",
    warwithin = "The War Within",
    ["the war within"] = "The War Within",
    midnight = "Midnight",
    mid = "Midnight",
    calabozo = "Dungeon",
    calabozos = "Dungeon",
    dungeon = "Dungeon",
    dungeons = "Dungeon",
    mazmorra = "Dungeon",
    mazmorras = "Dungeon",
    masmorra = "Dungeon",
    masmorras = "Dungeon",
    donjon = "Dungeon",
    donjons = "Dungeon",
    raid = "Raid",
    raids = "Raid",
    logro = "Achievement",
    logros = "Achievement",
    achievement = "Achievement",
    achievements = "Achievement",
    conquista = "Achievement",
    conquistas = "Achievement",
    hautfait = "Achievement",
    hautsfaits = "Achievement",
    erfolg = "Achievement",
    erfolge = "Achievement",
    vendedor = "Vendor",
    vendedores = "Vendor",
    vendor = "Vendor",
    vendors = "Vendor",
    vendeur = "Vendor",
    vendeurs = "Vendor",
    haendler = "Vendor",
    reputacion = "Reputation",
    reputacao = "Reputation",
    reputation = "Reputation",
    ruf = "Reputation",
    evento = "Event",
    eventos = "Event",
    event = "Event",
    events = "Event",
    profesion = "Profession",
    profesiones = "Profession",
    profession = "Profession",
    professions = "Profession",
    quest = "Quest",
    quests = "Quest",
    mision = "Quest",
    misiones = "Quest",
    secreto = "Secret",
    secretos = "Secret",
    secret = "Secret",
    secrets = "Secret",
    otro = "Other",
    otros = "Other",
    other = "Other",
    others = "Other",
    faltante = "missing",
    faltantes = "missing",
    missing = "missing",
    pendiente = "missing",
    pendientes = "missing",
    pendente = "missing",
    pendentes = "missing",
    manquant = "missing",
    manquante = "missing",
    manquantes = "missing",
    offen = "missing",
    obtida = "collected",
    obtidas = "collected",
    obtenida = "collected",
    obtenidas = "collected",
    collected = "collected",
    complete = "collected",
    completed = "collected",
    obtenue = "collected",
    obtenues = "collected",
    erhalten = "collected",
    nodisponible = "unavailable",
    ["no disponible"] = "unavailable",
    ["no disponibles"] = "unavailable",
    retirada = "unavailable",
    retiradas = "unavailable",
    retirado = "unavailable",
    retirados = "unavailable",
    unobtainable = "unavailable",
    unavailable = "unavailable",
    retired = "unavailable",
    removed = "unavailable",
    todas = "all",
    todos = "all",
    all = "all",
    toutes = "all",
    alle = "all"
  }

  if aliases[cleanQuery] then
    for _, option in ipairs(options) do
      if option.value == aliases[cleanQuery] then
        return aliases[cleanQuery]
      end
    end
  end

  for _, option in ipairs(options) do
    if cleanQuery == Normalize(option.value) or cleanQuery == Normalize(option.label) then
      return option.value
    end
  end

  for _, option in ipairs(options) do
    if string.find(Normalize(option.value), cleanQuery, 1, true)
      or string.find(Normalize(option.label), cleanQuery, 1, true) then
      return option.value
    end
  end
end

function CycleOption(options, currentValue)
  for index, option in ipairs(options) do
    if option.value == currentValue then
      local nextOption = options[index + 1] or options[1]

      return nextOption.value
    end
  end

  return options[1].value
end

function PreviousOption(options, currentValue)
  for index, option in ipairs(options) do
    if option.value == currentValue then
      local previousOption = options[index - 1] or options[#options]

      return previousOption.value
    end
  end

  return options[1].value
end

function SourceMatches(source, filter)
  if filter == "all" then
    return true
  end

  local cleanSource = Normalize(source)
  local cleanFilter = Normalize(filter)

  if cleanSource == cleanFilter then
    return true
  end

  return string.find(cleanSource, cleanFilter, 1, true) ~= nil
end

function ExpansionMatches(expansion, filter)
  if filter == "all" then
    return true
  end

  return Normalize(expansion) == Normalize(filter)
end

function IsExpansionEnabled(expansion)
  return not (AzerColectDisabledExpansions and AzerColectDisabledExpansions[expansion])
end

function SafeCall(fn, ...)
  if not fn then
    return nil
  end

  local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, ...)

  if not ok then
    return nil
  end

  return a, b, c, d, e, f, g, h, i, j, k
end

function IsAutoCatalogEnabled()
  return not (AzerColectAutoCatalog and AzerColectAutoCatalog.enabled == false)
end

function IsDisabledMountID(mountID)
  return mountID and AzerColectDisabledMountIDs and AzerColectDisabledMountIDs[mountID] == true
end

function GetJournalMountInfo(mountID)
  mountID = tonumber(mountID)

  if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoByID then
    return nil
  end

  AzerColectRuntime.journalMountInfoCache = AzerColectRuntime.journalMountInfoCache or {}

  if AzerColectRuntime.journalMountInfoCache[mountID] then
    return AzerColectRuntime.journalMountInfoCache[mountID]
  end

  local name, spellID, icon, isActive, isUsable, sourceType,
    isFavorite, isFactionSpecific, faction, shouldHideOnChar,
    isCollected = SafeCall(C_MountJournal.GetMountInfoByID, mountID)

  if not name or name == "" then
    return nil
  end

  AzerColectRuntime.journalMountInfoCache[mountID] = {
    name = name,
    spellID = spellID,
    icon = icon,
    sourceType = sourceType,
    isCollected = isCollected == true,
    shouldHideOnChar = shouldHideOnChar == true
  }

  AzerColectRuntime.mountDisplayNameCache = AzerColectRuntime.mountDisplayNameCache or {}
  AzerColectRuntime.mountIconCache = AzerColectRuntime.mountIconCache or {}
  AzerColectRuntime.mountDisplayNameCache[mountID] = name
  AzerColectRuntime.mountIconCache[mountID] = icon

  return AzerColectRuntime.journalMountInfoCache[mountID]
end

function GetJournalMountExtra(mountID)
  mountID = tonumber(mountID)

  if not mountID or not C_MountJournal or not C_MountJournal.GetMountInfoExtraByID then
    return nil
  end

  AzerColectRuntime.journalMountExtraCache = AzerColectRuntime.journalMountExtraCache or {}

  if AzerColectRuntime.journalMountExtraCache[mountID] then
    return AzerColectRuntime.journalMountExtraCache[mountID]
  end

  local displayID, description, sourceText = SafeCall(C_MountJournal.GetMountInfoExtraByID, mountID)

  AzerColectRuntime.journalMountExtraCache[mountID] = {
    displayID = displayID,
    description = description,
    sourceText = sourceText
  }

  if type(displayID) == "number" and displayID > 0 then
    AzerColectRuntime.mountDisplayIDCache = AzerColectRuntime.mountDisplayIDCache or {}
    AzerColectRuntime.mountDisplayIDCache[mountID] = displayID
  end

  return AzerColectRuntime.journalMountExtraCache[mountID]
end

function BuildConfiguredMountIDSet()
  local mountIDs = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    if type(mount) == "table" and mount.mountID and mount.mountID ~= 0 then
      mountIDs[mount.mountID] = true
    end
  end

  return mountIDs
end

function SetEnumSourceType(sourceMap, enumTable, key, source)
  if type(enumTable) == "table" and enumTable[key] ~= nil then
    sourceMap[enumTable[key]] = source
  end
end

function BuildJournalSourceTypeMap()
  if AzerColectRuntime.journalSourceTypeMap then
    return AzerColectRuntime.journalSourceTypeMap
  end

  local sourceMap = {}
  local enumTable = Enum and Enum.MountSourceType

  SetEnumSourceType(sourceMap, enumTable, "Drop", "Rare")
  SetEnumSourceType(sourceMap, enumTable, "Rare", "Rare")
  SetEnumSourceType(sourceMap, enumTable, "Dungeon", "Dungeon")
  SetEnumSourceType(sourceMap, enumTable, "Raid", "Raid")
  SetEnumSourceType(sourceMap, enumTable, "WorldBoss", "World boss")
  SetEnumSourceType(sourceMap, enumTable, "Quest", "Quest")
  SetEnumSourceType(sourceMap, enumTable, "Vendor", "Vendor")
  SetEnumSourceType(sourceMap, enumTable, "Reputation", "Reputation")
  SetEnumSourceType(sourceMap, enumTable, "Profession", "Profession")
  SetEnumSourceType(sourceMap, enumTable, "Achievement", "Achievement")
  SetEnumSourceType(sourceMap, enumTable, "Event", "Event")
  SetEnumSourceType(sourceMap, enumTable, "WorldEvent", "Event")
  SetEnumSourceType(sourceMap, enumTable, "Promotion", "Other")
  SetEnumSourceType(sourceMap, enumTable, "TradingCardGame", "Other")
  SetEnumSourceType(sourceMap, enumTable, "InGameShop", "Other")
  SetEnumSourceType(sourceMap, enumTable, "Shop", "Other")
  SetEnumSourceType(sourceMap, enumTable, "Store", "Other")
  SetEnumSourceType(sourceMap, enumTable, "NotAvailable", "Other")
  SetEnumSourceType(sourceMap, enumTable, "TradingPost", "Vendor")
  SetEnumSourceType(sourceMap, enumTable, "Discovery", "Secret")

  AzerColectRuntime.journalSourceTypeMap = sourceMap

  return sourceMap
end

function BuildExternalJournalSourceTypeSet()
  if AzerColectRuntime.externalJournalSourceTypeSet then
    return AzerColectRuntime.externalJournalSourceTypeSet
  end

  local externalSourceTypes = {}
  local enumTable = Enum and Enum.MountSourceType

  SetEnumSourceType(externalSourceTypes, enumTable, "Promotion", true)
  SetEnumSourceType(externalSourceTypes, enumTable, "TradingCardGame", true)
  SetEnumSourceType(externalSourceTypes, enumTable, "InGameShop", true)
  SetEnumSourceType(externalSourceTypes, enumTable, "Shop", true)
  SetEnumSourceType(externalSourceTypes, enumTable, "Store", true)
  SetEnumSourceType(externalSourceTypes, enumTable, "NotAvailable", true)

  AzerColectRuntime.externalJournalSourceTypeSet = externalSourceTypes

  return externalSourceTypes
end

function TextContainsAny(text, ...)
  local cleanText = Normalize(text)

  if cleanText == "" then
    return false
  end

  for index = 1, select("#", ...) do
    local needle = Normalize(select(index, ...))

    if needle ~= "" and string.find(cleanText, needle, 1, true) then
      return true
    end
  end

  return false
end

function CleanTextContainsAny(cleanText, ...)
  cleanText = cleanText or ""

  if cleanText == "" then
    return false
  end

  for index = 1, select("#", ...) do
    local needle = Normalize(select(index, ...))

    if needle ~= "" and string.find(cleanText, needle, 1, true) then
      return true
    end
  end

  return false
end

function DetectProfessionNameFromText(text)
  local cleanText = Normalize(text)

  if cleanText == "" then
    return nil
  end

  for _, profession in ipairs(PROFESSION_ALIASES) do
    for _, alias in ipairs(profession.aliases or {}) do
      local cleanAlias = Normalize(alias)

      if cleanAlias ~= "" and string.find(cleanText, cleanAlias, 1, true) then
        return LocalizeDataValue(profession.label) or profession.aliases[1]
      end
    end
  end
end

function GetMountProfession(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local explicitProfession = LocalizeDataValue(mount.requiredProfession
    or mount.profession
    or mount.learnedByProfession
    or mount.craftingProfession)

  if explicitProfession and explicitProfession ~= "" then
    return explicitProfession
  end

  return DetectProfessionNameFromText(
    (mount.name or "") .. " "
    .. (LocalizeDataValue(mount.journalSource) or "") .. " "
    .. (LocalizeDataValue(mount.note) or "") .. " "
    .. (LocalizeDataValue(mount.requirement) or "") .. " "
    .. (LocalizeDataValue(mount.method) or "") .. " "
    .. (LocalizeDataValue(mount.source) or "")
  )
end

function GetNormalizedZoneExpansionMap()
  if AzerColectRuntime.normalizedZoneExpansionMap then
    return AzerColectRuntime.normalizedZoneExpansionMap
  end

  AzerColectRuntime.normalizedZoneExpansionMap = {}

  for zone, expansion in pairs(zoneExpansionMap) do
    AzerColectRuntime.normalizedZoneExpansionMap[Normalize(zone)] = expansion
  end

  return AzerColectRuntime.normalizedZoneExpansionMap
end

function IsExternalJournalMount(sourceType, sourceText)
  if AzerColectAutoCatalog and AzerColectAutoCatalog.includeExternal == true then
    return false
  end

  local externalSourceTypes = BuildExternalJournalSourceTypeSet()

  if sourceType and externalSourceTypes[sourceType] then
    return true
  end

  return TextContainsAny(
    sourceText,
    "promotion",
    "promocion",
    "in-game shop",
    "in-game store",
    "blizzard shop",
    "blizzard store",
    "battle.net shop",
    "battle.net",
    "not available",
    "unavailable",
    "no disponible",
    "recruit-a-friend",
    "recluta a un amigo",
    "trading card game",
    "tcg",
    "blizzcon",
    "collector's edition",
    "collectors edition",
    "edicion de coleccionista"
  )
end

function GetExternalJournalUnavailableReason(sourceType, sourceText)
  local enumTable = Enum and Enum.MountSourceType

  if type(enumTable) == "table" then
    if sourceType == enumTable.TradingCardGame then
      return L("unavailableReasonTCG")
    end

    if sourceType == enumTable.InGameShop
      or sourceType == enumTable.Shop
      or sourceType == enumTable.Store then
      return L("unavailableReasonShop")
    end

    if sourceType == enumTable.NotAvailable then
      return L("unavailableReasonRemoved")
    end
  end

  if TextContainsAny(sourceText, "not available", "unavailable", "no disponible", "no longer available", "no longer obtainable", "no longer in game") then
    return L("unavailableReasonRemoved")
  end

  if TextContainsAny(sourceText, "trading card game", "tcg", "juego de cartas") then
    return L("unavailableReasonTCG")
  end

  if TextContainsAny(sourceText, "collector's edition", "collectors edition", "edicion de coleccionista") then
    return L("unavailableReasonCollector")
  end

  if TextContainsAny(sourceText, "recruit-a-friend", "recluta a un amigo") then
    return L("unavailableReasonRecruit")
  end

  if TextContainsAny(sourceText, "pre-purchase", "prepurchase", "pre-order", "preorder", "precompra") then
    return L("unavailableReasonPreorder")
  end

  if TextContainsAny(sourceText, "in-game shop", "in game shop", "in-game store", "in game store", "blizzard shop", "blizzard store", "battle.net shop", "battle.net store", "battle.net", "world of warcraft shop", "tienda del juego", "tienda de blizzard") then
    return L("unavailableReasonShop")
  end

  if TextContainsAny(sourceText, "promotion", "promotional", "promocion", "limited-time", "limited time", "bundle", "prime gaming", "twitch drop", "blizzcon") then
    return L("unavailableReasonPromotion")
  end

  if type(enumTable) == "table" and sourceType == enumTable.Promotion then
    return L("unavailableReasonPromotion")
  end

  return nil
end

function InferJournalMountSource(sourceType, sourceText, mountName)
  local sourceContext = Trim((sourceText or "") .. " " .. (mountName or ""))

  if TextContainsAny(sourceContext, "world boss", "jefe del mundo") then
    return "World boss"
  end

  if TextContainsAny(sourceContext, "raid", "banda") then
    return "Raid"
  end

  if TextContainsAny(sourceContext, "dungeon", "calabozo", "calabozos", "mazmorra", "mazmorras") then
    return "Dungeon"
  end

  if TextContainsAny(sourceContext, "achievement", "logro") then
    return "Achievement"
  end

  if TextContainsAny(sourceContext, "reputation", "reputacion", "reputacion", "renown", "renombre") then
    return "Reputation"
  end

  if TextContainsAny(sourceContext, "event", "evento", "holiday", "fiesta") then
    return "Event"
  end

  if TextContainsAny(sourceContext, "vendor", "vendedor", "trading post", "puesto comercial") then
    return "Vendor"
  end

  if DetectProfessionNameFromText(sourceContext) or TextContainsAny(sourceContext,
    "profession",
    "profesion",
    "trade skill",
    "tradeskill",
    "crafted",
    "crafting",
    "fabricado",
    "fabricada",
    "engineering",
    "ingenieria",
    "blacksmithing",
    "herreria",
    "tailoring",
    "sastreria",
    "leatherworking",
    "peleteria",
    "jewelcrafting",
    "joyeria",
    "alchemy",
    "alquimia",
    "inscription",
    "inscripcion",
    "enchanting",
    "encantamiento",
    "fishing",
    "pesca",
    "archaeology",
    "arqueologia",
    "recipe",
    "receta",
    "schematic",
    "esquema",
    "pattern",
    "patron") then
    return "Profession"
  end

  if TextContainsAny(sourceContext, "quest", "mision") then
    return "Quest"
  end

  if TextContainsAny(sourceContext, "secret", "secreto", "puzzle", "acertijo") then
    return "Secret"
  end

  if TextContainsAny(sourceContext, "drop", "loot", "despojo", "botin", "rare", "raro") then
    return "Rare"
  end

  local sourceMap = BuildJournalSourceTypeMap()

  return sourceMap[sourceType] or "Other"
end

function BuildJournalMountNote(sourceText, description)
  if sourceText and sourceText ~= "" then
    return L("journalSourceLabel") .. ": " .. sourceText
  end

  if description and description ~= "" then
    return description
  end

  return L("journalCatalogNote")
end

function InferJournalMountExpansion(sourceText, description)
  local text = Trim((sourceText or "") .. " " .. (description or ""))

  if text == "" then
    return "General"
  end

  local cleanText = Normalize(text)

  if CleanTextContainsAny(cleanText, "midnight delves", "midnight dungeons", "midnight raids", "midnight season") then
    return "Midnight"
  end

  if CleanTextContainsAny(cleanText, "the war within", "khaz algar", "isle of dorn", "hallowfall", "azj-kahet", "siren isle", "undermine") then
    return "The War Within"
  end

  if CleanTextContainsAny(cleanText, "dragonflight", "dragon isles", "islas dragon", "valdrakken", "zaralek", "emerald dream") then
    return "Dragonflight"
  end

  if CleanTextContainsAny(cleanText, "shadowlands", "bastion", "maldraxxus", "ardenweald", "revendreth", "zereth mortis") then
    return "Shadowlands"
  end

  if CleanTextContainsAny(cleanText, "battle for azeroth", "kul tiras", "zandalar", "nazjatar", "mechagon", "dazar'alor", "ny'alotha") then
    return "BFA"
  end

  if CleanTextContainsAny(cleanText, "legion", "broken isles", "islas abruptas", "argus", "suramar", "broken shore", "costa abrupta") then
    return "Legion"
  end

  if CleanTextContainsAny(cleanText, "warlords of draenor", "draenor", "garrison") then
    return "Draenor"
  end

  if CleanTextContainsAny(cleanText, "mists of pandaria", "pandaria", "timeless isle", "isla intemporal", "throne of thunder") then
    return "Pandaria"
  end

  if CleanTextContainsAny(cleanText, "cataclysm", "deepholm", "infralar", "uldum", "firelands", "tierras de fuego", "dragon soul") then
    return "Cataclysm"
  end

  if CleanTextContainsAny(cleanText, "wrath of the lich king", "lich king", "rasganorte", "northrend", "icecrown", "corona de hielo", "ulduar", "argent tournament", "torneo argenta") then
    return "Wrath"
  end

  if CleanTextContainsAny(cleanText, "burning crusade", "outland", "terokkar", "netherstorm", "tempest keep", "the eye", "shattrath") then
    return "Burning Crusade"
  end

  for zone, expansion in pairs(GetNormalizedZoneExpansionMap()) do
    if string.find(cleanText, zone, 1, true) then
      return expansion
    end
  end

  return "General"
end

function AddJournalMountCatalogEntry(configuredMountIDs, mountID)
  if not mountID
    or configuredMountIDs[mountID]
    or IsDisabledMountID(mountID) then
    return false
  end

  local info = GetJournalMountInfo(mountID)
  local name = info and info.name

  if not name or name == "" then
    return false
  end

  local sourceType = info and info.sourceType

  if sourceType and BuildExternalJournalSourceTypeSet()[sourceType] then
    configuredMountIDs[mountID] = true
    return false
  end

  local extra = GetJournalMountExtra(mountID) or {}
  local description = extra.description
  local sourceText = extra.sourceText
  local journalSource = sourceText or description or ""

  if GetExternalJournalUnavailableReason(sourceType, journalSource) then
    configuredMountIDs[mountID] = true
    return false
  end

  local detectedProfession = DetectProfessionNameFromText((name or "") .. " " .. journalSource)
  local inferredSource = InferJournalMountSource(sourceType, journalSource, name)

  AzerColectMounts = AzerColectMounts or {}
  table.insert(AzerColectMounts, {
    name = name,
    mountID = mountID,
    source = inferredSource,
    expansion = InferJournalMountExpansion(sourceText, description),
    reset = "catalog",
    journalSource = journalSource,
    sourceType = sourceType,
    requiredProfession = detectedProfession,
    autoCatalog = true
  })

  if AzerColectRuntime.journalMountExtraCache and AzerColectRuntime.journalMountExtraCache[mountID] then
    AzerColectRuntime.journalMountExtraCache[mountID].description = nil
    AzerColectRuntime.journalMountExtraCache[mountID].sourceText = nil
  end

  configuredMountIDs[mountID] = true
  return true
end

function FinishJournalMountCatalogLoad()
  autoCatalogLoaded = true
  AzerColectRuntime.autoCatalogLoading = nil
  AzerColectRuntime.autoCatalogMountIDs = nil
  AzerColectRuntime.autoCatalogConfiguredMountIDs = nil
  AzerColectRuntime.autoCatalogIndex = nil
  InvalidateAzerColectDataCache()

  if mainFrame and mainFrame:IsShown() then
    QueueRefreshWindow(0.05)
  end
end

function QueueJournalMountCatalogBatch()
  if C_Timer and C_Timer.After then
    C_Timer.After(AUTO_CATALOG_BATCH_DELAY, ProcessJournalMountCatalogBatch)
  else
    ProcessJournalMountCatalogBatch()
  end
end

function ProcessJournalMountCatalogBatch()
  if autoCatalogLoaded or not AzerColectRuntime.autoCatalogLoading then
    return
  end

  local mountIDs = AzerColectRuntime.autoCatalogMountIDs
  local configuredMountIDs = AzerColectRuntime.autoCatalogConfiguredMountIDs

  if type(mountIDs) ~= "table" or type(configuredMountIDs) ~= "table" then
    FinishJournalMountCatalogLoad()
    return
  end

  local index = AzerColectRuntime.autoCatalogIndex or 1
  local lastIndex = math.min(#mountIDs, index + AUTO_CATALOG_BATCH_SIZE - 1)

  while index <= lastIndex do
    if AddJournalMountCatalogEntry(configuredMountIDs, mountIDs[index]) then
      autoCatalogAdded = autoCatalogAdded + 1
    end

    index = index + 1
  end

  AzerColectRuntime.autoCatalogIndex = index

  if index <= #mountIDs then
    QueueJournalMountCatalogBatch()
  else
    FinishJournalMountCatalogLoad()
  end
end

function AddJournalMountCatalog()
  if autoCatalogLoaded or not IsAutoCatalogEnabled() then
    return autoCatalogAdded
  end

  if AzerColectRuntime.autoCatalogLoading then
    return autoCatalogAdded
  end

  if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
    return autoCatalogAdded
  end

  local mountIDs = SafeCall(C_MountJournal.GetMountIDs)

  if type(mountIDs) ~= "table" then
    return autoCatalogAdded
  end

  AzerColectRuntime.autoCatalogMountIDs = mountIDs
  AzerColectRuntime.autoCatalogConfiguredMountIDs = BuildConfiguredMountIDSet()
  AzerColectRuntime.autoCatalogIndex = 1
  AzerColectRuntime.autoCatalogLoading = true
  autoCatalogAdded = 0
  QueueJournalMountCatalogBatch()

  return autoCatalogAdded
end

function StyleFont(fontString, size, r, g, b, flags)
  if not fontString then
    return
  end

  local font, currentSize, currentFlags = SafeCall(fontString.GetFont, fontString)

  local targetSize = size or currentSize or 12

  if targetSize < 18 then
    targetSize = targetSize + READABILITY_FONT_BONUS
  end

  if font then
    SafeCall(fontString.SetFont, fontString, font, targetSize, flags or currentFlags or "")
  end

  if r and g and b then
    SafeCall(fontString.SetTextColor, fontString, r, g, b)
  end

  SafeCall(fontString.SetShadowColor, fontString, 0, 0, 0, 0.95)
  SafeCall(fontString.SetShadowOffset, fontString, 1, -1)
end

function StyleButton(button, color)
  if not button then
    return
  end

  color = color or button.azerColor or UI_THEME.gold
  StyleFont(button:GetFontString(), 10, color[1] or 1, color[2] or 0.82, color[3] or 0.18, "OUTLINE")
end

function SetTextureColor(texture, color, alpha)
  if not texture or not color then
    return
  end

  texture:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, alpha or color[4] or 1)
end

function CreateLine(parent, layer, pointA, pointB, thickness, color, alpha)
  local line = parent:CreateTexture(nil, layer or "BORDER")

  line:SetPoint(pointA[1], parent, pointA[2], pointA[3] or 0, pointA[4] or 0)
  line:SetPoint(pointB[1], parent, pointB[2], pointB[3] or 0, pointB[4] or 0)

  if (pointA[1] == "TOPLEFT" and pointB[1] == "TOPRIGHT")
    or (pointA[1] == "BOTTOMLEFT" and pointB[1] == "BOTTOMRIGHT") then
    line:SetHeight(thickness or 1)
  else
    line:SetWidth(thickness or 1)
  end

  SetTextureColor(line, color or UI_THEME.goldSoft, alpha or 0.48)
  return line
end

function DecoratePanel(frame, backgroundColor, borderColor, backgroundAlpha, borderAlpha)
  if not frame then
    return
  end

  frame.azerBackground = frame:CreateTexture(nil, "BACKGROUND")
  frame.azerBackground:SetAllPoints()
  SetTextureColor(frame.azerBackground, backgroundColor or UI_THEME.panel, backgroundAlpha or 0.92)

  frame.azerTopLine = CreateLine(frame, "BORDER", { "TOPLEFT", "TOPLEFT" }, { "TOPRIGHT", "TOPRIGHT" }, 1, borderColor or UI_THEME.goldSoft, borderAlpha or 0.62)
  frame.azerBottomLine = CreateLine(frame, "BORDER", { "BOTTOMLEFT", "BOTTOMLEFT" }, { "BOTTOMRIGHT", "BOTTOMRIGHT" }, 1, borderColor or UI_THEME.goldSoft, (borderAlpha or 0.62) * 0.7)
  frame.azerLeftLine = CreateLine(frame, "BORDER", { "TOPLEFT", "TOPLEFT" }, { "BOTTOMLEFT", "BOTTOMLEFT" }, 1, borderColor or UI_THEME.goldSoft, (borderAlpha or 0.62) * 0.6)
  frame.azerRightLine = CreateLine(frame, "BORDER", { "TOPRIGHT", "TOPRIGHT" }, { "BOTTOMRIGHT", "BOTTOMRIGHT" }, 1, borderColor or UI_THEME.goldSoft, (borderAlpha or 0.62) * 0.6)
end

function DecorateButton(button, color, alpha)
  if not button then
    return
  end

  color = color or UI_THEME.gold
  button.azerColor = color

  if not button.azerBackground then
    button.azerBackground = button:CreateTexture(nil, "BACKGROUND")
    button.azerBackground:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.azerBackground:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)

    button.azerTopLine = button:CreateTexture(nil, "BORDER")
    button.azerTopLine:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.azerTopLine:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    button.azerTopLine:SetHeight(1)

    button.azerBottomLine = button:CreateTexture(nil, "BORDER")
    button.azerBottomLine:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.azerBottomLine:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.azerBottomLine:SetHeight(1)

    button.azerGlow = button:CreateTexture(nil, "OVERLAY")
    button.azerGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.azerGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.azerGlow:Hide()
  end

  SetTextureColor(button.azerBackground, color, alpha or 0.22)
  SetTextureColor(button.azerTopLine, color, 0.82)
  SetTextureColor(button.azerBottomLine, color, 0.48)
  SetTextureColor(button.azerGlow, color, 0.18)

  if button.GetNormalTexture then
    local normal = button:GetNormalTexture()
    if normal then
      SafeCall(normal.SetAlpha, normal, 0.18)
    end
  end

  if button.GetPushedTexture then
    local pushed = button:GetPushedTexture()
    if pushed then
      SafeCall(pushed.SetAlpha, pushed, 0.32)
    end
  end

  StyleButton(button, color)
end

function SetButtonIcon(button, texturePath)
  if not button then
    return
  end

  button:SetText("")

  if not button.azerIcon then
    button.azerIcon = button:CreateTexture(nil, "ARTWORK")
    button.azerIcon:SetSize(15, 15)
    button.azerIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.azerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  button.azerIcon:SetTexture(texturePath or DEFAULT_MOUNT_ICON)
  button.azerIcon:Show()
end

function SetButtonTooltip(button, title, details)
  if not button then
    return
  end

  button:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title or "")

    if details and details ~= "" then
      GameTooltip:AddLine(details, 0.82, 0.88, 1, true)
    end

    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)
end

function ConfigureIconButton(button, icon, tooltipTitle, tooltipDetails, onClick)
  SetButtonIcon(button, icon)
  SetButtonTooltip(button, tooltipTitle, tooltipDetails)
  button:SetScript("OnClick", onClick)
end

function ClampScrollOffset(offset, itemCount)
  local maxOffset = math.max(0, (itemCount or 0) - ROW_COUNT)

  return math.min(math.max(0, offset or 0), maxOffset)
end

function ResetListScroll()
  currentScrollOffset = 0
  currentPage = 1
end

function ScrollList(delta)
  if not mainFrame or not mainFrame.currentItemCount then
    return
  end

  local step = IsShiftKeyDown and IsShiftKeyDown() and 3 or 1
  local nextOffset = currentScrollOffset - ((delta or 0) * step)

  nextOffset = ClampScrollOffset(nextOffset, mainFrame.currentItemCount)

  if nextOffset ~= currentScrollOffset then
    currentScrollOffset = nextOffset
    currentPage = math.floor(currentScrollOffset / ROW_COUNT) + 1
    RefreshWindow()
  end
end

function Now()
  if GetServerTime then
    return GetServerTime()
  end

  return time()
end

local function GetCharacterKey()
  local name = UnitName("player") or L("unknownCharacter")
  local realm = GetRealmName() or L("unknownRealm")

  return name .. "-" .. realm
end

local function EnsureDB()
  AzerColectDB.attempts = AzerColectDB.attempts or {}
  AzerColectDB.favorites = AzerColectDB.favorites or {}
  AzerColectDB.favorites.mounts = AzerColectDB.favorites.mounts or {}
  AzerColectDB.favorites.achievements = AzerColectDB.favorites.achievements or {}
  AzerColectDB.minimap = AzerColectDB.minimap or {}
  AzerColectDB.minimap.angle = tonumber(AzerColectDB.minimap.angle) or 225
  AzerColectDB.characters = AzerColectDB.characters or {}
  AzerColectDB.knownMounts = AzerColectDB.knownMounts or {}
  AzerColectDB.mountHistory = AzerColectDB.mountHistory or {}
  AzerColectDB.newMountAlerts = AzerColectDB.newMountAlerts or {}
  AzerColectDB.options = AzerColectDB.options or {}

  for key, value in pairs(DEFAULT_OPTIONS) do
    if AzerColectDB.options[key] == nil then
      AzerColectDB.options[key] = value
    end
  end

  if AzerColectDB.newMountAlerts.enabled == nil then
    AzerColectDB.newMountAlerts.enabled = true
  end

  if AzerColectDB.newMountAlerts.sound == nil then
    AzerColectDB.newMountAlerts.sound = true
  end

  if AzerColectDB.newMountAlerts.confetti == nil then
    AzerColectDB.newMountAlerts.confetti = true
  end

  local characterKey = GetCharacterKey()
  AzerColectDB.attempts[characterKey] = AzerColectDB.attempts[characterKey] or {}
  AzerColectDB.characters[characterKey] = AzerColectDB.characters[characterKey] or {}

  return AzerColectDB.attempts[characterKey]
end

function GetAzerColectOption(key)
  EnsureDB()

  if AzerColectDB.options[key] == nil then
    return DEFAULT_OPTIONS[key]
  end

  return AzerColectDB.options[key] == true
end

function SetAzerColectOption(key, value)
  EnsureDB()
  AzerColectDB.options[key] = value == true
  InvalidateAzerColectDataCache()
end

local function GetResetGroup(reset)
  if reset == "weekly" then
    return "weekly"
  end

  return "daily"
end

local function GetSecondsUntilReset(resetGroup)
  if resetGroup == "weekly" and C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
    return C_DateAndTime.GetSecondsUntilWeeklyReset()
  end

  if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
    return C_DateAndTime.GetSecondsUntilDailyReset()
  end

  if GetQuestResetTime then
    return GetQuestResetTime()
  end

  return 24 * 60 * 60
end

local function FormatDuration(seconds)
  seconds = math.max(0, tonumber(seconds) or 0)

  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)

  if days > 0 then
    return L("durationDaysHours", days, hours)
  end

  if hours > 0 then
    return L("durationHoursMinutes", hours, minutes)
  end

  return L("durationMinutes", math.max(1, minutes))
end

local function GetWeeklyResetText()
  return L("weeklyResetTimer", FormatDuration(GetSecondsUntilReset("weekly")))
end

local function GetPeriodKey(mount)
  local resetGroup = GetResetGroup(mount.reset)
  local resetTime = Now() + GetSecondsUntilReset(resetGroup)

  return resetGroup .. ":" .. date("%Y-%m-%d-%H", resetTime)
end

local function GetMountKey(mount)
  return tostring(mount.mountID or mount.name)
end

function GetUnavailableRegistryEntry(mount)
  if type(mount) ~= "table" or type(AzerColectUnavailableMounts) ~= "table" then
    return nil
  end

  if mount.mountID then
    local entry = AzerColectUnavailableMounts[mount.mountID] or AzerColectUnavailableMounts[tostring(mount.mountID)]

    if entry then
      return entry
    end
  end

  local mountName = Normalize(mount.name or "")

  if mountName ~= "" then
    for key, entry in pairs(AzerColectUnavailableMounts) do
      if Normalize(tostring(key)) == mountName then
        return entry
      end

      if type(entry) == "table" and Normalize(entry.name or "") == mountName then
        return entry
      end
    end
  end
end

function GetMountUnavailableReason(mount)
  if type(mount) ~= "table" then
    return nil
  end

  AzerColectRuntime.unavailableReasonCache = AzerColectRuntime.unavailableReasonCache or {}

  local key = GetMountKey(mount)
  local cached = AzerColectRuntime.unavailableReasonCache[key]

  if cached ~= nil then
    return cached ~= false and cached or nil
  end

  local registryEntry = GetUnavailableRegistryEntry(mount)
  local reason

  if type(registryEntry) == "table" then
    reason = LocalizeDataValue(registryEntry.reason or registryEntry.unavailableReason or registryEntry.note)
  elseif type(registryEntry) == "string" then
    reason = registryEntry
  end

  reason = reason
    or LocalizeDataValue(mount.unavailableReason or mount.removedReason or mount.availabilityReason)

  if not reason and (mount.unavailable == true
    or mount.removed == true
    or mount.noLongerAvailable == true
    or mount.obtainable == false
    or mount.available == false) then
    reason = L("unavailableReasonRemoved")
  end

  if not reason then
    reason = GetExternalJournalUnavailableReason(
      mount.sourceType,
      (LocalizeDataValue(mount.journalSource) or "") .. " "
      .. (LocalizeDataValue(mount.note) or "") .. " "
      .. (LocalizeDataValue(mount.requirement) or "") .. " "
      .. (LocalizeDataValue(mount.method) or "") .. " "
      .. (LocalizeDataValue(mount.source) or "")
    )
  end

  if not reason then
    local searchText = Normalize(
      (mount.name or "") .. " "
      .. (LocalizeDataValue(mount.journalSource) or "") .. " "
      .. (LocalizeDataValue(mount.note) or "") .. " "
      .. (LocalizeDataValue(mount.requirement) or "") .. " "
      .. (LocalizeDataValue(mount.method) or "") .. " "
      .. (LocalizeDataValue(mount.source) or "")
    )

    if TextContainsAny(searchText, "not available", "unavailable", "no disponible", "no longer available", "no longer obtainable", "no longer in game", "removed from the game", "ya no esta disponible", "ya no se puede obtener", "ya no esta en el juego", "eliminada del juego", "eliminado del juego", "retirada del juego", "retirado del juego") then
      reason = L("unavailableReasonRemoved")
    elseif TextContainsAny(searchText, "trading card game", "tcg", "juego de cartas") then
      reason = L("unavailableReasonTCG")
    elseif TextContainsAny(searchText, "in-game shop", "in game shop", "in-game store", "in game store", "blizzard shop", "blizzard store", "battle.net shop", "battle.net store", "battle.net", "world of warcraft shop", "tienda del juego", "tienda de blizzard") then
      reason = L("unavailableReasonShop")
    elseif TextContainsAny(searchText, "promotion", "promotional", "promocion", "limited-time", "limited time", "bundle", "prime gaming", "twitch drop") then
      reason = L("unavailableReasonPromotion")
    elseif TextContainsAny(searchText, "collector's edition", "collectors edition", "edicion de coleccionista") then
      reason = L("unavailableReasonCollector")
    elseif TextContainsAny(searchText, "recruit-a-friend", "recluta a un amigo") then
      reason = L("unavailableReasonRecruit")
    elseif TextContainsAny(searchText, "blizzcon", "anniversary", "aniversario") then
      reason = L("unavailableReasonExpiredEvent")
    elseif TextContainsAny(searchText, "challenge mode", "modo desafio") then
      reason = L("unavailableReasonChallengeMode")
    elseif TextContainsAny(searchText, "ahead of the curve", "cutting edge", "curva", "filo del abismo") then
      reason = L("unavailableReasonAchievementRemoved")
    elseif TextContainsAny(searchText, "gladiator", "gladiador", "elite pvp", "elite") and TextContainsAny(searchText, "season", "temporada") then
      reason = L("unavailableReasonSeason")
    elseif TextContainsAny(searchText, "pre-purchase", "prepurchase", "pre-order", "preorder", "precompra") then
      reason = L("unavailableReasonPreorder")
    end
  end

  AzerColectRuntime.unavailableReasonCache[key] = reason or false

  return reason
end

function IsMountUnavailable(mount)
  return GetMountUnavailableReason(mount) ~= nil
end

function GetMountHistory(mount)
  if type(mount) ~= "table" then
    return nil
  end

  EnsureDB()

  local key = GetMountKey(mount)
  AzerColectDB.mountHistory[key] = AzerColectDB.mountHistory[key] or {
    name = mount.name,
    mountID = mount.mountID,
    attempts = 0,
    periods = {}
  }

  local history = AzerColectDB.mountHistory[key]

  history.name = mount.name or history.name
  history.mountID = mount.mountID or history.mountID
  history.periods = history.periods or {}

  return history
end

function RecordMountAttemptHistory(mount)
  local history = GetMountHistory(mount)

  if not history then
    return
  end

  local periodKey = GetCharacterKey() .. ":" .. GetPeriodKey(mount)

  if history.periods[periodKey] then
    return
  end

  history.periods[periodKey] = true
  history.attempts = (tonumber(history.attempts) or 0) + 1
  history.estimatedMinutes = (tonumber(history.estimatedMinutes) or 0)
    + math.max(1, tonumber(GetEasyMountMinutes and GetEasyMountMinutes(mount)) or 10)
  history.firstAttemptAt = history.firstAttemptAt or Now()
  history.lastAttemptAt = Now()
end

local function MarkAttempt(mount)
  local attempts = EnsureDB()

  attempts[GetMountKey(mount)] = {
    name = mount.name,
    reset = mount.reset,
    period = GetPeriodKey(mount),
    markedAt = Now()
  }

  RecordMountAttemptHistory(mount)
  InvalidateAzerColectDataCache()
end

local function ClearAttempt(mount)
  local attempts = EnsureDB()
  attempts[GetMountKey(mount)] = nil
  InvalidateAzerColectDataCache()
end

local function IsAttempted(mount)
  local attempts = EnsureDB()
  local attempt = attempts[GetMountKey(mount)]

  return attempt and attempt.period == GetPeriodKey(mount)
end

local function EnsureFavorites()
  EnsureDB()

  return AzerColectDB.favorites
end

local function GetAchievementID(entry)
  if type(entry) == "table" then
    return entry.id or entry.achievementID
  end

  return entry
end

local function GetAchievementKey(entry)
  local achievementID = GetAchievementID(entry)

  return achievementID and tostring(achievementID)
end

local function GetAchievementDisplayName(entry)
  if type(entry) == "table" and entry.name then
    return entry.name
  end

  local achievementID = GetAchievementID(entry)

  if achievementID then
    local id, name = SafeCall(GetAchievementInfo, achievementID)

    if id and name then
      return name
    end
  end

  return achievementID and L("achievementNameFallback", achievementID) or L("unknownAchievement")
end

local function IsFavoriteMount(mount)
  local favorites = EnsureFavorites()

  return favorites.mounts[GetMountKey(mount)] == true
end

local function IsFavoriteAchievement(entry)
  local favorites = EnsureFavorites()
  local key = GetAchievementKey(entry)

  return key and favorites.achievements[key] == true
end

local function ToggleFavoriteMount(mount)
  local favorites = EnsureFavorites()
  local key = GetMountKey(mount)

  if favorites.mounts[key] then
    favorites.mounts[key] = nil
    Print(L("favoriteRemoved", GetMountDisplayName(mount)))
  else
    favorites.mounts[key] = true
    Print(L("favoriteAdded", GetMountDisplayName(mount)))
  end

  InvalidateAzerColectDataCache()
end

local function ToggleFavoriteAchievement(entry)
  local favorites = EnsureFavorites()
  local key = GetAchievementKey(entry)

  if not key then
    Print(L("achievementUnknown"))
    return
  end

  if favorites.achievements[key] then
    favorites.achievements[key] = nil
    Print(L("favoriteRemoved", GetAchievementDisplayName(entry)))
  else
    favorites.achievements[key] = true
    Print(L("favoriteAdded", GetAchievementDisplayName(entry)))
  end

  InvalidateAzerColectDataCache()
end

local function ShouldShowMount(mount, mode)
  if mode == "today" then
    return mount.reset == "daily"
      or mount.reset == "repeatable"
      or mount.reset == "event"
      or mount.reset == "special"
  end

  if mode == "weekly" then
    return mount.reset == "weekly"
  end

  return true
end

local function GetMountExpansion(mount)
  if mount.expansion and mount.expansion ~= "" then
    return mount.expansion
  end

  return zoneExpansionMap[mount.zone or ""] or "General"
end

local function GetMountSource(mount)
  return mount.source or "Other"
end

local supportedDataLocales = {
  enUS = true,
  esMX = true,
  ptBR = true,
  frFR = true,
  deDE = true
}

local localeAliases = {
  enGB = "enUS",
  esES = "esMX",
  ptPT = "ptBR"
}

local function GetDataLocale()
  return "enUS"
end

local function IsLocalizedDataTable(value)
  if type(value) ~= "table" then
    return false
  end

  for localeKey in pairs(supportedDataLocales) do
    if value[localeKey] ~= nil then
      return true
    end
  end

  for aliasKey in pairs(localeAliases) do
    if value[aliasKey] ~= nil then
      return true
    end
  end

  return value.en ~= nil
    or value.es ~= nil
    or value.pt ~= nil
    or value.fr ~= nil
    or value.de ~= nil
end

local function PickLocalizedDataValue(value)
  if not IsLocalizedDataTable(value) then
    return value
  end

  local dataLocale = GetDataLocale()
  local language = string.sub(dataLocale, 1, 2)

  return value[dataLocale]
    or value[language]
    or value[localeAliases[dataLocale] or ""]
    or value.enUS
    or value.en
end

local manualTextTranslations = {
  ["Muy baja"] = {
    enUS = "Very low",
    esMX = "Muy baja",
    ptBR = "Muito baixa",
    frFR = "Tres faible",
    deDE = "Sehr niedrig"
  },
  ["Baja"] = {
    enUS = "Low",
    esMX = "Baja",
    ptBR = "Baixa",
    frFR = "Faible",
    deDE = "Niedrig"
  },
  ["Garantizada si completas el evento cronometrado"] = {
    enUS = "Guaranteed if you complete the timed event",
    esMX = "Garantizada si completas el evento cronometrado",
    ptBR = "Garantida se voce concluir o evento cronometrado",
    frFR = "Garantie si vous terminez l'evenement chronometre",
    deDE = "Garantiert, wenn du das Zeitereignis abschliesst"
  },
  ["Disponible solo durante el evento."] = {
    enUS = "Available only during the event.",
    esMX = "Disponible solo durante el evento."
  },
  ["Heroic. Un intento diario por personaje."] = {
    enUS = "Heroic. One daily attempt per character.",
    esMX = "Heroic. Un intento diario por personaje."
  },
  ["Un intento diario por personaje."] = {
    enUS = "One daily attempt per character.",
    esMX = "Un intento diario por personaje."
  },
  ["Un intento semanal por personaje."] = {
    enUS = "One weekly attempt per character.",
    esMX = "Un intento semanal por personaje."
  },
  ["Normal se puede repetir; Heroic es diario."] = {
    enUS = "Normal can be repeated; Heroic is daily.",
    esMX = "Normal se puede repetir; Heroic es diario."
  }
}

local spanishToEnglishFragments = {
  { "Campana completada", "Campaign completed" },
  { "Item especial", "Special item" },
  { "Entrada de servicio", "Service entrance" },
  { "Entrada de instancia", "Instance entrance" },
  { "Entrada de banda", "Raid entrance" },
  { "Entrada de evento", "Event entrance" },
  { "Punto de aparicion", "Spawn point" },
  { "Ruta de patrulla", "Patrol route" },
  { "Ruta inicial", "Starting route" },
  { "Ruta de vuelo", "Flight route" },
  { "World quest activa", "Active world quest" },
  { "Jefe del mundo activo", "Active world boss" },
  { "Hongo humedo", "Damp mushroom" },
  { "Cuando Beledar cambia", "When Beledar shifts" },
  { "Requiere item", "Requires item" },
  { "Requiere Empty Magma Shell", "Requires Empty Magma Shell" },
  { "Evento activo", "Active event" },
  { "Evento", "Event" },
  { "Vendedor", "Vendor" },
  { "Variable", "Variable" },
  { "salir y reiniciar instancia", "exit and reset the instance" },
  { "un intento diario por personaje", "one daily attempt per character" },
  { "Un intento diario por personaje", "One daily attempt per character" },
  { "un intento semanal por personaje", "one weekly attempt per character" },
  { "Un intento semanal por personaje", "One weekly attempt per character" },
  { "una vez al dia por personaje", "once per day per character" },
  { "Durante ", "During " },
  { "cola del evento", "queue for the event" },
  { "abrir ", "open " },
  { "encadenar calabozos Timewalking", "chain Timewalking dungeons" },
  { "loot de jefes", "boss loot" },
  { "llegar al ", "reach " },
  { "antes del tiempo limite", "before the timer expires" },
  { "Normalmente es garantizada si llegas a tiempo", "Usually guaranteed if you arrive in time" },
  { "Se puede repetir, respetando el limite de instancias", "Can be repeated, respecting the instance limit" },
  { "Sale de la bolsa de recompensa de las diarias", "Drops from the daily quest reward bag" },
  { "Completa el evento cronometrado y abre", "Complete the timed event and open" },
  { "Revisa el lockout antes de entrar", "Check the lockout before entering" },
  { "Requiere hacer el evento cronometrado", "Requires completing the timed event" },
  { "para invocar a", "to summon" },
  { "Tambien puede salir", "Can also drop" },
  { "mediante random dungeon reward", "through the random dungeon reward" },
  { "deja vivos los 3 dracos", "leave the 3 drakes alive" },
  { "antes de matar a", "before killing" },
  { "Mata a", "Kill" },
  { "sin guardianes activos", "with no active keepers" },
  { "Necesitas", "Requires" },
  { "para quitarle el escudo", "to remove the shield" },
  { "Rare de mundo abierto", "Open world rare" },
  { "Buen candidato para intento diario", "Good daily attempt candidate" },
  { "buen objetivo para grupos de farmeo", "good target for farming groups" },
  { "Busca portales", "Look for portals" },
  { "en zonas de", "in zones of" },
  { "Requiere desbloquear", "Requires unlocking" },
  { "el secreto de los orbes", "the orb secret" },
  { "el farmeo de Worldbreaker Membership", "the Worldbreaker Membership farm" },
  { "antes de poder obtener la recompensa", "before you can obtain the reward" },
  { "Encuentra y toca", "Find and touch" },
  { "cinco cristales efimeros", "five ephemeral crystals" },
  { "antes que otros jugadores", "before other players" },
  { "Drop de raid", "Raid drop" },
  { "Drop extremadamente raro", "Extremely rare drop" },
  { "Drop indirecto por item de quest", "Indirect drop through a quest item" },
  { "Drop de Mythic o Mythic+", "Drop from Mythic or Mythic+" },
  { "Drop bajo despues de", "Low drop after" },
  { "Rare asociado al ciclo de", "Rare tied to the cycle of" },
  { "Rare con ruta por", "Rare with a route through" },
  { "Usa", "Use" },
  { "para invocarlo", "to summon it" },
  { "Tesoro/secreto de", "Treasure/secret in" },
  { "Rare de Dragonflight", "Dragonflight rare" },
  { "Cadena especial con reputacion de", "Special questline with reputation from" },
  { "Puede enseniar una montura de dungeon antigua que no tengas", "Can teach an older dungeon mount you do not have" },
  { "Recompensa del meta-logro de", "Meta-achievement reward from" },
  { "Recompensa de meta-logro de", "Meta-achievement reward from" },
  { "Recompensa de logro en", "Achievement reward on" },
  { "Recompensa de Mythic+", "Mythic+ reward" },
  { "Recompensa de renombre de", "Renown reward from" },
  { "Recompensa de reputacion de", "Reputation reward from" },
  { "Recompensa por derrotar al", "Reward for defeating" },
  { "Recompensa por recolectar los Skyriding Glyphs de", "Reward for collecting the Skyriding Glyphs from" },
  { "Requiere reunir", "Requires collecting" },
  { "requiere progreso en", "requires progress in" },
  { "requiere rango alto de", "requires high rank in" },
  { "requiere rango de", "requires rank in" },
  { "requiere", "requires" },
  { "Cadena/grindeo que empieza con drop raro", "Questline/grind that starts with a rare drop" },
  { "Montura personalizable de la introduccion a Delves", "Customizable mount from the Delves introduction" },
  { "Vendedor raro de la tienda", "Rare vendor in the shop" },
  { "Vendedora de equipo de tormentas", "Storm gear vendor" },
  { "Vendedor dentro de", "Vendor inside" },
  { "Vendedor en", "Vendor in" },
  { "Vendedor de", "Vendor for" },
  { "por Undercoin", "for Undercoin" },
  { "Montura con vendedor, reparador y transfigurador", "Mount with vendor, repair, and transmogrifier" },
  { "Intercambio con objetos de", "Exchange with items from" },
  { "Intercambio con anillos de mazmorras de Dragonflight", "Exchange with Dragonflight dungeon rings" },
  { "desbloquear", "unlock" },
  { "farmeo", "farm" },
  { "farmear", "farm" },
  { "juntar", "collect" },
  { "La moneda se farmea de elites cerca de", "The currency is farmed from elites near" },
  { "elites cerca de", "elites near" },
  { "subir", "raise" },
  { "Disponible en la zona activa de", "Available in the active zone for" },
  { "desbloqueado con", "unlocked with" },
  { "Talutu para Horda; Tricky Nick para Alianza", "Talutu for Horde; Tricky Nick for Alliance" },
  { "Mythic+ puede dar mas oportunidades segun temporada", "Mythic+ can provide more chances depending on the season" },
  { "Rare de Timeless Isle", "Timeless Isle rare" },
  { "Rare de Argus", "Argus rare" },
  { "Rare de Nazjatar", "Nazjatar rare" },
  { "Rare de Mechagon", "Mechagon rare" },
  { "World boss de Pandaria", "Pandaria world boss" },
  { "World boss de Draenor", "Draenor world boss" },
  { "World boss de BFA cuando esta activo", "BFA world boss when active" },
  { "Derrota todos los objetivos de Prey en dificultad Nightmare", "Defeat all Prey targets on Nightmare difficulty" },
  { "Drop de rares de", "Drop from rares in" },
  { "Tesoro de Zul'Aman que requiere llaves de cuatro guardianes", "Zul'Aman treasure that requires keys from four guardians" },
  { "Tesoro de Zul'Aman que requiere Vile Essence", "Zul'Aman treasure that requires Vile Essence" },
  { "Tesoro de Harandar que requiere Crystalized Resin Fragments", "Harandar treasure that requires Crystalized Resin Fragments" },
  { "Recompensa del meta-logro de raids de", "Raid meta-achievement reward from" },
  { "meta-logro de Delves de Midnight", "Midnight Delves meta-achievement" },
  { "en cualquier dificultad", "on any difficulty" },
  { "Revisa la recompensa exacta en la ventana de logros si Blizzard la cambia", "Check the exact reward in the achievements window when Blizzard changes it" }
}

local function ReplacePlain(text, search, replacement)
  local result = ""
  local position = 1

  while true do
    local startIndex, endIndex = string.find(text, search, position, true)

    if not startIndex then
      return result .. string.sub(text, position)
    end

    result = result .. string.sub(text, position, startIndex - 1) .. replacement
    position = endIndex + 1
  end
end

table.sort(spanishToEnglishFragments, function(a, b)
  return string.len(a[1] or "") > string.len(b[1] or "")
end)

local function TranslateSpanishTextToEnglish(text)
  local translated = text

  for _, replacement in ipairs(spanishToEnglishFragments) do
    translated = ReplacePlain(translated, replacement[1], replacement[2])
  end

  return translated
end

function LocalizeDataValue(value)
  local localized = PickLocalizedDataValue(value)

  if type(localized) ~= "string" then
    return localized
  end

  local exactTranslation = manualTextTranslations[localized]

  if exactTranslation then
    localized = PickLocalizedDataValue(exactTranslation) or localized
  end

  if GetDataLocale() ~= "esMX" then
    localized = TranslateSpanishTextToEnglish(localized)
  end

  return localized
end

local function GetMountVendor(mount)
  if type(mount) ~= "table" then
    return nil
  end

  if mount.vendor and mount.vendor ~= "" then
    return LocalizeDataValue(mount.vendor)
  end

  local source = GetMountSource(mount)

  if (source == "Vendor" or source == "Reputation") and mount.boss and mount.boss ~= "" then
    return LocalizeDataValue(mount.boss)
  end
end

local function FormatListValue(value, separator)
  if type(value) == "table" then
    if IsLocalizedDataTable(value) then
      return LocalizeDataValue(value)
    end

    local parts = {}

    for _, item in ipairs(value) do
      local localizedItem = LocalizeDataValue(item)

      if localizedItem and localizedItem ~= "" then
        table.insert(parts, tostring(localizedItem))
      end
    end

    if #parts > 0 then
      return table.concat(parts, separator or " > ")
    end

    return nil
  end

  if value == nil or value == "" then
    return nil
  end

  return tostring(LocalizeDataValue(value))
end

local function FormatDropChance(value)
  if type(value) == "number" then
    local percent = value

    if percent > 0 and percent < 1 then
      percent = percent * 100
    end

    if math.floor(percent) == percent then
      return string.format("%d%%", math.floor(percent))
    end

    local formatted = string.format("%.2f", percent)
    formatted = formatted:gsub("0+$", ""):gsub("%.$", "")

    return formatted .. "%"
  end

  return FormatListValue(value, ", ")
end

local function GetMountDropChance(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local explicitDropChance = FormatDropChance(mount.dropChance)

  if explicitDropChance and explicitDropChance ~= "" then
    local cleanExplicit = Normalize(explicitDropChance)

    if cleanExplicit == "muy baja" or cleanExplicit == "very low" then
      return "0.4%"
    end

    if cleanExplicit == "baja" or cleanExplicit == "low" then
      return "1%"
    end

    if string.find(cleanExplicit, "garantizada", 1, true)
      or string.find(cleanExplicit, "guaranteed", 1, true) then
      return "100%"
    end

    return explicitDropChance
  end

  local note = Normalize(LocalizeDataValue(mount.note) or "")

  if string.find(note, "drop bajo despues de", 1, true)
    or string.find(note, "low drop after", 1, true) then
    return "0.4%"
  end

  if string.find(note, "drop extremadamente raro", 1, true)
    or string.find(note, "extremely rare drop", 1, true) then
    return "0.03%"
  end

  if string.find(note, "drop de raid", 1, true)
    or string.find(note, "raid drop", 1, true) then
    return "1%"
  end

  if Normalize(GetMountSource(mount)) == "raid"
    and Normalize(mount.reset) == "weekly"
    and (string.find(note, "un intento semanal", 1, true)
      or string.find(note, "weekly attempt", 1, true)) then
    return "1%"
  end

  if string.find(note, "garantiz", 1, true)
    or string.find(note, "guaranteed", 1, true) then
    return "100%"
  end
end

local function GetMountEventName(mount)
  if type(mount) ~= "table" then
    return nil
  end

  return FormatListValue(mount.eventName or mount.event, ", ")
end

local activeCalendarEventsCacheKey
local activeCalendarEventsCache
local activeCalendarEventsCanRead = false

local function AddActiveCalendarEvent(events, title)
  if type(title) == "string" and title ~= "" then
    events[Normalize(title)] = true
    events[Normalize(title:gsub("[%'`]", ""))] = true
  end
end

local function GetCurrentCalendarDay()
  if C_Calendar and C_Calendar.GetDate then
    local dateInfo = SafeCall(C_Calendar.GetDate)

    if type(dateInfo) == "table" and tonumber(dateInfo.monthDay) then
      return tonumber(dateInfo.monthDay)
    end
  end

  return tonumber(date("%d"))
end

local function GetActiveCalendarEvents()
  local cacheKey = date("%Y-%m-%d")

  if activeCalendarEventsCacheKey == cacheKey then
    return activeCalendarEventsCache, activeCalendarEventsCanRead
  end

  local events = {}
  local canRead = false
  local monthDay = GetCurrentCalendarDay()

  if monthDay and C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent then
    if C_Calendar.OpenCalendar then
      SafeCall(C_Calendar.OpenCalendar)
    end

    local numEvents = SafeCall(C_Calendar.GetNumDayEvents, 0, monthDay)

    if tonumber(numEvents) then
      canRead = true

      for eventIndex = 1, tonumber(numEvents) do
        local eventInfo = SafeCall(C_Calendar.GetDayEvent, 0, monthDay, eventIndex)

        if type(eventInfo) == "table" then
          AddActiveCalendarEvent(events, eventInfo.title or eventInfo.name)
        elseif type(eventInfo) == "string" then
          AddActiveCalendarEvent(events, eventInfo)
        end
      end
    end
  end

  activeCalendarEventsCacheKey = canRead and cacheKey or nil
  activeCalendarEventsCache = canRead and events or {}
  activeCalendarEventsCanRead = canRead

  return events, canRead
end

local function AddEventSearchTerm(terms, text)
  if type(text) ~= "string" or text == "" then
    return
  end

  local cleanText = Normalize(text)

  if cleanText ~= "" then
    terms[cleanText] = true
    terms[Normalize(cleanText:gsub("[%'`]", ""))] = true
  end
end

local function BuildEventSearchTerms(eventName)
  local terms = {}

  AddEventSearchTerm(terms, eventName)

  local aliasKey = Normalize(tostring(eventName or ""):gsub("[%'`]", ""))
  local aliases = EVENT_ALIASES[aliasKey]

  if aliases then
    for _, alias in ipairs(aliases) do
      AddEventSearchTerm(terms, alias)
    end
  end

  return terms
end

local function IsNamedEventActive(eventName)
  local activeEvents, canRead = GetActiveCalendarEvents()

  if not canRead then
    return false
  end

  local terms = BuildEventSearchTerms(eventName)

  for activeTitle in pairs(activeEvents) do
    for term in pairs(terms) do
      if string.len(term) >= 4
        and (activeTitle == term
          or string.find(activeTitle, term, 1, true)
          or string.find(term, activeTitle, 1, true)) then
        return true
      end
    end
  end

  return false
end

local function IsEventMount(mount)
  if type(mount) ~= "table" then
    return false
  end

  return mount.reset == "event"
    or SourceMatches(GetMountSource(mount), "Event")
    or GetMountEventName(mount) ~= nil
end

local function IsEventMountAvailable(mount)
  if not IsEventMount(mount) then
    return true
  end

  if mount.eventActive == true or mount.activeEvent == true then
    return true
  end

  if mount.eventActive == false or mount.activeEvent == false then
    return false
  end

  local eventName = GetMountEventName(mount)

  if not eventName or eventName == "" then
    return false
  end

  return IsNamedEventActive(eventName)
end

local function GetMountRoute(mount)
  if type(mount) ~= "table" then
    return nil
  end

  return FormatListValue(mount.route or mount.farmRoute or mount.routeSteps, " > ")
end

local function GetMountMethod(mount)
  if type(mount) ~= "table" then
    return nil
  end

  return FormatListValue(mount.method or mount.acquireMethod or mount.acquisitionMethod, ", ")
    or GetSourceDisplayName(GetMountSource(mount))
end

local function GetMountCoordinates(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local coordinates = mount.coordinates or mount.coords or mount.coord
  local location = LocalizeDataValue(mount.location or mount.locationLabel)

  if not coordinates then
    local guide = GetMountLocationGuide(mount)

    if guide then
      coordinates = guide.coordinates or guide.coords or guide.coord
      location = location or LocalizeDataValue(guide.location or guide.locationLabel)
    end
  end

  local formattedCoordinates = FormatCoordinatesValue(coordinates)

  if formattedCoordinates and location and location ~= "" then
    return location .. ": " .. formattedCoordinates
  end

  return formattedCoordinates
end

function FindLocationGuideEntry(entries, key)
  if type(entries) ~= "table" or not key or key == "" then
    return nil
  end

  local direct = entries[key]

  if type(direct) == "table" then
    return direct
  end

  local cleanKey = Normalize(tostring(key))

  for entryKey, entry in pairs(entries) do
    if Normalize(tostring(entryKey)) == cleanKey and type(entry) == "table" then
      return entry
    end
  end
end

function GetMountLocationGuide(mount)
  if type(mount) ~= "table" or type(AzerColectLocationGuide) ~= "table" then
    return nil
  end

  local mounts = AzerColectLocationGuide.mounts
  local bosses = AzerColectLocationGuide.bosses
  local zones = AzerColectLocationGuide.zones
  local entry

  if type(mounts) == "table" then
    if mount.mountID then
      entry = mounts[mount.mountID] or mounts[tostring(mount.mountID)]
    end

    entry = entry
      or FindLocationGuideEntry(mounts, mount.name)
      or FindLocationGuideEntry(mounts, LocalizeDataValue(mount.name))
  end

  entry = entry
    or FindLocationGuideEntry(bosses, mount.boss)
    or FindLocationGuideEntry(bosses, LocalizeDataValue(mount.boss))
    or FindLocationGuideEntry(zones, mount.zone)
    or FindLocationGuideEntry(zones, LocalizeDataValue(mount.zone))

  return entry
end

function FormatCoordinatesValue(coordinates)
  if type(coordinates) == "table" then
    local x = coordinates.x or coordinates[1]
    local y = coordinates.y or coordinates[2]

    if tonumber(x) and tonumber(y) then
      return string.format("%.1f, %.1f", tonumber(x), tonumber(y))
    end
  end

  return FormatListValue(coordinates, ", ")
end

local function GetMountRespawn(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local respawn = FormatListValue(mount.respawn or mount.respawnTime or mount.spawnTimer, ", ")

  if respawn then
    return respawn
  end

  local guide = GetMountLocationGuide(mount)

  if guide then
    respawn = FormatListValue(guide.respawn or guide.respawnTime or guide.spawnTimer, ", ")

    if respawn then
      return respawn
    end
  end

  local source = Normalize(GetMountSource(mount))

  if mount.reset == "weekly" or source == "raid" or source == "world boss" then
    return L("weeklyLockoutGuide")
  end

  if mount.reset == "daily" then
    return L("dailyLockoutGuide")
  end

  if mount.reset == "repeatable" and source == "dungeon" then
    return L("repeatableInstanceGuide")
  end

  if source == "rare" then
    return L("variableRespawnGuide")
  end
end

local function GetMountMacro(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local macro = FormatListValue(mount.macro or mount.targetMacro, "\n")

  if macro then
    return macro
  end

  local guide = GetMountLocationGuide(mount)

  if guide then
    macro = FormatListValue(guide.macro or guide.targetMacro, "\n")

    if macro then
      return macro
    end
  end

  local source = Normalize(GetMountSource(mount))
  local boss = LocalizeDataValue(mount.boss)

  if boss and boss ~= "" and (source == "rare" or source == "world boss") then
    return "/target " .. boss
  end
end

local function GetMountTomTomCommand(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local explicitCommand = FormatListValue(mount.tomtom or mount.waypoint or mount.tomTom, "\n")

  if explicitCommand then
    return explicitCommand
  end

  local zone, coordinates = GetMountWaypointInfo(mount)

  if coordinates and zone and zone ~= "" then
    return "/way " .. zone .. " " .. coordinates
  end
end

function GetMountWaypointInfo(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local guide = GetMountLocationGuide(mount)
  local coordinates = FormatCoordinatesValue(mount.coordinates or mount.coords or mount.coord)
  local zone = LocalizeDataValue(mount.waypointZone
    or mount.mapZone
    or (guide and (guide.waypointZone or guide.mapZone or guide.zone))
    or mount.zone)

  if coordinates then
    return zone, coordinates
  end

  if guide then
    coordinates = FormatCoordinatesValue(guide.coordinates or guide.coords or guide.coord)
    zone = LocalizeDataValue(guide.waypointZone or guide.mapZone or guide.zone or mount.zone)
  end

  return zone, coordinates
end

local function FormatGuideRequirement(requirement)
  if type(requirement) == "table" then
    if IsLocalizedDataTable(requirement) then
      return L("requirementNeededMarker") .. " " .. LocalizeDataValue(requirement)
    end

    local text = LocalizeDataValue(requirement.text or requirement.name or requirement[1])
    local status = requirement.status or requirement.state
    local done = requirement.done
    local marker = L("requirementNeededMarker")

    if done == nil then
      done = requirement.completed
    end

    if done == nil then
      done = requirement.met
    end

    if done == true or status == true then
      marker = L("requirementMetMarker")
    elseif done == false or status == false then
      marker = L("requirementMissingMarker")
    elseif status then
      local cleanStatus = Normalize(status)

      if cleanStatus == "ok" or cleanStatus == "done" or cleanStatus == "met" or cleanStatus == "complete" then
        marker = L("requirementMetMarker")
      elseif cleanStatus == "missing" or cleanStatus == "no" or cleanStatus == "blocked" then
        marker = L("requirementMissingMarker")
      end
    end

    if text and text ~= "" then
      return marker .. " " .. text
    end
  end

  local text = LocalizeDataValue(requirement)

  if text and text ~= "" then
    return L("requirementNeededMarker") .. " " .. text
  end
end

local function GetMountRequirementsText(mount)
  if type(mount) ~= "table" then
    return nil
  end

  if type(mount.requirements) == "table" and not IsLocalizedDataTable(mount.requirements) then
    local lines = {}

    for _, requirement in ipairs(mount.requirements) do
      local line = FormatGuideRequirement(requirement)

      if line then
        table.insert(lines, line)
      end
    end

    if #lines > 0 then
      return table.concat(lines, "\n")
    end
  end

  local requirement = FormatListValue(mount.requirements or mount.requirement, "\n")

  if requirement then
    return FormatGuideRequirement(requirement)
  end
end

local function AddGuideLine(lines, label, value)
  if value and value ~= "" then
    table.insert(lines, label .. ": " .. value)
  end
end

local function AddGuideSection(lines, title)
  if #lines > 0 then
    table.insert(lines, "")
  end

  table.insert(lines, title)
end

local function AddGuideSectionLine(lines, label, value)
  if value and value ~= "" then
    table.insert(lines, "  " .. label .. ": " .. value)
  end
end

local function HasFarmRoute(mount)
  return GetMountRoute(mount) ~= nil
end

local function BuildCompactMountNote(mount, boss, vendor)
  if type(mount) ~= "table" then
    return ""
  end

  local details = {}
  local dropChance = GetMountDropChance(mount)
  local cost = LocalizeDataValue(mount.cost)
  local profession = GetMountProfession(mount)
  local eventName = GetMountEventName(mount)
  local route = GetMountRoute(mount)

  if boss and boss ~= "" and boss ~= L("unknownBoss") and boss ~= vendor then
    table.insert(details, boss)
  elseif vendor and vendor ~= "" then
    table.insert(details, vendor)
  end

  if dropChance then
    table.insert(details, L("dropChanceLabel") .. ": " .. dropChance)
  end

  if profession then
    table.insert(details, L("professionLabel") .. ": " .. profession)
  end

  if cost and cost ~= "" then
    table.insert(details, L("costLabel") .. ": " .. cost)
  end

  if eventName then
    table.insert(details, L("eventLabel") .. ": " .. eventName)
  end

  if route then
    table.insert(details, L("routeLabel"))
  end

  return ShortenText(table.concat(details, " | "), 72)
end

local function BuildMountInfoLine(mount)
  if type(mount) ~= "table" then
    return ""
  end

  local details = {}
  local vendor = GetMountVendor(mount)
  local eventName = GetMountEventName(mount)
  local dropChance = GetMountDropChance(mount)
  local route = GetMountRoute(mount)
  local unavailableReason = GetMountUnavailableReason(mount)
  local profession = GetMountProfession(mount)

  if unavailableReason then
    table.insert(details, L("unavailableLabel") .. ": " .. unavailableReason)
  end

  if vendor then
    table.insert(details, L("vendorLabel") .. ": " .. vendor)
  end

  if eventName then
    table.insert(details, L("eventLabel") .. ": " .. eventName)
  end

  if profession then
    table.insert(details, L("professionLabel") .. ": " .. profession)
  end

  local cost = LocalizeDataValue(mount.cost)
  local requirement = LocalizeDataValue(mount.requirement)

  if cost and cost ~= "" then
    table.insert(details, L("costLabel") .. ": " .. cost)
  end

  if requirement and requirement ~= "" then
    table.insert(details, L("requiresLabel") .. ": " .. requirement)
  end

  if dropChance then
    table.insert(details, L("dropChanceLabel") .. ": " .. dropChance)
  end

  if route then
    table.insert(details, L("routeLabel") .. ": " .. route)
  end

  return table.concat(details, " | ")
end

local function BuildMountPreviewDetails(mount)
  if type(mount) ~= "table" then
    return ""
  end

  local lines = {}
  local zone = LocalizeDataValue(mount.zone)
  local method = GetMountMethod(mount)
  local coordinates = GetMountCoordinates(mount)
  local requirements = GetMountRequirementsText(mount)
  local respawn = GetMountRespawn(mount)
  local macro = GetMountMacro(mount)
  local tomtom = GetMountTomTomCommand(mount)
  local cost = LocalizeDataValue(mount.cost)
  local dropChance = GetMountDropChance(mount)
  local bestCharacter = GetBestCharacterForMount(mount)
  local note = LocalizeDataValue(mount.note)
  local unavailableReason = GetMountUnavailableReason(mount)
  local profession = GetMountProfession(mount)

  if (not note or note == "") and mount.autoCatalog then
    note = LocalizeDataValue(mount.journalSource)
  end

  if method or profession or unavailableReason or bestCharacter then
    AddGuideSection(lines, L("previewSectionMethod"))
    AddGuideSectionLine(lines, L("methodLabel"), method)
    AddGuideSectionLine(lines, L("professionLabel"), profession)
    AddGuideSectionLine(lines, L("unavailableLabel"), unavailableReason)
    AddGuideSectionLine(lines, L("bestCharacterLabel"), bestCharacter)
  end

  if zone or coordinates then
    AddGuideSection(lines, L("previewSectionLocation"))
    AddGuideSectionLine(lines, L("zoneLabel"), zone)
    AddGuideSectionLine(lines, L("coordinatesLabel"), coordinates)
  end

  if requirements then
    AddGuideSection(lines, L("previewSectionRequirements"))
    table.insert(lines, requirements)
  end

  if respawn or dropChance or cost or macro or tomtom then
    AddGuideSection(lines, L("previewSectionReward"))
    AddGuideSectionLine(lines, L("respawnLabel"), respawn)
    AddGuideSectionLine(lines, L("dropChanceLabel"), dropChance)
    AddGuideSectionLine(lines, L("costLabel"), cost)
    AddGuideSectionLine(lines, L("macroLabel"), macro)
    AddGuideSectionLine(lines, L("tomtomLabel"), tomtom)
  end

  if note and note ~= "" then
    AddGuideSection(lines, L("previewSectionNotes"))
    table.insert(lines, "  " .. note)
  end

  return table.concat(lines, "\n")
end

local function BuildMountNote(mount)
  local info = BuildMountInfoLine(mount)
  local note = LocalizeDataValue(mount.note) or ""

  if note == "" and mount.autoCatalog then
    note = LocalizeDataValue(mount.journalSource) or ""
  end

  if info ~= "" and note ~= "" then
    return info .. " - " .. note
  end

  return info ~= "" and info or note
end

local function ShouldRequireActiveEventForMode(mode)
  if mode == "today" or mode == "missingEasy" then
    return true
  end

  return GetAzerColectOption("showInactiveEvents") == false
end

local function PassesMountFilters(mount)
  local expansion = GetMountExpansion(mount)
  local unavailable = IsMountUnavailable(mount)
  local eventAvailable = true

  if not unavailable and ShouldRequireActiveEventForMode(currentMode) then
    eventAvailable = IsEventMountAvailable(mount)
  end

  return IsExpansionEnabled(expansion)
    and eventAvailable
    and ExpansionMatches(expansion, currentExpansionFilter)
    and SourceMatches(GetMountSource(mount), currentSourceFilter)
end

local function GetAchievementSource(entry)
  if type(entry) ~= "table" then
    return "Achievement"
  end

  if entry.source and entry.source ~= "" then
    return entry.source
  end

  local note = Normalize(entry.note)

  if string.find(note, "raid", 1, true) then
    return "Raid Achievement"
  end

  if string.find(note, "dungeon", 1, true) then
    return "Dungeon Achievement"
  end

  if string.find(note, "delve", 1, true) then
    return "Delves Achievement"
  end

  return "Achievement"
end

local function PassesAchievementFilters(entry)
  local expansion = type(entry) == "table" and entry.expansion or "General"
  local source = GetAchievementSource(entry)

  return IsExpansionEnabled(expansion)
    and ExpansionMatches(expansion, currentExpansionFilter)
    and SourceMatches(source, currentSourceFilter)
end

local function BuildMountJournalNameCache()
  if not C_MountJournal or not C_MountJournal.GetMountIDs or not C_MountJournal.GetMountInfoByID then
    AzerColectRuntime.mountJournalNameCache = nil
    AzerColectRuntime.collectedMountNameCache = nil
    AzerColectRuntime.collectedMountIDCache = nil
    return nil
  end

  local mountIDs = SafeCall(C_MountJournal.GetMountIDs)

  if type(mountIDs) ~= "table" then
    AzerColectRuntime.mountJournalNameCache = nil
    AzerColectRuntime.collectedMountNameCache = nil
    AzerColectRuntime.collectedMountIDCache = nil
    return nil
  end

  AzerColectRuntime.mountJournalNameCache = {}
  AzerColectRuntime.collectedMountNameCache = {}
  AzerColectRuntime.collectedMountIDCache = {}
  AzerColectRuntime.mountDisplayNameCache = AzerColectRuntime.mountDisplayNameCache or {}
  AzerColectRuntime.mountIconCache = AzerColectRuntime.mountIconCache or {}

  for _, journalMountID in ipairs(mountIDs) do
    local info = GetJournalMountInfo(journalMountID)

    if info and info.name then
      local key = Normalize(info.name)

      AzerColectRuntime.mountJournalNameCache[key] = journalMountID
      AzerColectRuntime.mountDisplayNameCache[journalMountID] = info.name
      AzerColectRuntime.mountIconCache[journalMountID] = info.icon

      if info.isCollected == true then
        AzerColectRuntime.collectedMountIDCache[journalMountID] = true
        AzerColectRuntime.collectedMountNameCache[key] = true
      end
    end
  end

  return AzerColectRuntime.mountJournalNameCache
end

local function BuildCollectedMountNameCache()
  if not BuildMountJournalNameCache() then
    return nil
  end

  return AzerColectRuntime.collectedMountNameCache
end

local function GetMountJournalID(mount)
  if type(mount) ~= "table" then
    return mount
  end

  if mount.mountID and mount.mountID ~= 0 then
    return mount.mountID
  end

  if not mount.name or mount.name == "" then
    return nil
  end

  local cache = AzerColectRuntime.mountJournalNameCache or BuildMountJournalNameCache()

  if not cache then
    return nil
  end

  return cache[Normalize(mount.name)]
end

GetMountDisplayName = function(mount)
  if type(mount) ~= "table" then
    return tostring(mount or "")
  end

  local journalID = GetMountJournalID(mount)

  if journalID then
    local cachedName = AzerColectRuntime.mountDisplayNameCache and AzerColectRuntime.mountDisplayNameCache[journalID]

    if cachedName and cachedName ~= "" then
      return cachedName
    end

    local info = GetJournalMountInfo(journalID)

    if info and info.name and info.name ~= "" then
      return info.name
    end
  end

  return mount.name or L("previewMount")
end

local function IsMountNameCollected(mountName)
  if not mountName or mountName == "" then
    return false
  end

  local cache = AzerColectRuntime.collectedMountNameCache or BuildCollectedMountNameCache()

  if not cache then
    return false
  end

  return cache[Normalize(mountName)] == true
end

local function HasMount(mount)
  local mountID = GetMountJournalID(mount)
  local mountName = type(mount) == "table" and mount.name or nil

  if not mountID or mountID == 0 then
    mountID = nil
  end

  if not C_MountJournal or not C_MountJournal.GetMountInfoByID then
    return false
  end

  if mountID then
    if AzerColectRuntime.collectedMountIDCache then
      return AzerColectRuntime.collectedMountIDCache[mountID] == true
    end

    local info = GetJournalMountInfo(mountID)

    if info and info.isCollected == true then
      return true
    end
  end

  if mountName then
    return IsMountNameCollected(mountName)
  end

  return false
end

local function CollectionMatches(isCollected, mount)
  local unavailable = mount and IsMountUnavailable(mount)

  if unavailable then
    return false
  end

  if currentCollectionFilter == "all" then
    return true
  end

  if currentCollectionFilter == "collected" then
    return isCollected == true
  end

  return isCollected ~= true
end

local function FindMount(query)
  AddJournalMountCatalog()

  local cleanQuery = Normalize(query)

  if cleanQuery == "" then
    return nil
  end

  local mountID = tonumber(cleanQuery)
  local firstPartialMatch

  for _, mount in ipairs(AzerColectMounts or {}) do
    local mountName = Normalize(mount.name)
    local displayName = Normalize(GetMountDisplayName(mount))

    if mountID and mount.mountID == mountID then
      return mount
    end

    if mountName == cleanQuery or displayName == cleanQuery then
      return mount
    end

    if not firstPartialMatch
      and (string.find(mountName, cleanQuery, 1, true)
        or string.find(displayName, cleanQuery, 1, true)) then
      firstPartialMatch = mount
    end
  end

  return firstPartialMatch
end

local function FindAchievement(query)
  local cleanQuery = Normalize(query)

  if cleanQuery == "" then
    return nil
  end

  local queryID = tonumber(cleanQuery)
  local firstPartialMatch

  for _, entry in ipairs(AzerColectAchievements or {}) do
    local achievementID = GetAchievementID(entry)
    local achievementName = Normalize(GetAchievementDisplayName(entry))

    if queryID and achievementID == queryID then
      return entry
    end

    if achievementName == cleanQuery then
      return entry
    end

    if not firstPartialMatch and string.find(achievementName, cleanQuery, 1, true) then
      firstPartialMatch = entry
    end
  end

  return firstPartialMatch
end

local function SearchText()
  return Normalize(currentSearchText)
end

local function MountMatchesSearch(mount)
  local query = SearchText()

  if query == "" then
    return true
  end

  AzerColectRuntime.mountSearchTextCache = AzerColectRuntime.mountSearchTextCache or {}

  local key = GetMountKey(mount)
  local searchText = AzerColectRuntime.mountSearchTextCache[key]

  if not searchText then
    searchText = Normalize(
      (mount.name or "") .. " "
      .. GetMountDisplayName(mount) .. " "
      .. (LocalizeDataValue(mount.boss) or "") .. " "
      .. (LocalizeDataValue(mount.vendor) or "") .. " "
      .. (LocalizeDataValue(mount.zone) or "") .. " "
      .. (LocalizeDataValue(mount.cost) or "") .. " "
      .. (LocalizeDataValue(mount.requirement) or "") .. " "
      .. (GetMountEventName(mount) or "") .. " "
      .. (GetMountProfession(mount) or "") .. " "
      .. (GetMountDropChance(mount) or "") .. " "
      .. (GetMountRoute(mount) or "") .. " "
      .. (GetMountUnavailableReason(mount) or "") .. " "
      .. (LocalizeDataValue(mount.journalSource) or "") .. " "
      .. (LocalizeDataValue(mount.note) or "")
    )
    AzerColectRuntime.mountSearchTextCache[key] = searchText
  end

  return string.find(searchText, query, 1, true) ~= nil
end

local function AchievementMatchesSearch(item)
  local query = SearchText()

  if query == "" then
    return true
  end

  local rewardMount = ExtractMountNameFromReward(item.configuredReward)
    or ExtractMountNameFromReward(item.reward)
    or ""

  return string.find(Normalize(item.name), query, 1, true) ~= nil
    or string.find(Normalize(rewardMount), query, 1, true) ~= nil
end

local function OpenAchievement(achievementID)
  if not achievementID then
    Print(L("achievementUnknown"))
    return
  end

  if not AchievementFrame and AchievementFrame_LoadUI then
    AchievementFrame_LoadUI()
  end

  if OpenAchievementFrameToAchievement then
    OpenAchievementFrameToAchievement(achievementID)
    return
  end

  if AchievementFrame_SelectAchievement then
    if AchievementFrame then
      ShowUIPanel(AchievementFrame)
    end

    AchievementFrame_SelectAchievement(achievementID)
    return
  end

  if ToggleAchievementFrame then
    ToggleAchievementFrame()
    Print(L("achievementOpenFallback"))
    return
  end

  Print(L("achievementOpenUnavailable"))
end

local function GetAchievementProgress(entry)
  local achievementID = GetAchievementID(entry)

  if not achievementID then
    return nil
  end

  local id, name, points, completed, month, day, year, description,
    flags, icon, rewardText = SafeCall(GetAchievementInfo, achievementID)

  if not id then
    return nil
  end

  local total = SafeCall(GetAchievementNumCriteria, achievementID)

  if type(total) ~= "number" or total <= 0 then
    if completed then
      return name, 1, 1, rewardText, {}, true
    end

    return name, 0, 1, rewardText, {}, false
  end

  local done = 0
  local quantityDone = 0
  local quantityTotal = 0
  local missingCriteria = {}

  for i = 1, total do
    local criteriaString, criteriaType, completedCriteria, quantity, reqQuantity =
      SafeCall(GetAchievementCriteriaInfo, achievementID, i)

    if completedCriteria then
      done = done + 1
    end

    if type(quantity) == "number" and type(reqQuantity) == "number" and reqQuantity > 0 then
      quantityDone = quantityDone + math.min(quantity, reqQuantity)
      quantityTotal = quantityTotal + reqQuantity
    end

    if not completedCriteria and criteriaString and criteriaString ~= "" and #missingCriteria < 3 then
      local missingText = criteriaString

      if type(quantity) == "number" and type(reqQuantity) == "number" and reqQuantity > 0 then
        missingText = missingText .. " (" .. math.min(quantity, reqQuantity) .. "/" .. reqQuantity .. ")"
      end

      table.insert(missingCriteria, missingText)
    end
  end

  if quantityTotal > 0 then
    done = quantityDone
    total = quantityTotal
  end

  if completed then
    done = total
    missingCriteria = {}
  end

  return name, done, total, rewardText, missingCriteria, completed == true
end

local function SortMountItems(items)
  table.sort(items, function(a, b)
    local aFavorite = IsFavoriteMount(a.mount)
    local bFavorite = IsFavoriteMount(b.mount)

    if aFavorite ~= bFavorite then
      return aFavorite
    end

    return GetMountDisplayName(a.mount) < GetMountDisplayName(b.mount)
  end)
end

function GetCurrentCharacterProfile()
  EnsureDB()

  local characterKey = GetCharacterKey()
  local profile = AzerColectDB.characters[characterKey] or {}

  AzerColectDB.characters[characterKey] = profile
  profile.key = characterKey
  profile.name = UnitName("player") or L("unknownCharacter")
  profile.realm = GetRealmName() or L("unknownRealm")
  profile.level = UnitLevel and UnitLevel("player") or nil
  local className, classFile = UnitClass and UnitClass("player")
  profile.class = classFile or className
  profile.faction = UnitFactionGroup and UnitFactionGroup("player") or nil
  profile.lastSeen = Now()

  return profile
end

function StoreReputationSnapshot(profile)
  profile.reputations = {}
  profile.renown = {}

  local count = SafeCall(GetNumFactions)

  if type(count) == "number" then
    for index = 1, count do
      local name, description, standingID, barMin, barMax, barValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild,
        factionID = SafeCall(GetFactionInfo, index)

      if name and name ~= "" and not isHeader then
        local key = Normalize(name)
        local maxValue = tonumber(barMax) or 0
        local minValue = tonumber(barMin) or 0
        local value = tonumber(barValue) or 0
        local span = math.max(1, maxValue - minValue)

        profile.reputations[key] = {
          name = name,
          factionID = factionID,
          standingID = tonumber(standingID) or 0,
          barMin = minValue,
          barMax = maxValue,
          barValue = value,
          percent = math.floor(((value - minValue) / span) * 100 + 0.5)
        }
      end
    end
  end

  if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
    local repCount = SafeCall(C_Reputation.GetNumFactions)

    if type(repCount) == "number" then
      for index = 1, repCount do
        local data = SafeCall(C_Reputation.GetFactionDataByIndex, index)

        if type(data) == "table" and data.name and data.name ~= "" and not data.isHeader then
          local key = Normalize(data.name)
          local minValue = tonumber(data.currentReactionThreshold) or tonumber(data.barMin) or 0
          local maxValue = tonumber(data.nextReactionThreshold) or tonumber(data.barMax) or 0
          local value = tonumber(data.currentStanding) or tonumber(data.barValue) or 0
          local span = math.max(1, maxValue - minValue)

          profile.reputations[key] = {
            name = data.name,
            factionID = data.factionID,
            standingID = tonumber(data.reaction) or tonumber(data.standingID) or 0,
            barMin = minValue,
            barMax = maxValue,
            barValue = value,
            percent = math.floor(((value - minValue) / span) * 100 + 0.5)
          }
        end
      end
    end
  end

  if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.GetMajorFactionData then
    local ids = SafeCall(C_MajorFactions.GetMajorFactionIDs)

    if type(ids) == "table" then
      for _, factionID in ipairs(ids) do
        local data = SafeCall(C_MajorFactions.GetMajorFactionData, factionID)

        if type(data) == "table" and data.name and data.name ~= "" then
          profile.renown[Normalize(data.name)] = {
            name = data.name,
            factionID = factionID,
            level = tonumber(data.renownLevel) or tonumber(data.renownReputationLevel) or 0
          }
        end
      end
    end
  end
end

function StoreProfessionSnapshot(profile)
  profile.professions = {}

  if not GetProfessions or not GetProfessionInfo then
    return
  end

  local professionIndexes = { GetProfessions() }

  for slot = 1, 5 do
    local professionIndex = professionIndexes[slot]

    if professionIndex then
      local name, icon, skillLevel, maxSkillLevel = SafeCall(GetProfessionInfo, professionIndex)

      if name and name ~= "" then
        profile.professions[Normalize(name)] = {
          name = name,
          skill = tonumber(skillLevel) or 0,
          maxSkill = tonumber(maxSkillLevel) or 0
        }
      end
    end
  end
end

function GetQuestCompletionState(questID)
  questID = tonumber(questID)

  if not questID then
    return false, false
  end

  local completed = false
  local active = false

  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    completed = SafeCall(C_QuestLog.IsQuestFlaggedCompleted, questID) == true
  elseif IsQuestFlaggedCompleted then
    completed = SafeCall(IsQuestFlaggedCompleted, questID) == true
  end

  if C_QuestLog and C_QuestLog.IsOnQuest then
    active = SafeCall(C_QuestLog.IsOnQuest, questID) == true
  elseif IsQuestFlaggedCompleted then
    active = false
  end

  return completed, active
end

function NormalizeIDList(value)
  local list = {}

  if type(value) == "table" and not IsLocalizedDataTable(value) then
    for _, item in ipairs(value) do
      if tonumber(item) then
        table.insert(list, tonumber(item))
      end
    end
  elseif tonumber(value) then
    table.insert(list, tonumber(value))
  end

  return list
end

function StoreQuestSnapshot(profile)
  profile.quests = {}

  for _, requirement in ipairs(CollectConfiguredProgressRequirements()) do
    if requirement.kind == "quest" or requirement.kind == "questChain" or requirement.kind == "campaign" then
      for _, questID in ipairs(requirement.questIDs or {}) do
        local completed, active = GetQuestCompletionState(questID)

        profile.quests[tostring(questID)] = {
          id = questID,
          completed = completed == true,
          active = active == true,
          lastSeen = Now()
        }
      end
    end
  end
end

function StoreAchievementProgress(profile, achievementID)
  if not achievementID then
    return
  end

  local name, done, total, rewardText, missingCriteria, completed = GetAchievementProgress({ id = achievementID })

  if name then
    local percent = total and total > 0 and math.floor((done / total) * 100 + 0.5) or 0

    profile.achievements[tostring(achievementID)] = {
      id = achievementID,
      name = name,
      done = tonumber(done) or 0,
      total = tonumber(total) or 0,
      percent = completed and 100 or percent,
      completed = completed == true,
      lastSeen = Now()
    }
  end
end

function StoreAchievementSnapshot(profile)
  profile.achievements = {}

  for _, entry in ipairs(AzerColectAchievements or {}) do
    local achievementID = GetAchievementID(entry)

    if achievementID then
      StoreAchievementProgress(profile, achievementID)
    end
  end

  for _, requirement in ipairs(CollectConfiguredProgressRequirements()) do
    if requirement.kind == "achievement" and requirement.achievementID then
      StoreAchievementProgress(profile, requirement.achievementID)
    end
  end
end

function UpdateCurrentCharacterSnapshot(force)
  local now = Now()

  if not force and AzerColectRuntime.snapshotQueued then
    return
  end

  if not force and AzerColectRuntime.lastCharacterSnapshotAt > 0 and (now - AzerColectRuntime.lastCharacterSnapshotAt) < AzerColectRuntime.CHARACTER_SNAPSHOT_THROTTLE then
    if not AzerColectRuntime.snapshotQueued and C_Timer and C_Timer.After then
      AzerColectRuntime.snapshotQueued = true

      C_Timer.After(AzerColectRuntime.CHARACTER_SNAPSHOT_THROTTLE, function()
        AzerColectRuntime.snapshotQueued = false
        UpdateCurrentCharacterSnapshot(true)
        QueueRefreshWindow(0.05)
      end)
    end

    return
  end

  AzerColectRuntime.lastCharacterSnapshotAt = now

  local ok, profile = pcall(GetCurrentCharacterProfile)

  if not ok or type(profile) ~= "table" then
    return
  end

  pcall(StoreReputationSnapshot, profile)
  pcall(StoreProfessionSnapshot, profile)
  pcall(StoreQuestSnapshot, profile)
  pcall(StoreAchievementSnapshot, profile)
  InvalidateAzerColectDataCache()
end

function GetStoredCharacterCount()
  EnsureDB()

  local count = 0

  for _, profile in pairs(AzerColectDB.characters or {}) do
    if type(profile) == "table" and profile.name then
      count = count + 1
    end
  end

  return count
end

function GetStandingRequirementIndex(text)
  local cleanText = Normalize(text)
  local standings = {
    { "unfriendly", 3 },
    { "hated", 1 },
    { "odiado", 1 },
    { "hostile", 2 },
    { "hostil", 2 },
    { "neutral", 4 },
    { "friendly", 5 },
    { "amistoso", 5 },
    { "honored", 6 },
    { "honorable", 6 },
    { "revered", 7 },
    { "venerado", 7 },
    { "exalted", 8 },
    { "exaltado", 8 }
  }

  for _, standing in ipairs(standings) do
    local label = standing[1]
    local index = standing[2]

    if string.find(cleanText, label, 1, true) then
      return index, label
    end
  end
end

function AddProgressRequirement(requirements, requirement)
  if type(requirements) ~= "table" or type(requirement) ~= "table" then
    return
  end

  local kind = Normalize(requirement.kind or requirement.type or requirement.progressType or "")
  local label = LocalizeDataValue(requirement.label or requirement.name or requirement.title)

  if kind == "" then
    if requirement.questIDs or requirement.quests or requirement.questID then
      kind = "questchain"
    elseif requirement.achievementIDs or requirement.achievements or requirement.achievementID then
      kind = "achievement"
    elseif requirement.renownLevel or requirement.level then
      kind = "renown"
    elseif requirement.profession then
      kind = "profession"
    end
  end

  if kind == "quest"
    or kind == "quests"
    or kind == "questchain"
    or kind == "quest chain"
    or kind == "campaign"
    or kind == "story"
    or kind == "historia"
    or kind == "campana" then
    local questIDs = NormalizeIDList(requirement.questIDs
      or requirement.quests
      or requirement.questID
      or requirement.ids
      or requirement.id
      or requirement[1])

    if #questIDs > 0 then
      table.insert(requirements, {
        kind = (kind == "campaign" or kind == "story" or kind == "historia" or kind == "campana") and "campaign" or (#questIDs > 1 and "questChain" or "quest"),
        label = label,
        questIDs = questIDs,
        target = tonumber(requirement.target or requirement.required or requirement.requiredCount) or #questIDs
      })
    end

    return
  end

  if kind == "achievement" or kind == "achievements" or kind == "logro" or kind == "logros" then
    local achievementIDs = NormalizeIDList(requirement.achievementIDs
      or requirement.achievements
      or requirement.achievementID
      or requirement.ids
      or requirement.id
      or requirement[1])

    for _, achievementID in ipairs(achievementIDs) do
      table.insert(requirements, {
        kind = "achievement",
        achievementID = achievementID,
        label = label
      })
    end

    return
  end

  if kind == "renown" or kind == "renombre" then
    local faction = LocalizeDataValue(requirement.faction or requirement.name)
    local target = tonumber(requirement.level or requirement.renownLevel or requirement.target)

    if faction and faction ~= "" and target then
      table.insert(requirements, {
        kind = "renown",
        faction = faction,
        target = target
      })
    end

    return
  end

  if kind == "profession" or kind == "profesion" then
    local profession = LocalizeDataValue(requirement.profession or requirement.name)

    if profession and profession ~= "" then
      table.insert(requirements, {
        kind = "profession",
        profession = profession
      })
    end
  end
end

function AddProgressRequirementsFromList(requirements, progressList)
  if type(progressList) ~= "table" or IsLocalizedDataTable(progressList) then
    return
  end

  if progressList.kind or progressList.type or progressList.progressType then
    AddProgressRequirement(requirements, progressList)
    return
  end

  for _, requirement in ipairs(progressList) do
    AddProgressRequirement(requirements, requirement)
  end
end

function CollectConfiguredProgressRequirements()
  if AzerColectRuntime.configuredProgressRequirementsCache then
    return AzerColectRuntime.configuredProgressRequirementsCache
  end

  local requirements = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    for _, requirement in ipairs(ExtractMountProgressRequirements(mount)) do
      table.insert(requirements, requirement)
    end
  end

  AzerColectRuntime.configuredProgressRequirementsCache = requirements

  return requirements
end

function ExtractMountProgressRequirements(mount)
  local requirements = {}

  if type(mount) ~= "table" then
    return requirements
  end

  AzerColectRuntime.mountProgressRequirementsCache = AzerColectRuntime.mountProgressRequirementsCache or {}

  local mountKey = GetMountKey(mount)

  if AzerColectRuntime.mountProgressRequirementsCache[mountKey] then
    return AzerColectRuntime.mountProgressRequirementsCache[mountKey]
  end

  local faction = LocalizeDataValue(mount.reputation or mount.faction or mount.renownFaction)
  local renownLevel = tonumber(mount.renownLevel or mount.requiredRenown)

  if faction and faction ~= "" and renownLevel then
    table.insert(requirements, {
      kind = "renown",
      faction = faction,
      target = renownLevel
    })
  end

  local requirementText = LocalizeDataValue(mount.requirement) or ""
  local parsedFaction, parsedRenown = requirementText:match("^(.+)%s+[Rr]enown%s+(%d+)")

  if not parsedFaction then
    parsedFaction, parsedRenown = requirementText:match("^(.+)%s+[Rr]enombre%s+(%d+)")
  end

  if parsedFaction and parsedRenown then
    table.insert(requirements, {
      kind = "renown",
      faction = Trim(parsedFaction),
      target = tonumber(parsedRenown)
    })
  else
    local standingIndex, standingLabel = GetStandingRequirementIndex(requirementText)

    if standingIndex then
      local cleanRequirement = Normalize(requirementText)
      local standingStart = string.find(cleanRequirement, "%s+" .. standingLabel .. "$")
      local factionName = standingStart and Trim(string.sub(requirementText, 1, standingStart - 1))
        or Trim(requirementText)

      if factionName and factionName ~= "" then
        table.insert(requirements, {
          kind = "standing",
          faction = factionName,
          target = standingIndex
        })
      end
    end
  end

  local requiredProfession = LocalizeDataValue(mount.requiredProfession or mount.profession)

  if requiredProfession and requiredProfession ~= "" then
    table.insert(requirements, {
      kind = "profession",
      profession = requiredProfession
    })
  end

  local achievementID = mount.requiredAchievementID
    or mount.campaignAchievementID
    or mount.achievementID

  if achievementID then
    table.insert(requirements, {
      kind = "achievement",
      achievementID = tonumber(achievementID) or achievementID,
      label = LocalizeDataValue(mount.requiredAchievementName or mount.campaignName)
    })
  end

  local achievementIDs = NormalizeIDList(mount.requiredAchievementIDs
    or mount.campaignAchievementIDs
    or mount.storyAchievementIDs
    or mount.achievementIDs)

  for _, extraAchievementID in ipairs(achievementIDs) do
    table.insert(requirements, {
      kind = "achievement",
      achievementID = extraAchievementID,
      label = LocalizeDataValue(mount.requiredAchievementName or mount.campaignName)
    })
  end

  AddProgressRequirement(requirements, {
    type = "questChain",
    questIDs = mount.requiredQuestIDs or mount.questIDs,
    label = LocalizeDataValue(mount.questChainName or mount.progressName)
  })

  AddProgressRequirement(requirements, {
    type = "campaign",
    questIDs = mount.campaignQuestIDs or mount.storyQuestIDs,
    label = LocalizeDataValue(mount.campaignName or mount.storyName)
  })

  AddProgressRequirementsFromList(requirements, mount.progressRequirements or mount.progress or mount.altProgress or mount.storyProgress)

  local achievementEntry = FindAchievementForMount(mount)

  if achievementEntry then
    table.insert(requirements, {
      kind = "achievement",
      achievementID = GetAchievementID(achievementEntry),
      label = GetAchievementDisplayName(achievementEntry)
    })
  end

  AzerColectRuntime.mountProgressRequirementsCache[mountKey] = requirements

  return requirements
end

function BuildAchievementMountLookup()
  if AzerColectRuntime.achievementLookupByMountID and AzerColectRuntime.achievementLookupByName then
    return
  end

  AzerColectRuntime.achievementLookupByMountID = {}
  AzerColectRuntime.achievementLookupByName = {}

  for _, entry in ipairs(AzerColectAchievements or {}) do
    if type(entry) == "table" then
      if entry.mountID then
        AzerColectRuntime.achievementLookupByMountID[entry.mountID] = entry
      end

      local rewardMount = Normalize(ExtractMountNameFromReward(entry.reward) or "")

      if rewardMount ~= "" then
        AzerColectRuntime.achievementLookupByName[rewardMount] = entry
      end
    end
  end
end

function FindAchievementForMount(mount)
  if type(mount) ~= "table" then
    return nil
  end

  BuildAchievementMountLookup()

  if mount.mountID and AzerColectRuntime.achievementLookupByMountID and AzerColectRuntime.achievementLookupByMountID[mount.mountID] then
    return AzerColectRuntime.achievementLookupByMountID[mount.mountID]
  end

  local mountName = Normalize(GetMountDisplayName(mount))

  if AzerColectRuntime.achievementLookupByName then
    return AzerColectRuntime.achievementLookupByName[mountName]
  end
end

function ScoreCharacterForRequirement(profile, requirement)
  if type(profile) ~= "table" or type(requirement) ~= "table" then
    return 0
  end

  if requirement.kind == "renown" then
    local key = Normalize(requirement.faction)
    local renown = profile.renown and profile.renown[key]
    local level = renown and tonumber(renown.level) or 0
    local target = math.max(1, tonumber(requirement.target) or 1)
    local score = math.min(level, target) / target * 120
    local reason = L("altReasonRenown", level, target)

    if level >= target then
      score = score + 500
    end

    return score, reason
  end

  if requirement.kind == "standing" then
    local key = Normalize(requirement.faction)
    local reputation = profile.reputations and profile.reputations[key]
    local standing = reputation and tonumber(reputation.standingID) or 0
    local target = math.max(1, tonumber(requirement.target) or 1)
    local score = math.min(standing, target) / target * 120
    local reason = L("altReasonReputation", standing, target)

    if standing >= target then
      score = score + 500
    elseif reputation and reputation.percent then
      score = score + math.min(30, tonumber(reputation.percent) or 0)
    end

    return score, reason
  end

  if requirement.kind == "profession" then
    local key = Normalize(requirement.profession)
    local profession = profile.professions and profile.professions[key]

    if profession then
      return 140 + math.min(60, tonumber(profession.skill) or 0), L("altReasonProfession", profession.name)
    end

    return 0, L("altReasonProfessionMissing", requirement.profession)
  end

  if requirement.kind == "achievement" and requirement.achievementID then
    local achievement = profile.achievements and profile.achievements[tostring(requirement.achievementID)]

    if achievement then
      local score = tonumber(achievement.percent) or 0
      local reason = L("altReasonAchievement", score)

      if achievement.completed then
        score = score + 500
        reason = L("altReasonAchievementDone")
      end

      return score, reason
    end
  end

  if requirement.kind == "quest" or requirement.kind == "questChain" or requirement.kind == "campaign" then
    local questIDs = requirement.questIDs or {}
    local total = math.max(1, tonumber(requirement.target) or #questIDs)
    local completed = 0
    local active = 0

    for _, questID in ipairs(questIDs) do
      local quest = profile.quests and profile.quests[tostring(questID)]

      if quest and quest.completed then
        completed = completed + 1
      elseif quest and quest.active then
        active = active + 1
      end
    end

    local progressValue = math.min(total, completed + (active * 0.5))
    local score = (progressValue / total) * 180
    local label = requirement.label
    local reason = label and label ~= ""
      and L("altReasonNamedProgress", label, completed, total)
      or L("altReasonProgress", completed, total)

    if completed >= total then
      score = score + 500
      reason = label and label ~= ""
        and L("altReasonNamedProgressDone", label)
        or L("altReasonProgressDone")
    end

    return score, reason
  end

  return 0
end

function GetCharacterDisplayName(profile)
  if type(profile) ~= "table" then
    return L("unknownCharacter")
  end

  return (profile.name or L("unknownCharacter")) .. "-" .. (profile.realm or L("unknownRealm"))
end

function GetBestCharacterForMount(mount)
  EnsureDB()

  local requirements = ExtractMountProgressRequirements(mount)

  if #requirements == 0 then
    return nil
  end

  local bestProfile
  local bestScore = -1
  local bestReasons = {}

  for _, profile in pairs(AzerColectDB.characters or {}) do
    if type(profile) == "table" and profile.name then
      local score = 0
      local reasons = {}

      for _, requirement in ipairs(requirements) do
        local requirementScore, reason = ScoreCharacterForRequirement(profile, requirement)

        score = score + (tonumber(requirementScore) or 0)

        if reason and reason ~= "" and #reasons < 2 then
          table.insert(reasons, reason)
        end
      end

      if score > bestScore then
        bestProfile = profile
        bestScore = score
        bestReasons = reasons
      end
    end
  end

  if not bestProfile then
    return L("altNoSnapshots")
  end

  local displayName = GetCharacterDisplayName(bestProfile)
  local currentMarker = bestProfile.key == GetCharacterKey() and " " .. L("altCurrentCharacter") or ""

  if #bestReasons == 0 then
    return displayName .. currentMarker
  end

  return displayName .. currentMarker .. " (" .. table.concat(bestReasons, " | ") .. ")"
end

function GetEasyMountMinutes(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local explicitTime = mount.easyTime or mount.priorityTime or mount.timeEstimate or mount.estimatedTime

  if tonumber(explicitTime) then
    return tonumber(explicitTime)
  end

  local source = Normalize(GetMountSource(mount))

  if source == "vendor" then
    return 3
  end

  if source == "reputation" then
    return 5
  end

  if source == "quest" or source == "daily quest" or source == "world quest" then
    return 8
  end

  if source == "dungeon" then
    return mount.reset == "repeatable" and 5 or 10
  end

  if source == "event" then
    return 5
  end

  if source == "rare" then
    return 10
  end

  if source == "secret" then
    return 12
  end
end

function GetEasyMountActionText(mount)
  if type(mount) ~= "table" then
    return nil
  end

  local customText = LocalizeDataValue(mount.easyText or mount.easyAction or mount.quickNote)

  if customText and customText ~= "" then
    return customText
  end

  local source = Normalize(GetMountSource(mount))
  local cost = LocalizeDataValue(mount.cost)

  if cost and cost ~= "" and (source == "vendor" or source == "reputation") then
    return L("easyCost", cost)
  end

  if source == "vendor" then
    return L("easyBuyOnly")
  end

  local minutes = GetEasyMountMinutes(mount)

  if minutes then
    return L("easyTime", minutes)
  end

  if source == "reputation" then
    return L("easyReputation")
  end

  if source == "quest" or source == "daily quest" or source == "world quest" then
    return L("easyQuest")
  end

  if source == "event" then
    return L("easyActiveEvent")
  end
end

function GetEasyMountScore(mount)
  if type(mount) ~= "table" then
    return 999
  end

  local source = Normalize(GetMountSource(mount))
  local score = 100

  if mount.easy == true or mount.quick == true then
    score = 1
  elseif source == "vendor" then
    score = 10
  elseif source == "reputation" then
    score = 18
  elseif source == "quest" or source == "daily quest" or source == "world quest" then
    score = 24
  elseif source == "dungeon" and mount.reset == "repeatable" then
    score = 30
  elseif source == "dungeon" and mount.reset == "daily" then
    score = 36
  elseif source == "event" then
    score = 38
  elseif source == "rare" then
    score = 44
  elseif source == "secret" then
    score = 50
  end

  if IsFavoriteMount(mount) then
    score = score - 3
  end

  if mount.requirement or mount.requirements then
    score = score + 8
  end

  if GetMountDropChance(mount) == "100%" then
    score = score - 5
  end

  return score
end

function IsEasyMissingMount(mount)
  if type(mount) ~= "table" or HasMount(mount) or IsMountUnavailable(mount) or not IsEventMountAvailable(mount) then
    return false
  end

  if mount.easy == true or mount.quick == true then
    return true
  end

  if mount.easy == false or mount.quick == false then
    return false
  end

  local source = Normalize(GetMountSource(mount))

  if source == "vendor" then
    return true
  end

  if source == "reputation" and mount.cost then
    return true
  end

  if source == "quest" or source == "daily quest" or source == "world quest" then
    return true
  end

  if source == "dungeon" and mount.reset ~= "weekly" then
    return true
  end

  if source == "event" then
    return true
  end

  if source == "rare" then
    return GetMountCoordinates(mount) ~= nil or GetMountMacro(mount) ~= nil or GetMountDropChance(mount) == "100%"
  end

  if source == "secret" and (GetMountCoordinates(mount) or HasFarmRoute(mount)) then
    return true
  end

  return false
end

function BuildEasyMissingItems()
  local items = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    local collected = HasMount(mount)

    if IsEasyMissingMount(mount)
      and PassesMountFilters(mount)
      and MountMatchesSearch(mount)
      and CollectionMatches(collected, mount) then
      table.insert(items, {
        kind = "mount",
        mount = mount
      })
    end
  end

  table.sort(items, function(a, b)
    local aScore = GetEasyMountScore(a.mount)
    local bScore = GetEasyMountScore(b.mount)

    if aScore ~= bScore then
      return aScore < bScore
    end

    local aTime = GetEasyMountMinutes(a.mount) or 999
    local bTime = GetEasyMountMinutes(b.mount) or 999

    if aTime ~= bTime then
      return aTime < bTime
    end

    return GetMountDisplayName(a.mount) < GetMountDisplayName(b.mount)
  end)

  return items, L("noEasyMissingMounts")
end

local function BuildMountItems(mode)
  local items = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    local collected = HasMount(mount)

    if ShouldShowMount(mount, mode)
      and PassesMountFilters(mount)
      and MountMatchesSearch(mount)
      and CollectionMatches(collected, mount) then
      table.insert(items, {
        kind = "mount",
        mount = mount
      })
    end
  end

  SortMountItems(items)

  return items
end

local function IsMountAchievement(entry)
  if type(entry) ~= "table" then
    return false
  end

  if entry.mountID and entry.mountID ~= 0 then
    return true
  end

  local reward = Trim(entry.reward or "")

  return string.find(reward, "Mount:", 1, true) == 1
    or string.find(reward, "Montura:", 1, true) == 1
end

local function CreateAchievementItem(entry)
  if not IsMountAchievement(entry) then
    return nil
  end

  local achievementID = GetAchievementID(entry)
  local name, done, total, rewardText, missingCriteria, completed = GetAchievementProgress(entry)

  if name and total > 0 then
    local percent = math.floor((done / total) * 100)
    local reward = rewardText

    if completed then
      percent = 100
    end

    if not reward or reward == "" then
      reward = (type(entry) == "table" and LocalizeDataValue(entry.reward)) or L("previewEmpty")
    end

    return {
      kind = "achievement",
      achievementID = achievementID,
      name = name,
      done = done,
      total = total,
      percent = percent,
      completed = completed == true,
      reward = reward,
      configuredReward = type(entry) == "table" and entry.reward or nil,
      mountID = type(entry) == "table" and entry.mountID or nil,
      expansion = type(entry) == "table" and entry.expansion or "General",
      source = GetAchievementSource(entry),
      note = type(entry) == "table" and entry.note or "",
      missingCriteria = missingCriteria or {},
      favorite = IsFavoriteAchievement(entry)
    }
  end
end

local function SortAchievementItems(items)
  table.sort(items, function(a, b)
    if a.favorite ~= b.favorite then
      return a.favorite
    end

    if a.completed ~= b.completed then
      return not a.completed
    end

    if a.percent == b.percent then
      return a.name < b.name
    end

    return a.percent > b.percent
  end)
end

local function BuildAchievementItems()
  local items = {}

  if not AzerColectAchievements or #AzerColectAchievements == 0 then
    return items, L("noAchievementsConfigured")
  end

  for _, entry in ipairs(AzerColectAchievements or {}) do
    local item = PassesAchievementFilters(entry) and CreateAchievementItem(entry)

    if item and AchievementMatchesSearch(item) and CollectionMatches(item.completed) then
      table.insert(items, item)
    end
  end

  SortAchievementItems(items)

  return items, L("noMountAchievements")
end

local function BuildSourceItems()
  local items = {}
  local achievementMountIDs = {}

  if currentSourceFilter == "Achievement" or currentSourceFilter == "all" then
    for _, entry in ipairs(AzerColectAchievements or {}) do
      local item = PassesAchievementFilters(entry) and CreateAchievementItem(entry)

      if item and AchievementMatchesSearch(item) and CollectionMatches(item.completed) then
        if item.mountID then
          achievementMountIDs[item.mountID] = true
        end

        table.insert(items, item)
      end
    end
  end

  for _, mount in ipairs(AzerColectMounts or {}) do
    local collected = HasMount(mount)
    local isDuplicateAchievementMount = mount.mountID
      and achievementMountIDs[mount.mountID]
      and SourceMatches(GetMountSource(mount), "Achievement")

    if not isDuplicateAchievementMount
      and PassesMountFilters(mount)
      and MountMatchesSearch(mount)
      and CollectionMatches(collected, mount) then
      table.insert(items, {
        kind = "mount",
        mount = mount
      })
    end
  end

  table.sort(items, function(a, b)
    if a.kind ~= b.kind then
      return a.kind == "mount"
    end

    if a.kind == "achievement" then
      if a.completed ~= b.completed then
        return not a.completed
      end

      if a.percent == b.percent then
        return a.name < b.name
      end

      return a.percent > b.percent
    end

    local aCollected = HasMount(a.mount)
    local bCollected = HasMount(b.mount)

    if aCollected ~= bCollected then
      return not aCollected
    end

    return a.mount.name < b.mount.name
  end)

  return items, L("noSourceMounts")
end

local function BuildRouteItems()
  local items = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    local collected = HasMount(mount)

    if HasFarmRoute(mount)
      and PassesMountFilters(mount)
      and MountMatchesSearch(mount)
      and CollectionMatches(collected, mount) then
      table.insert(items, {
        kind = "mount",
        mount = mount
      })
    end
  end

  SortMountItems(items)

  return items, L("noRouteMounts")
end

local function BuildFavoriteItems()
  local items = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    local collected = HasMount(mount)

    if IsFavoriteMount(mount)
      and PassesMountFilters(mount)
      and MountMatchesSearch(mount)
      and CollectionMatches(collected, mount) then
      table.insert(items, {
        kind = "mount",
        mount = mount
      })
    end
  end

  for _, entry in ipairs(AzerColectAchievements or {}) do
    if IsFavoriteAchievement(entry) and PassesAchievementFilters(entry) then
      local item = CreateAchievementItem(entry)

      if item and AchievementMatchesSearch(item) and CollectionMatches(item.completed) then
        table.insert(items, item)
      end
    end
  end

  table.sort(items, function(a, b)
    if a.kind ~= b.kind then
      return a.kind == "mount"
    end

    if a.kind == "achievement" then
      if a.completed ~= b.completed then
        return not a.completed
      end

      if a.percent == b.percent then
        return a.name < b.name
      end

      return a.percent > b.percent
    end

    return GetMountDisplayName(a.mount) < GetMountDisplayName(b.mount)
  end)

  return items, L("noFavorites")
end

local function BuildItems()
  AddJournalMountCatalog()

  local cacheKey = currentMode .. "\001"
    .. currentExpansionFilter .. "\001"
    .. currentSourceFilter .. "\001"
    .. currentCollectionFilter .. "\001"
    .. SearchText() .. "\001"
    .. tostring(AzerColectRuntime.cacheRevision)

  if AzerColectRuntime.itemListCacheKey == cacheKey and AzerColectRuntime.itemListCacheItems then
    return AzerColectRuntime.itemListCacheItems, AzerColectRuntime.itemListCacheEmptyText
  end

  local items
  local emptyText

  if currentMode == "favorites" then
    items, emptyText = BuildFavoriteItems()
  elseif currentMode == "missingEasy" then
    items, emptyText = BuildEasyMissingItems()
  elseif currentMode == "achievements" then
    items, emptyText = BuildAchievementItems()
  elseif currentMode == "sources" then
    items, emptyText = BuildSourceItems()
  elseif currentMode == "routes" then
    items, emptyText = BuildRouteItems()
  elseif currentMode == "reputation" or currentMode == "events" then
    items, emptyText = BuildMountItems("all"), L("noSourceMounts")
  else
    items, emptyText = BuildMountItems(currentMode), L("noPendingMounts")
  end

  AzerColectRuntime.itemListCacheKey = cacheKey
  AzerColectRuntime.itemListCacheItems = items
  AzerColectRuntime.itemListCacheEmptyText = emptyText

  return items, emptyText
end

local function CountAttempted(items)
  local attempted = 0

  for _, item in ipairs(items) do
    if item.kind == "mount" and IsAttempted(item.mount) then
      attempted = attempted + 1
    end
  end

  return attempted
end

local function CountMountsForMode(mode)
  local total = 0
  local attempted = 0

  for _, mount in ipairs(AzerColectMounts or {}) do
    if ShouldShowMount(mount, mode)
      and (not ShouldRequireActiveEventForMode(mode) or IsEventMountAvailable(mount))
      and not IsMountUnavailable(mount)
      and not HasMount(mount) then
      total = total + 1

      if IsAttempted(mount) then
        attempted = attempted + 1
      end
    end
  end

  return math.max(0, total - attempted), attempted, total
end

local function GetCollectionStats()
  if AzerColectRuntime.collectionStatsCacheRevision == AzerColectRuntime.cacheRevision and AzerColectRuntime.collectionStatsCache then
    return AzerColectRuntime.collectionStatsCache.total, AzerColectRuntime.collectionStatsCache.collected, AzerColectRuntime.collectionStatsCache.missing, AzerColectRuntime.collectionStatsCache.favorites
  end

  local total = 0
  local collected = 0
  local favorites = 0

  for _, mount in ipairs(AzerColectMounts or {}) do
    if IsExpansionEnabled(GetMountExpansion(mount)) and not IsMountUnavailable(mount) then
      total = total + 1

      if HasMount(mount) then
        collected = collected + 1
      end

      if IsFavoriteMount(mount) then
        favorites = favorites + 1
      end
    end
  end

  AzerColectRuntime.collectionStatsCacheRevision = AzerColectRuntime.cacheRevision
  AzerColectRuntime.collectionStatsCache = {
    total = total,
    collected = collected,
    missing = math.max(0, total - collected),
    favorites = favorites
  }

  return AzerColectRuntime.collectionStatsCache.total, AzerColectRuntime.collectionStatsCache.collected, AzerColectRuntime.collectionStatsCache.missing, AzerColectRuntime.collectionStatsCache.favorites
end

function GetJournalCollectionCounts()
  local total = 0
  local collected = 0

  if not C_MountJournal or not C_MountJournal.GetMountIDs then
    return collected, total
  end

  local mountIDs = SafeCall(C_MountJournal.GetMountIDs)

  if type(mountIDs) ~= "table" then
    return collected, total
  end

  for _, mountID in ipairs(mountIDs) do
    local info = GetJournalMountInfo(mountID)
    local extra = GetJournalMountExtra(mountID) or {}

    if info and not IsMountUnavailable({
      name = info.name,
      mountID = mountID,
      sourceType = info.sourceType,
      source = InferJournalMountSource(info.sourceType, extra.sourceText or extra.description, info.name),
      journalSource = extra.sourceText or extra.description
    }) then
      total = total + 1

      if info.isCollected then
        collected = collected + 1
      end
    end
  end

  return collected, total
end

function FormatTrackedTime(seconds)
  seconds = math.max(0, tonumber(seconds) or 0)

  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)

  if days > 0 then
    return L("newMountTimeDays", days, hours)
  end

  if hours > 0 then
    return L("newMountTimeHours", hours, minutes)
  end

  return L("newMountTimeMinutes", math.max(1, minutes))
end

function GetNewMountAlertStats(mountID, mountName)
  EnsureDB()

  local mount = {
    name = mountName or L("previewMount"),
    mountID = mountID
  }
  local history = GetMountHistory(mount) or {}
  local attempts = tonumber(history.attempts) or 0
  local timeText = L("newMountUnknown")
  local estimatedMinutes = tonumber(history.estimatedMinutes) or 0

  if estimatedMinutes <= 0 and attempts > 0 then
    estimatedMinutes = attempts * 10
  end

  if estimatedMinutes > 0 then
    timeText = FormatTrackedTime(estimatedMinutes * 60)
  elseif history.firstAttemptAt then
    timeText = FormatTrackedTime(Now() - history.firstAttemptAt)
  end

  local collected, total = GetJournalCollectionCounts()

  return {
    attempts = attempts > 0 and tostring(attempts) or L("newMountUnknown"),
    timeText = timeText,
    collectionText = collected .. "/" .. total
  }
end

function CaptureKnownMountCollection(showAlerts)
  EnsureDB()

  if not C_MountJournal or not C_MountJournal.GetMountIDs then
    return
  end

  InvalidateMountJournalCaches()

  local mountIDs = SafeCall(C_MountJournal.GetMountIDs)

  if type(mountIDs) ~= "table" then
    return
  end

  local knownMounts = AzerColectDB.knownMounts or {}
  local initialized = AzerColectDB.knownMountsInitialized == true
  local newMounts = {}

  for _, mountID in ipairs(mountIDs) do
    local info = GetJournalMountInfo(mountID)

    if info and info.isCollected then
      local key = tostring(mountID)

      if not knownMounts[key] then
        knownMounts[key] = true

        if showAlerts and initialized then
          table.insert(newMounts, {
            mountID = mountID,
            name = info.name
          })
        end
      end
    end
  end

  AzerColectDB.knownMounts = knownMounts
  AzerColectDB.knownMountsInitialized = true

  for _, mountInfo in ipairs(newMounts) do
    QueueNewMountAlert(mountInfo.mountID, mountInfo.name)
  end
end

function ScheduleMountCollectionScan(showAlerts)
  AzerColectRuntime.mountScanShouldAlert = AzerColectRuntime.mountScanShouldAlert or showAlerts

  if AzerColectRuntime.mountScanQueued then
    return
  end

  AzerColectRuntime.mountScanQueued = true

  if C_Timer and C_Timer.After then
    C_Timer.After(showAlerts and 0.8 or 4, function()
      local shouldAlert = AzerColectRuntime.mountScanShouldAlert == true

      AzerColectRuntime.mountScanQueued = false
      AzerColectRuntime.mountScanShouldAlert = false
      CaptureKnownMountCollection(shouldAlert)

      if mainFrame and mainFrame:IsShown() then
        QueueRefreshWindow(0.05)
      end
    end)
  else
    local shouldAlert = AzerColectRuntime.mountScanShouldAlert == true

    AzerColectRuntime.mountScanQueued = false
    AzerColectRuntime.mountScanShouldAlert = false
    CaptureKnownMountCollection(shouldAlert)
  end
end

function GetExpansionDisplayName(expansion)
  for _, option in ipairs(expansionFilterOptions or {}) do
    if option.value == expansion then
      return option.label
    end
  end

  return expansion or L("unknownZone")
end

function BuildExpansionProgressStats()
  if AzerColectRuntime.expansionProgressCacheRevision == AzerColectRuntime.cacheRevision and AzerColectRuntime.expansionProgressOrdered and AzerColectRuntime.expansionProgressStats then
    return AzerColectRuntime.expansionProgressOrdered, AzerColectRuntime.expansionProgressStats
  end

  local stats = {}
  local ordered = {}

  for _, option in ipairs(expansionFilterOptions or {}) do
    if option.value ~= "all" and IsExpansionEnabled(option.value) then
      stats[option.value] = {
        expansion = option.value,
        label = option.label,
        total = 0,
        collected = 0
      }

      table.insert(ordered, stats[option.value])
    end
  end

  for _, mount in ipairs(AzerColectMounts or {}) do
    local expansion = GetMountExpansion(mount)

    if IsExpansionEnabled(expansion) and not IsMountUnavailable(mount) then
      if not stats[expansion] then
        stats[expansion] = {
          expansion = expansion,
          label = GetExpansionDisplayName(expansion),
          total = 0,
          collected = 0
        }

        table.insert(ordered, stats[expansion])
      end

      stats[expansion].total = stats[expansion].total + 1

      if HasMount(mount) then
        stats[expansion].collected = stats[expansion].collected + 1
      end
    end
  end

  AzerColectRuntime.expansionProgressCacheRevision = AzerColectRuntime.cacheRevision
  AzerColectRuntime.expansionProgressOrdered = ordered
  AzerColectRuntime.expansionProgressStats = stats

  return ordered, stats
end

function FormatExpansionProgressLine(stat)
  if type(stat) ~= "table" or (tonumber(stat.total) or 0) <= 0 then
    return nil
  end

  local total = tonumber(stat.total) or 0
  local collected = tonumber(stat.collected) or 0
  local percent = total > 0 and math.floor((collected / total) * 100 + 0.5) or 0

  return L("expansionProgressLine", stat.label or stat.expansion or "", collected, total, percent)
end

function GetCurrentExpansionProgressText()
  local ordered, stats = BuildExpansionProgressStats()

  if currentExpansionFilter ~= "all" and stats[currentExpansionFilter] then
    return FormatExpansionProgressLine(stats[currentExpansionFilter])
  end

  local bestMissing

  for _, stat in ipairs(ordered) do
    if stat.total and stat.total > 0 then
      local missing = stat.total - stat.collected

      if missing > 0 and (not bestMissing or missing > (bestMissing.total - bestMissing.collected)) then
        bestMissing = stat
      end
    end
  end

  if bestMissing then
    return L("expansionProgressHint", FormatExpansionProgressLine(bestMissing))
  end

  return L("expansionProgressComplete")
end

function ShowExpansionProgressTooltip(owner)
  if not GameTooltip or not owner then
    return
  end

  local ordered = BuildExpansionProgressStats()

  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(L("expansionProgressTitle"))

  for _, stat in ipairs(ordered) do
    local line = FormatExpansionProgressLine(stat)

    if line then
      GameTooltip:AddLine(line, 0.9, 0.9, 1)
    end
  end

  GameTooltip:Show()
end

function ShortenText(text, maxLength)
  text = tostring(text or "")
  maxLength = maxLength or 24

  if string.len(text) <= maxLength then
    return text
  end

  return string.sub(text, 1, math.max(1, maxLength - 3)) .. "..."
end

function GetSmartPriorityScope()
  if currentMode == "weekly" then
    return "weekly", L("priorityWeeklyTitle")
  end

  if currentMode == "reputation" then
    return "reputation", L("priorityReputationTitle")
  end

  if currentMode == "events" then
    return "events", L("priorityEventsTitle")
  end

  if currentMode == "routes" then
    return "routes", L("priorityRoutesTitle")
  end

  if currentMode == "missingEasy" then
    return "missingEasy", L("missingEasyPriorityTitle")
  end

  return "today", L("priorityTodayTitle")
end

function PriorityScopeMatches(mount, scope)
  local source = GetMountSource(mount)

  if scope == "weekly" then
    return mount.reset == "weekly"
  end

  if scope == "reputation" then
    return SourceMatches(source, "Reputation")
  end

  if scope == "events" then
    return mount.reset == "event" or SourceMatches(source, "Event")
  end

  if scope == "routes" then
    return HasFarmRoute(mount)
  end

  if scope == "missingEasy" then
    return IsEasyMissingMount(mount)
  end

  return ShouldShowMount(mount, "today")
end

function GetPriorityTimeEstimate(mount)
  local explicitTime = mount.priorityTime or mount.timeEstimate or mount.estimatedTime

  if type(explicitTime) == "number" then
    return L("priorityMinutes", explicitTime)
  end

  if explicitTime and explicitTime ~= "" then
    return tostring(LocalizeDataValue(explicitTime))
  end

  local source = Normalize(GetMountSource(mount))
  local reset = Normalize(mount.reset)

  if source == "rare" then
    return L("priorityMinutes", reset == "repeatable" and 4 or 5)
  end

  if source == "daily quest" or source == "world quest" then
    return L("priorityMinutes", 8)
  end

  if source == "event" then
    return L("priorityMinutes", 10)
  end

  if source == "dungeon" then
    return L("priorityMinutes", 12)
  end

  if source == "raid" or source == "world boss" then
    return L("priorityMinutes", 15)
  end

  if source == "reputation" then
    return L("priorityMinutes", 15)
  end

  if source == "vendor" then
    return L("priorityMinutes", 5)
  end

  if source == "achievement" or source == "secret" or source == "quest" then
    return L("priorityMinutes", 20)
  end

  return L("priorityMinutes", 10)
end

function GetPriorityReason(mount)
  local customReason = mount.priorityNote or mount.priorityReason

  if customReason and customReason ~= "" then
    return tostring(LocalizeDataValue(customReason))
  end

  local source = GetMountSource(mount)
  local cleanSource = Normalize(source)
  local zone = LocalizeDataValue(mount.zone)
  local eventName = GetMountEventName(mount)
  local requirement = LocalizeDataValue(mount.requirement)
  local priorityGain = mount.priorityGain or mount.repGain or mount.reputationGain
  local dropChance = GetMountDropChance(mount)

  if eventName then
    return L("priorityEventReason", eventName)
  end

  if cleanSource == "reputation" then
    if priorityGain then
      return L("priorityGainReason", tostring(LocalizeDataValue(priorityGain)))
    end

    if requirement and requirement ~= "" then
      return requirement
    end

    return GetSourceDisplayName(source)
  end

  if cleanSource == "rare" and zone and zone ~= "" then
    return L("priorityRareReason", zone)
  end

  if dropChance then
    return L("dropChanceLabel") .. ": " .. dropChance
  end

  if requirement and requirement ~= "" then
    return requirement
  end

  if zone and zone ~= "" then
    return GetSourceDisplayName(source) .. " | " .. zone
  end

  return GetSourceDisplayName(source)
end

function GetPriorityScore(mount, scope)
  local score = 0
  local source = Normalize(GetMountSource(mount))
  local expansion = Normalize(GetMountExpansion(mount))

  if IsFavoriteMount(mount) then
    score = score + 180
  end

  if mount.reset == "event" then
    score = score + 140
  elseif mount.reset == "daily" then
    score = score + 125
  elseif mount.reset == "repeatable" then
    score = score + 110
  elseif mount.reset == "weekly" then
    score = score + (scope == "weekly" and 130 or 35)
  elseif mount.reset == "special" then
    score = score + 70
  end

  if source == "rare" then
    score = score + 60
  elseif source == "daily quest" or source == "world quest" then
    score = score + 36
  elseif source == "reputation" then
    score = score + 34
  elseif source == "event" then
    score = score + 30
  elseif source == "dungeon" then
    score = score + 22
  elseif source == "raid" then
    score = score + 18
  elseif source == "vendor" then
    score = score - 12
  end

  if HasFarmRoute(mount) then
    score = score + 26
  end

  if GetMountDropChance(mount) then
    score = score + 10
  end

  if expansion == "the war within" then
    score = score + 22
  elseif expansion == "dragonflight" then
    score = score + 10
  end

  return score
end

function BuildSmartPriorityPlan()
  local scope, title = GetSmartPriorityScope()
  local cacheKey = scope .. "\001" .. tostring(AzerColectRuntime.cacheRevision)

  if AzerColectRuntime.priorityPlanCacheKey == cacheKey and AzerColectRuntime.priorityPlanCache then
    return AzerColectRuntime.priorityPlanCache
  end

  local candidates = {}

  for _, mount in ipairs(AzerColectMounts or {}) do
    if IsExpansionEnabled(GetMountExpansion(mount))
      and IsEventMountAvailable(mount)
      and not IsMountUnavailable(mount)
      and not HasMount(mount)
      and not IsAttempted(mount)
      and PriorityScopeMatches(mount, scope) then
      local score = GetPriorityScore(mount, scope)
      local time = GetPriorityTimeEstimate(mount)
      local reason = GetPriorityReason(mount)

      if scope == "missingEasy" then
        score = 1000 - GetEasyMountScore(mount)
        time = GetEasyMountActionText(mount) or time
        reason = GetSourceDisplayName(GetMountSource(mount))
      end

      table.insert(candidates, {
        mount = mount,
        score = score,
        time = time,
        reason = reason
      })
    end
  end

  table.sort(candidates, function(a, b)
    if a.score == b.score then
      return GetMountDisplayName(a.mount) < GetMountDisplayName(b.mount)
    end

    return a.score > b.score
  end)

  local recommendations = {}

  for index = 1, math.min(PRIORITY_RECOMMENDATION_COUNT, #candidates) do
    table.insert(recommendations, candidates[index])
  end

  AzerColectRuntime.priorityPlanCacheKey = cacheKey
  AzerColectRuntime.priorityPlanCache = {
    title = title,
    scope = scope,
    total = #candidates,
    recommendations = recommendations
  }

  return AzerColectRuntime.priorityPlanCache
end

function SetPriorityRowHover(row, isHovered)
  if not row then
    return
  end

  if row.background then
    if isHovered then
      row.background:SetColorTexture(0.12, 0.08, 0.025, 0.72)
    else
      row.background:SetColorTexture(0.015, 0.022, 0.044, 0.46)
    end
  end

  if row.leftLine then
    if isHovered then
      row.leftLine:SetColorTexture(1, 0.68, 0.12, 0.9)
    else
      row.leftLine:SetColorTexture(0.12, 0.54, 1, 0.44)
    end
  end
end

function GetPriorityFocusMode(mount)
  if currentMode == "missingEasy" then
    return "missingEasy"
  end

  if IsEventMount(mount) then
    return "events"
  end

  if SourceMatches(GetMountSource(mount), "Reputation") then
    return "reputation"
  end

  if mount.reset == "weekly" then
    return "weekly"
  end

  if ShouldShowMount(mount, "today") then
    return "today"
  end

  if HasFarmRoute(mount) then
    return "routes"
  end

  return "all"
end

function FocusPriorityMount(mount)
  if not mount then
    return
  end

  currentMode = GetPriorityFocusMode(mount)
  currentExpansionFilter = "all"
  currentSourceFilter = "all"
  currentCollectionFilter = "missing"
  currentSearchText = GetMountDisplayName(mount)
  ApplyModeDefaults(currentMode)
  ResetListScroll()

  if mainFrame and mainFrame.searchBox then
    mainFrame.searchBox:SetText(currentSearchText)
    mainFrame.searchBox:ClearFocus()
  end

  RefreshWindow()
  ShowMountPreview(mount)
end

function UpdateSmartPriorityPanel()
  if not mainFrame or not mainFrame.priorityPlanTitle then
    return
  end

  local plan = BuildSmartPriorityPlan()
  local recommendations = plan.recommendations or {}

  mainFrame.priorityPlanTitle:SetText(plan.title)

  for index = 1, PRIORITY_RECOMMENDATION_COUNT do
    local row = mainFrame.priorityRows and mainFrame.priorityRows[index]
    local recommendation = recommendations[index]

    if row and recommendation then
      local mountName = ShortenText(GetMountDisplayName(recommendation.mount), 22)

      row.mount = recommendation.mount
      row.name:SetText(index .. ". " .. mountName .. " (" .. recommendation.time .. ")")
      row.reason:SetText(ShortenText(recommendation.reason, 30))
      SetPriorityRowHover(row, false)
      row:SetScript("OnEnter", function(self)
        SetPriorityRowHover(self, true)

        if GameTooltip and self.mount then
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:AddLine(GetMountDisplayName(self.mount), 1, 0.9, 0.25)
          GameTooltip:AddLine(L("prioritySelectHint"), 0.82, 0.88, 1)
          GameTooltip:Show()
        end
      end)
      row:SetScript("OnLeave", function(self)
        SetPriorityRowHover(self, false)

        if GameTooltip then
          GameTooltip:Hide()
        end
      end)
      row:SetScript("OnMouseDown", function(self)
        if GameTooltip then
          GameTooltip:Hide()
        end

        FocusPriorityMount(self.mount)
      end)
      row:Show()
    elseif row then
      row.mount = nil
      row:SetScript("OnEnter", nil)
      row:SetScript("OnLeave", nil)
      row:SetScript("OnMouseDown", nil)
      row:Hide()
    end
  end

  if mainFrame.priorityPotential then
    if #recommendations > 0 then
      local totalMinutes = 0

      for _, recommendation in ipairs(recommendations) do
        local minutes = tonumber(tostring(recommendation.time or ""):match("(%d+)"))

        if minutes then
          totalMinutes = totalMinutes + minutes
        end
      end

      if totalMinutes > 0 then
        mainFrame.priorityPotential:SetText(L("priorityPotentialDetailed", #recommendations, totalMinutes))
      else
        mainFrame.priorityPotential:SetText(L("priorityPotential", #recommendations))
      end
    else
      mainFrame.priorityPotential:SetText(L("priorityNoItems"))
    end
  end
end

function PrintSummary()
  local todayPending, todayAttempted = CountMountsForMode("today")
  local weeklyPending, weeklyAttempted = CountMountsForMode("weekly")
  local achievementItems = BuildAchievementItems()

  Print(L("summaryToday", todayPending, todayAttempted))
  Print(L("summaryWeekly", weeklyPending, weeklyAttempted))
  Print(GetWeeklyResetText())
  Print(L("summaryAchievements", #achievementItems))
end

function PlayNewMountAlertSound()
  if not AzerColectDB or not AzerColectDB.newMountAlerts or AzerColectDB.newMountAlerts.sound == false then
    return
  end

  if PlaySound and SOUNDKIT then
    local sound = SOUNDKIT.UI_COLLECTIONS_TOAST
      or SOUNDKIT.UI_IG_STORE_PURCHASE_DELIVERED_TOAST_01
      or SOUNDKIT.ACHIEVEMENT_MENU_OPEN

    if sound then
      SafeCall(PlaySound, sound, "Master")
      return
    end
  end

  if PlaySoundFile then
    SafeCall(PlaySoundFile, "Sound\\Interface\\RaidWarning.ogg", "Master")
  end
end

function CreateNewMountAlertFrame()
  if AzerColectRuntime.newMountAlertFrame then
    return AzerColectRuntime.newMountAlertFrame
  end

  local frame = CreateFrame("Frame", "AzerColectNewMountAlertFrame", UIParent)
  frame:SetSize(470, 178)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -142)
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(80)
  frame:EnableMouse(false)
  frame:Hide()
  DecoratePanel(frame, { 0.01, 0.014, 0.03 }, UI_THEME.gold, 0.96, 0.85)

  frame.glow = frame:CreateTexture(nil, "BACKGROUND")
  frame.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
  frame.glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
  frame.glow:SetColorTexture(0.08, 0.45, 1, 0.16)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetSize(76, 76)
  frame.icon:SetPoint("LEFT", frame, "LEFT", 24, 2)
  frame.icon:SetTexture(DEFAULT_MOUNT_ICON)
  frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  frame.iconBorder = frame:CreateTexture(nil, "BORDER")
  frame.iconBorder:SetPoint("TOPLEFT", frame.icon, "TOPLEFT", -3, 3)
  frame.iconBorder:SetPoint("BOTTOMRIGHT", frame.icon, "BOTTOMRIGHT", 3, -3)
  frame.iconBorder:SetColorTexture(1, 0.68, 0.12, 0.46)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 118, -22)
  frame.title:SetWidth(320)
  frame.title:SetJustifyH("LEFT")
  StyleFont(frame.title, 18, 1, 0.78, 0.18, "OUTLINE")

  frame.mountName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  frame.mountName:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -8)
  frame.mountName:SetWidth(320)
  frame.mountName:SetJustifyH("LEFT")
  StyleFont(frame.mountName, 20, 1, 1, 1, "OUTLINE")

  frame.stats = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.stats:SetPoint("TOPLEFT", frame.mountName, "BOTTOMLEFT", 0, -12)
  frame.stats:SetWidth(330)
  frame.stats:SetJustifyH("LEFT")
  frame.stats:SetSpacing(3)
  StyleFont(frame.stats, 12, 0.82, 0.9, 1, "OUTLINE")

  frame.confetti = {}

  for index = 1, 22 do
    local particle = frame:CreateTexture(nil, "OVERLAY")

    particle:SetSize(7, 7)
    particle:SetColorTexture(1, 0.72, 0.18, 1)
    particle:Hide()
    particle.anim = particle:CreateAnimationGroup()
    particle.move = particle.anim:CreateAnimation("Translation")
    particle.move:SetDuration(1.35)
    particle.fade = particle.anim:CreateAnimation("Alpha")
    particle.fade:SetFromAlpha(1)
    particle.fade:SetToAlpha(0)
    particle.fade:SetDuration(1.35)
    particle.anim:SetScript("OnFinished", function()
      particle:Hide()
    end)

    frame.confetti[index] = particle
  end

  AzerColectRuntime.newMountAlertFrame = frame

  return frame
end

function PlayNewMountConfetti(frame)
  if not frame or not frame.confetti or not AzerColectDB or not AzerColectDB.newMountAlerts or AzerColectDB.newMountAlerts.confetti == false then
    return
  end

  local colors = {
    { 1, 0.72, 0.16 },
    { 0.18, 0.78, 1 },
    { 0.34, 1, 0.44 },
    { 0.78, 0.3, 1 },
    { 1, 0.25, 0.34 }
  }

  for index, particle in ipairs(frame.confetti) do
    local color = colors[((index - 1) % #colors) + 1]
    local startX = math.random(-210, 210)
    local startY = math.random(-8, 24)
    local offsetX = math.random(-48, 48)
    local offsetY = -math.random(72, 132)

    particle.anim:Stop()
    particle:ClearAllPoints()
    particle:SetPoint("TOP", frame, "TOP", startX, startY)
    particle:SetColorTexture(color[1], color[2], color[3], 1)
    particle:SetAlpha(1)
    particle.move:SetOffset(offsetX, offsetY)
    particle:Show()
    particle.anim:Play()
  end
end

function ShowNextNewMountAlert()
  local queue = AzerColectRuntime.newMountAlertQueue

  if not queue or #queue == 0 then
    return
  end

  local frame = CreateNewMountAlertFrame()

  if frame:IsShown() then
    return
  end

  local alert = table.remove(queue, 1)
  local mountID = alert.mountID
  local mountName = alert.name or L("previewMount")
  local stats = GetNewMountAlertStats(mountID, mountName)

  frame.icon:SetTexture(GetMountIcon({
    name = mountName,
    mountID = mountID
  }))
  frame.title:SetText(L("newMountTitle"))
  frame.mountName:SetText(mountName)
  frame.stats:SetText(
    L("newMountAttempts", stats.attempts) .. "\n"
    .. L("newMountTimeInvested", stats.timeText) .. "\n"
    .. L("newMountCollectionTotal", stats.collectionText)
  )
  frame:SetAlpha(1)
  frame:Show()

  PlayNewMountAlertSound()
  PlayNewMountConfetti(frame)

  AzerColectRuntime.newMountAlertToken = (AzerColectRuntime.newMountAlertToken or 0) + 1
  local token = AzerColectRuntime.newMountAlertToken

  if C_Timer and C_Timer.After then
    C_Timer.After(NEW_MOUNT_ALERT_DURATION, function()
      if AzerColectRuntime.newMountAlertToken ~= token then
        return
      end

      frame:Hide()
      ShowNextNewMountAlert()
    end)
  end
end

function QueueNewMountAlert(mountID, mountName)
  EnsureDB()

  if AzerColectDB.newMountAlerts.enabled == false then
    return
  end

  AzerColectRuntime.newMountAlertQueue = AzerColectRuntime.newMountAlertQueue or {}

  table.insert(AzerColectRuntime.newMountAlertQueue, {
    mountID = mountID,
    name = mountName
  })

  ShowNextNewMountAlert()
end

function SetButtonSelected(button, isSelected)
  local color = button and button.azerColor or UI_THEME.gold

  if isSelected then
    SafeCall(button.LockHighlight, button)
    button:Disable()
    StyleFont(button:GetFontString(), 10, 1, 0.95, 0.45, "OUTLINE")

    if button.azerBackground then
      SetTextureColor(button.azerBackground, color, 0.42)
    end

    if button.azerTopLine then
      SetTextureColor(button.azerTopLine, color, 0.82)
    end

    if button.azerBottomLine then
      SetTextureColor(button.azerBottomLine, color, 0.45)
    end

    if button.azerGlow then
      button.azerGlow:Show()
    end
  else
    SafeCall(button.UnlockHighlight, button)
    button:Enable()
    StyleFont(button:GetFontString(), 10, 0.72, 0.78, 0.88, "OUTLINE")

    if button.azerBackground then
      SetTextureColor(button.azerBackground, UI_THEME.neutral, 0.52)
    end

    if button.azerTopLine then
      SetTextureColor(button.azerTopLine, color, 0.24)
    end

    if button.azerBottomLine then
      SetTextureColor(button.azerBottomLine, UI_THEME.neutral, 0.42)
    end

    if button.azerGlow then
      button.azerGlow:Hide()
    end
  end
end

function ShowAllMountsForExpansion()
  if currentMode ~= "achievements"
    and currentMode ~= "favorites"
    and currentMode ~= "missingEasy"
    and currentMode ~= "sources"
    and currentMode ~= "reputation"
    and currentMode ~= "events"
    and currentMode ~= "routes" then
    currentMode = "all"
  end

  if currentMode ~= "sources"
    and currentMode ~= "missingEasy"
    and currentMode ~= "reputation"
    and currentMode ~= "events"
    and currentMode ~= "routes" then
    currentSourceFilter = "all"
  end

  ResetListScroll()
  RefreshWindow()
end

function ShowAllMountsForSource()
  if currentMode ~= "achievements"
    and currentMode ~= "favorites"
    and currentMode ~= "missingEasy"
    and currentMode ~= "sources"
    and currentMode ~= "reputation"
    and currentMode ~= "events"
    and currentMode ~= "routes" then
    currentMode = "all"
  end

  ResetListScroll()
  RefreshWindow()
end

ApplyModeDefaults = function(mode)
  if mode == "sources" and currentSourceFilter == "all" then
    currentSourceFilter = "Vendor"
  end

  if mode == "reputation" then
    currentSourceFilter = "Reputation"
  end

  if mode == "events" then
    currentSourceFilter = "Event"
  end

  if mode == "routes" then
    currentSourceFilter = "all"
  end

  if mode == "missingEasy" then
    currentSourceFilter = "all"
    currentCollectionFilter = "missing"
  end
end

UpdateFilterButtons = function()
  if not mainFrame then
    return
  end

  mainFrame.expansionButton:SetText(L("filterExpansion") .. ": " .. GetOptionLabel(expansionFilterOptions, currentExpansionFilter))
  mainFrame.sourceButton:SetText((currentMode == "sources" and L("filterSource") or L("filterType"))
    .. ": " .. GetSourceDisplayName(currentSourceFilter))
  mainFrame.collectionButton:SetText(L("filterCollection") .. ": "
    .. GetOptionLabel(collectionFilterOptions, currentCollectionFilter))

  if mainFrame.filterToggleButton then
    mainFrame.filterToggleButton:SetText(filtersAdvancedOpen and L("buttonHideFilters") or L("buttonFilters"))
  end

  if mainFrame.searchLabel then
    mainFrame.searchLabel:ClearAllPoints()

    if filtersAdvancedOpen then
      mainFrame.sourceButton:Show()
      mainFrame.collectionButton:Show()
      mainFrame.clearFilterButton:Show()
      mainFrame.searchLabel:SetPoint("LEFT", mainFrame.clearFilterButton, "RIGHT", 10, 0)

      if mainFrame.searchBox then
        mainFrame.searchBox:SetWidth(205)
      end
    else
      mainFrame.sourceButton:Hide()
      mainFrame.collectionButton:Hide()
      mainFrame.clearFilterButton:Hide()
      mainFrame.searchLabel:SetPoint("LEFT", mainFrame.filterToggleButton, "RIGHT", 10, 0)

      if mainFrame.searchBox then
        mainFrame.searchBox:SetWidth(310)
      end
    end
  end

  if currentMode == "reputation" or currentMode == "events" then
    mainFrame.sourceButton:Disable()
    StyleFont(mainFrame.sourceButton:GetFontString(), 10, 0.78, 0.76, 0.68, "OUTLINE")
  else
    mainFrame.sourceButton:Enable()
    StyleButton(mainFrame.sourceButton)
  end

  local defaultSourceFilter = "all"

  if currentMode == "sources" then
    defaultSourceFilter = "Vendor"
  elseif currentMode == "reputation" then
    defaultSourceFilter = "Reputation"
  elseif currentMode == "events" then
    defaultSourceFilter = "Event"
  end

  if currentExpansionFilter == "all"
    and currentSourceFilter == defaultSourceFilter
    and currentCollectionFilter == "missing"
    and SearchText() == "" then
    mainFrame.clearFilterButton:Disable()
  else
    mainFrame.clearFilterButton:Enable()
  end

  if mainFrame.clearSearchButton then
    if SearchText() == "" then
      mainFrame.clearSearchButton:Disable()
    else
      mainFrame.clearSearchButton:Enable()
    end
  end
end

function SetRowHover(row, isHovered)
  if not row or not row.background then
    return
  end

  if isHovered then
    row.background:SetColorTexture(0.13, 0.09, 0.035, 0.95)

    if row.glow then
      row.glow:Show()
    end

    if row.topLine then
      row.topLine:SetColorTexture(1, 0.67, 0.12, 0.85)
    end
  else
    row.background:SetColorTexture(row.baseR or 0.055, row.baseG or 0.058, row.baseB or 0.065, row.baseA or 0.88)

    if row.glow then
      row.glow:Hide()
    end

    if row.topLine then
      row.topLine:SetColorTexture(0.22, 0.36, 0.56, 0.48)
    end
  end
end

function GetMountDisplayID(mount)
  local journalID = GetMountJournalID(mount)

  if not journalID then
    return nil
  end

  local cachedDisplayID = AzerColectRuntime.mountDisplayIDCache and AzerColectRuntime.mountDisplayIDCache[journalID]

  if type(cachedDisplayID) == "number" and cachedDisplayID > 0 then
    return cachedDisplayID
  end

  local extra = GetJournalMountExtra(journalID)
  local displayID = extra and extra.displayID

  if type(displayID) == "number" and displayID > 0 then
    AzerColectRuntime.mountDisplayIDCache = AzerColectRuntime.mountDisplayIDCache or {}
    AzerColectRuntime.mountDisplayIDCache[journalID] = displayID
    return displayID
  end
end

function GetMountIcon(mount)
  local journalID = GetMountJournalID(mount)

  if journalID then
    local cachedIcon = AzerColectRuntime.mountIconCache and AzerColectRuntime.mountIconCache[journalID]

    if cachedIcon then
      return cachedIcon
    end

    local info = GetJournalMountInfo(journalID)

    if info and info.icon then
      return info.icon
    end
  end

  return DEFAULT_MOUNT_ICON
end

function AddTomTomWaypoint(mount)
  local command = GetMountTomTomCommand(mount)

  if not command or command == "" then
    Print(L("waypointUnavailable"))
    return
  end

  local tomtomCommand = command:gsub("^/way%s*", "")

  if SlashCmdList and SlashCmdList["TOMTOM_WAY"] then
    SafeCall(SlashCmdList["TOMTOM_WAY"], tomtomCommand)
    Print(L("waypointAdded", GetMountDisplayName(mount)))
    return
  end

  Print(L("waypointCommand", command))
end

function BuildDailyRouteSteps()
  local candidates = {}
  local skipAttempted = GetAzerColectOption("dailyRouteSkipAttempted")

  for _, mount in ipairs(AzerColectMounts or {}) do
    if IsExpansionEnabled(GetMountExpansion(mount))
      and IsEventMountAvailable(mount)
      and not IsMountUnavailable(mount)
      and not HasMount(mount)
      and (not skipAttempted or not IsAttempted(mount))
      and PriorityScopeMatches(mount, "today") then
      local hasWaypoint = GetMountTomTomCommand(mount) ~= nil
      local score = GetPriorityScore(mount, "today")

      if hasWaypoint then
        score = score + 15
      end

      table.insert(candidates, {
        mount = mount,
        score = score,
        hasWaypoint = hasWaypoint
      })
    end
  end

  table.sort(candidates, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end

    if a.hasWaypoint ~= b.hasWaypoint then
      return a.hasWaypoint
    end

    return GetMountDisplayName(a.mount) < GetMountDisplayName(b.mount)
  end)

  local steps = {}

  for index = 1, math.min(DAILY_ROUTE_LIMIT, #candidates) do
    table.insert(steps, candidates[index])
  end

  return steps
end

function UpdateDailyRoutePanel()
  if not mainFrame or not mainFrame.dailyRouteStatus then
    return
  end

  local route = AzerColectRuntime.dailyRoute
  local steps = route and route.steps or {}
  local index = route and route.index or 0
  local step = steps[index]

  if step and step.mount then
    mainFrame.dailyRouteStatus:SetText(L("dailyRouteStatus", index, #steps, ShortenText(GetMountDisplayName(step.mount), 18)))
    mainFrame.dailyRouteNextButton:Show()
    mainFrame.dailyRouteStopButton:Show()
    mainFrame.dailyRouteButton:SetText(L("dailyRouteRestart"))
    return
  end

  mainFrame.dailyRouteStatus:SetText(L("dailyRouteIdle"))
  mainFrame.dailyRouteNextButton:Hide()
  mainFrame.dailyRouteStopButton:Hide()
  mainFrame.dailyRouteButton:SetText(L("dailyRouteStart"))
end

function RunDailyRouteStep(index)
  local route = AzerColectRuntime.dailyRoute

  if not route or type(route.steps) ~= "table" then
    return
  end

  local step = route.steps[index]

  if not step or not step.mount then
    AzerColectRuntime.dailyRoute = nil
    Print(L("dailyRouteComplete"))
    UpdateDailyRoutePanel()
    return
  end

  route.index = index
  FocusPriorityMount(step.mount)

  if GetAzerColectOption("dailyRouteAutoWaypoint") then
    if GetMountTomTomCommand(step.mount) then
      AddTomTomWaypoint(step.mount)
    else
      Print(L("dailyRouteNoWaypoint", GetMountDisplayName(step.mount)))
    end
  end

  Print(L("dailyRouteStep", index, #route.steps, GetMountDisplayName(step.mount)))
  UpdateDailyRoutePanel()
end

function StartDailyRoute()
  local steps = BuildDailyRouteSteps()

  if #steps == 0 then
    AzerColectRuntime.dailyRoute = nil
    Print(L("dailyRouteNoSteps"))
    UpdateDailyRoutePanel()
    return
  end

  AzerColectRuntime.dailyRoute = {
    steps = steps,
    index = 1
  }

  RunDailyRouteStep(1)
end

function AdvanceDailyRoute()
  local route = AzerColectRuntime.dailyRoute

  if not route or type(route.steps) ~= "table" then
    StartDailyRoute()
    return
  end

  RunDailyRouteStep((route.index or 0) + 1)
end

function StopDailyRoute()
  AzerColectRuntime.dailyRoute = nil
  Print(L("dailyRouteStopped"))
  UpdateDailyRoutePanel()
end

ClearMountPreview = function(message)
  if not mainFrame or not mainFrame.previewPanel then
    return
  end

  mainFrame.previewName:SetText(L("previewMount"))
  mainFrame.previewDetails:SetText(message or L("previewClickToLoad"))

  if mainFrame.previewWaypointButton then
    mainFrame.previewWaypointButton.mount = nil
    mainFrame.previewWaypointButton:Hide()
  end

  if mainFrame.previewInfoTitle then
    mainFrame.previewInfoTitle:SetText(L("previewHowToGet"))
  end

  if mainFrame.previewModel then
    mainFrame.previewModel.displayActive = false
    SafeCall(mainFrame.previewModel.ClearModel, mainFrame.previewModel)
    mainFrame.previewModel:Hide()
  end

  if mainFrame.previewEmptyText then
    mainFrame.previewEmptyText:SetText(L("previewNoModel"))
    mainFrame.previewEmptyText:Show()
  end
end

ShowMountPreview = function(mount)
  if not mainFrame or not mainFrame.previewPanel or not mount then
    ClearMountPreview()
    return
  end

  local displayID = GetMountDisplayID(mount)
  local details = BuildMountPreviewDetails(mount)

  if not details or details == "" then
    details = L("previewEmpty")
  end

  mainFrame.previewName:SetText(GetMountDisplayName(mount))
  if mainFrame.previewInfoTitle then
    mainFrame.previewInfoTitle:SetText(L("previewFullGuide"))
  end

  if mainFrame.previewWaypointButton then
    mainFrame.previewWaypointButton.mount = mount

    if GetMountTomTomCommand(mount) then
      mainFrame.previewWaypointButton:Show()
    else
      mainFrame.previewWaypointButton:Hide()
    end
  end

  if displayID and mainFrame.previewModel then
    mainFrame.previewDetails:SetText(details)
    mainFrame.previewEmptyText:Hide()
    mainFrame.previewModel:Show()
    mainFrame.previewModel.displayActive = true
    mainFrame.previewModel.previewFacing = -0.35

    SafeCall(mainFrame.previewModel.ClearModel, mainFrame.previewModel)
    SafeCall(mainFrame.previewModel.SetDisplayInfo, mainFrame.previewModel, displayID)
    SafeCall(mainFrame.previewModel.SetCamDistanceScale, mainFrame.previewModel, 1.25)
    SafeCall(mainFrame.previewModel.SetPortraitZoom, mainFrame.previewModel, 0)
    SafeCall(mainFrame.previewModel.SetPosition, mainFrame.previewModel, 0, 0, 0)
    SafeCall(mainFrame.previewModel.SetFacing, mainFrame.previewModel, mainFrame.previewModel.previewFacing)
  else
    mainFrame.previewDetails:SetText(details .. "\n" .. L("previewNoJournalModel"))

    if mainFrame.previewModel then
      mainFrame.previewModel.displayActive = false
      SafeCall(mainFrame.previewModel.ClearModel, mainFrame.previewModel)
      mainFrame.previewModel:Hide()
    end

    mainFrame.previewEmptyText:SetText(L("previewNoModel"))
    mainFrame.previewEmptyText:Show()
  end
end

ExtractMountNameFromReward = function(text)
  if not text or text == "" then
    return nil
  end

  local name = text:match("[Mm]ount:%s*([^,]+)")
    or text:match("[Mm]ontura:%s*([^,]+)")

  if name then
    return Trim(name:gsub("%.$", ""))
  end
end

function GetAchievementPreviewMount(item)
  if not item then
    return nil
  end

  local mountName = ExtractMountNameFromReward(item.configuredReward)
    or ExtractMountNameFromReward(item.reward)

  if not mountName and not item.mountID then
    return nil
  end

  return {
    name = mountName or LocalizeDataValue(item.reward) or "Mount",
    mountID = item.mountID,
    expansion = item.expansion,
    source = item.source or "Achievement",
    reset = "special",
    note = item.note
  }
end

function CreateStatCard(parent, key, x, color)
  local card = CreateFrame("Frame", nil, parent)

  color = color or UI_THEME.gold
  card:SetSize(176, 54)
  card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -82)
  DecoratePanel(card, UI_THEME.panel, color, 0.82, 0.34)

  card.icon = card:CreateTexture(nil, "ARTWORK")
  card.icon:SetSize(30, 30)
  card.icon:SetPoint("LEFT", card, "LEFT", 12, 0)
  card.icon:SetTexture(DEFAULT_MOUNT_ICON)
  card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  card.icon:SetVertexColor(color[1], color[2], color[3], 0.62)

  card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  card.label:SetPoint("TOPLEFT", card, "TOPLEFT", 52, -7)
  card.label:SetWidth(116)
  card.label:SetJustifyH("LEFT")
  card.label:SetText(L(key))
  StyleFont(card.label, 9, 0.72, 0.78, 0.88, "OUTLINE")

  card.value = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  card.value:SetPoint("TOPLEFT", card, "TOPLEFT", 52, -20)
  card.value:SetWidth(116)
  card.value:SetJustifyH("LEFT")
  card.value:SetText("0")
  StyleFont(card.value, 20, 1, 1, 1, "OUTLINE")

  card.sub = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  card.sub:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 52, 5)
  card.sub:SetWidth(116)
  card.sub:SetJustifyH("LEFT")
  card.sub:SetText("")
  StyleFont(card.sub, 9, 0.74, 0.78, 0.88, "OUTLINE")

  return card
end

function UpdateStatCard(card, value, subText)
  if not card then
    return
  end

  card.value:SetText(tostring(value or 0))
  card.sub:SetText(subText or "")
end

function CreateTabButton(parent, label, mode, x)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(92, 32)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -34)
  button:SetText(label)
  DecorateButton(button, MODE_COLORS[mode] or UI_THEME.gold, 0.2)
  button:SetScript("OnClick", function()
    SetMode(mode)
  end)

  return button
end

function CreateOptionsCheck(parent, yOffset, label, getter, setter)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")

  check:SetSize(24, 24)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, yOffset)
  check.getter = getter
  check.setter = setter

  check.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  check.label:SetPoint("LEFT", check, "RIGHT", 6, 0)
  check.label:SetWidth(388)
  check.label:SetJustifyH("LEFT")
  check.label:SetText(label)
  StyleFont(check.label, 11, 0.92, 0.95, 1, "OUTLINE")

  check:SetScript("OnClick", function(self)
    if self.setter then
      self.setter(self:GetChecked() == true)
    end

    RefreshOptionsPanel()
    RefreshWindow()
  end)

  return check
end

function CreateOptionsSection(parent, yOffset, label)
  local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, yOffset)
  heading:SetWidth(150)
  heading:SetJustifyH("LEFT")
  heading:SetText(label)
  StyleFont(heading, 10, 1, 0.82, 0.24, "OUTLINE")

  local line = parent:CreateTexture(nil, "BORDER")
  line:SetPoint("LEFT", heading, "RIGHT", 10, 0)
  line:SetPoint("RIGHT", parent, "RIGHT", -22, 0)
  line:SetHeight(1)
  line:SetColorTexture(0.95, 0.63, 0.12, 0.34)

  return heading
end

function CreateOptionsActionButton(parent, label, xOffset, yOffset, width, color, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 116, 24)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
  button:SetText(label)
  DecorateButton(button, color or UI_THEME.gold, 0.2)
  button:SetScript("OnClick", onClick)

  return button
end

function RefreshOptionsPanel()
  if not mainFrame or not mainFrame.optionsPanel or not mainFrame.optionsPanel.checks then
    return
  end

  for _, check in ipairs(mainFrame.optionsPanel.checks) do
    if check.getter then
      check:SetChecked(check.getter() == true)
    end
  end
end

function ToggleOptionsPanel()
  if not mainFrame then
    return
  end

  if not mainFrame.optionsPanel then
    CreateOptionsPanel(mainFrame)
  end

  if mainFrame.optionsPanel:IsShown() then
    mainFrame.optionsPanel:Hide()
  else
    RefreshOptionsPanel()
    UpdateDailyRoutePanel()
    mainFrame.optionsPanel:Show()
  end
end

function CreateOptionsPanel(parent)
  local panel = CreateFrame("Frame", nil, parent)

  panel:SetSize(460, 430)
  panel:SetPoint("CENTER", parent, "CENTER", 0, 0)
  panel:SetFrameLevel(parent:GetFrameLevel() + 30)
  panel:EnableMouse(true)
  DecoratePanel(panel, UI_THEME.panel, UI_THEME.purple, 0.96, 0.72)
  panel:Hide()

  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
  panel.title:SetText(L("optionsTitle"))
  StyleFont(panel.title, 18, 1, 0.84, 0.28, "OUTLINE")

  panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
  panel.subtitle:SetWidth(420)
  panel.subtitle:SetJustifyH("LEFT")
  panel.subtitle:SetText(L("optionsSubtitle"))
  StyleFont(panel.subtitle, 10, 0.74, 0.82, 0.95, "OUTLINE")

  CreateOptionsSection(panel, -72, L("optionsSectionCatalog"))
  CreateOptionsSection(panel, -130, L("optionsSectionAlerts"))
  CreateOptionsSection(panel, -238, L("optionsSectionDailyRoute"))

  panel.checks = {}

  table.insert(panel.checks, CreateOptionsCheck(panel, -94, L("optionShowInactiveEvents"), function()
    return GetAzerColectOption("showInactiveEvents")
  end, function(value)
    SetAzerColectOption("showInactiveEvents", value)
  end))

  table.insert(panel.checks, CreateOptionsCheck(panel, -152, L("optionNewMountAlerts"), function()
    EnsureDB()
    return AzerColectDB.newMountAlerts.enabled == true
  end, function(value)
    EnsureDB()
    AzerColectDB.newMountAlerts.enabled = value == true
  end))

  table.insert(panel.checks, CreateOptionsCheck(panel, -180, L("optionNewMountSound"), function()
    EnsureDB()
    return AzerColectDB.newMountAlerts.sound == true
  end, function(value)
    EnsureDB()
    AzerColectDB.newMountAlerts.sound = value == true
  end))

  table.insert(panel.checks, CreateOptionsCheck(panel, -208, L("optionNewMountConfetti"), function()
    EnsureDB()
    return AzerColectDB.newMountAlerts.confetti == true
  end, function(value)
    EnsureDB()
    AzerColectDB.newMountAlerts.confetti = value == true
  end))

  parent.dailyRouteButton = CreateOptionsActionButton(panel, L("dailyRouteStart"), 22, -260, 134, UI_THEME.blue, function()
    StartDailyRoute()
  end)

  parent.dailyRouteNextButton = CreateOptionsActionButton(panel, L("dailyRouteNext"), 164, -260, 90, UI_THEME.green, function()
    AdvanceDailyRoute()
  end)

  parent.dailyRouteStopButton = CreateOptionsActionButton(panel, L("dailyRouteStop"), 262, -260, 90, UI_THEME.red, function()
    StopDailyRoute()
  end)

  parent.dailyRouteStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  parent.dailyRouteStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -292)
  parent.dailyRouteStatus:SetWidth(416)
  parent.dailyRouteStatus:SetJustifyH("LEFT")
  parent.dailyRouteStatus:SetText(L("dailyRouteIdle"))
  SafeCall(parent.dailyRouteStatus.SetWordWrap, parent.dailyRouteStatus, false)
  StyleFont(parent.dailyRouteStatus, 10, 0.72, 0.82, 0.95, "OUTLINE")

  table.insert(panel.checks, CreateOptionsCheck(panel, -324, L("optionDailyRouteSkipAttempted"), function()
    return GetAzerColectOption("dailyRouteSkipAttempted")
  end, function(value)
    SetAzerColectOption("dailyRouteSkipAttempted", value)
    AzerColectRuntime.dailyRoute = nil
    UpdateDailyRoutePanel()
  end))

  table.insert(panel.checks, CreateOptionsCheck(panel, -352, L("optionDailyRouteAutoWaypoint"), function()
    return GetAzerColectOption("dailyRouteAutoWaypoint")
  end, function(value)
    SetAzerColectOption("dailyRouteAutoWaypoint", value)
  end))

  panel.closeButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  panel.closeButton:SetSize(112, 26)
  panel.closeButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -18, 16)
  panel.closeButton:SetText(L("buttonClose"))
  DecorateButton(panel.closeButton, UI_THEME.gold, 0.2)
  panel.closeButton:SetScript("OnClick", function()
    panel:Hide()
  end)

  parent.optionsPanel = panel
  RefreshOptionsPanel()
  UpdateDailyRoutePanel()

  return panel
end

function CreateWindow()
  if mainFrame then
    return
  end

  mainFrame = CreateFrame("Frame", "AzerColectFrame", UIParent, "BasicFrameTemplateWithInset")
  mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
  mainFrame:SetPoint("CENTER")
  mainFrame:SetMovable(true)
  mainFrame:EnableMouse(true)
  mainFrame:EnableMouseWheel(true)
  mainFrame:RegisterForDrag("LeftButton")
  mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
  mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
  mainFrame:SetScript("OnMouseWheel", function(_, delta)
    ScrollList(delta)
  end)
  mainFrame:Hide()

  mainFrame.windowBackground = mainFrame:CreateTexture(nil, "BACKGROUND")
  mainFrame.windowBackground:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 7, -7)
  mainFrame.windowBackground:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -7, 7)
  mainFrame.windowBackground:SetColorTexture(0.006, 0.01, 0.026, 0.96)

  mainFrame.bodyBackground = mainFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
  mainFrame.bodyBackground:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -72)
  mainFrame.bodyBackground:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
  mainFrame.bodyBackground:SetColorTexture(0.012, 0.016, 0.034, 0.92)

  mainFrame.outerTopLine = mainFrame:CreateTexture(nil, "BORDER")
  mainFrame.outerTopLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -6)
  mainFrame.outerTopLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -12, -6)
  mainFrame.outerTopLine:SetHeight(1)
  mainFrame.outerTopLine:SetColorTexture(1, 0.68, 0.18, 0.68)

  mainFrame.outerBottomLine = mainFrame:CreateTexture(nil, "BORDER")
  mainFrame.outerBottomLine:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 8)
  mainFrame.outerBottomLine:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -12, 8)
  mainFrame.outerBottomLine:SetHeight(1)
  mainFrame.outerBottomLine:SetColorTexture(0.1, 0.64, 1, 0.35)

  mainFrame.headerLine = mainFrame:CreateTexture(nil, "BORDER")
  mainFrame.headerLine:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -72)
  mainFrame.headerLine:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -18, -72)
  mainFrame.headerLine:SetHeight(1)
  mainFrame.headerLine:SetColorTexture(0.95, 0.63, 0.12, 0.45)

  mainFrame.logo = mainFrame:CreateTexture(nil, "ARTWORK")
  mainFrame.logo:SetSize(38, 38)
  mainFrame.logo:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -13)
  mainFrame.logo:SetTexture(MINIMAP_ICON_TEXTURE)
  mainFrame.logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  mainFrame.titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  mainFrame.titleText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 62, -11)
  mainFrame.titleText:SetText(ADDON_DISPLAY_NAME)
  StyleFont(mainFrame.titleText, 24, 1, 0.84, 0.28, "OUTLINE")

  mainFrame.subtitleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.subtitleText:SetPoint("TOPLEFT", mainFrame.titleText, "BOTTOMLEFT", 2, -1)
  mainFrame.subtitleText:SetText(L("addonSubtitle"))
  StyleFont(mainFrame.subtitleText, 11, 0.95, 0.95, 1, "OUTLINE")

  mainFrame.tabs = {
    today = CreateTabButton(mainFrame, L("modeToday"), "today", 226),
    weekly = CreateTabButton(mainFrame, L("modeWeekly"), "weekly", 322),
    all = CreateTabButton(mainFrame, L("modeAll"), "all", 418),
    favorites = CreateTabButton(mainFrame, L("modeFavorites"), "favorites", 514),
    achievements = CreateTabButton(mainFrame, L("modeAchievements"), "achievements", 610),
    sources = CreateTabButton(mainFrame, L("modeSources"), "sources", 706),
    reputation = CreateTabButton(mainFrame, L("modeReputation"), "reputation", 802),
    events = CreateTabButton(mainFrame, L("modeEvents"), "events", 898),
    routes = CreateTabButton(mainFrame, L("modeRoutes"), "routes", 994)
  }

  mainFrame.refreshButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.refreshButton:SetSize(86, 26)
  mainFrame.refreshButton:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -38, -37)
  mainFrame.refreshButton:SetText(L("buttonRefresh"))
  DecorateButton(mainFrame.refreshButton, UI_THEME.gold, 0.18)
  mainFrame.refreshButton:SetScript("OnClick", function()
    InvalidateMountJournalCaches()
    UpdateCurrentCharacterSnapshot(true)
    RefreshWindow()
  end)

  mainFrame.sidebar = CreateFrame("Frame", nil, mainFrame)
  mainFrame.sidebar:SetSize(SIDEBAR_WIDTH, 494)
  mainFrame.sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 18, -82)
  DecoratePanel(mainFrame.sidebar, UI_THEME.panel, UI_THEME.goldSoft, 0.9, 0.62)

  mainFrame.progressTitle = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame.progressTitle:SetPoint("TOP", mainFrame.sidebar, "TOP", 0, -12)
  mainFrame.progressTitle:SetWidth(SIDEBAR_WIDTH - 24)
  mainFrame.progressTitle:SetJustifyH("CENTER")
  mainFrame.progressTitle:SetText(L("progressTitle"))
  StyleFont(mainFrame.progressTitle, 11, 1, 0.84, 0.24, "OUTLINE")

  mainFrame.progressPercent = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  mainFrame.progressPercent:SetPoint("TOP", mainFrame.progressTitle, "BOTTOM", 0, -20)
  mainFrame.progressPercent:SetWidth(SIDEBAR_WIDTH - 24)
  mainFrame.progressPercent:SetJustifyH("CENTER")
  mainFrame.progressPercent:SetText("0%")
  StyleFont(mainFrame.progressPercent, 32, 1, 1, 1, "OUTLINE")

  mainFrame.progressBar = CreateFrame("StatusBar", nil, mainFrame.sidebar)
  mainFrame.progressBar:SetSize(SIDEBAR_WIDTH - 32, 14)
  mainFrame.progressBar:SetPoint("TOP", mainFrame.progressPercent, "BOTTOM", 0, -18)
  mainFrame.progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  mainFrame.progressBar:SetStatusBarColor(0.1, 0.9, 0.72, 0.95)
  mainFrame.progressBar:SetMinMaxValues(0, 100)
  mainFrame.progressBar:SetValue(0)
  DecoratePanel(mainFrame.progressBar, { 0.006, 0.012, 0.026 }, UI_THEME.cyan, 0.75, 0.48)

  mainFrame.progressDetails = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mainFrame.progressDetails:SetPoint("TOP", mainFrame.progressBar, "BOTTOM", 0, -10)
  mainFrame.progressDetails:SetWidth(SIDEBAR_WIDTH - 24)
  mainFrame.progressDetails:SetJustifyH("CENTER")
  mainFrame.progressDetails:SetText("0 / 0")
  StyleFont(mainFrame.progressDetails, 11, 0.82, 0.88, 1, "OUTLINE")

  mainFrame.expansionProgressDetails = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mainFrame.expansionProgressDetails:SetPoint("TOP", mainFrame.progressDetails, "BOTTOM", 0, -3)
  mainFrame.expansionProgressDetails:SetWidth(SIDEBAR_WIDTH - 24)
  mainFrame.expansionProgressDetails:SetJustifyH("CENTER")
  mainFrame.expansionProgressDetails:SetText(L("expansionProgressTooltipHint"))
  SafeCall(mainFrame.expansionProgressDetails.SetWordWrap, mainFrame.expansionProgressDetails, false)
  StyleFont(mainFrame.expansionProgressDetails, 10, 0.98, 0.84, 0.34, "OUTLINE")

  mainFrame.progressTooltipArea = CreateFrame("Frame", nil, mainFrame.sidebar)
  mainFrame.progressTooltipArea:SetPoint("TOPLEFT", mainFrame.progressTitle, "TOPLEFT", -6, 6)
  mainFrame.progressTooltipArea:SetPoint("BOTTOMRIGHT", mainFrame.expansionProgressDetails, "BOTTOMRIGHT", 6, -3)
  mainFrame.progressTooltipArea:EnableMouse(true)
  mainFrame.progressTooltipArea:SetScript("OnEnter", function(self)
    ShowExpansionProgressTooltip(self)
  end)
  mainFrame.progressTooltipArea:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  mainFrame.missingEasyButton = CreateFrame("Button", nil, mainFrame.sidebar, "UIPanelButtonTemplate")
  mainFrame.missingEasyButton:SetSize(SIDEBAR_WIDTH - 28, 34)
  mainFrame.missingEasyButton:SetPoint("TOP", mainFrame.expansionProgressDetails, "BOTTOM", 0, -12)
  mainFrame.missingEasyButton:SetText(L("missingEasyButton"))
  DecorateButton(mainFrame.missingEasyButton, UI_THEME.green, 0.22)
  mainFrame.missingEasyButton:SetScript("OnClick", function()
    SetMode("missingEasy")
  end)

  mainFrame.priorityLabel = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.priorityLabel:SetPoint("TOPLEFT", mainFrame.sidebar, "TOPLEFT", 14, -192)
  mainFrame.priorityLabel:SetText(L("priorityLabel"))
  StyleFont(mainFrame.priorityLabel, 10, 1, 0.82, 0.26, "OUTLINE")

  mainFrame.priorityMode = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  mainFrame.priorityMode:SetPoint("TOPLEFT", mainFrame.priorityLabel, "BOTTOMLEFT", 0, -8)
  mainFrame.priorityMode:SetWidth(SIDEBAR_WIDTH - 28)
  mainFrame.priorityMode:SetJustifyH("LEFT")
  mainFrame.priorityMode:SetText(modeLabels[currentMode] or L("modeToday"))
  StyleFont(mainFrame.priorityMode, 16, 1, 1, 1, "OUTLINE")

  mainFrame.priorityPlanTitle = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.priorityPlanTitle:SetPoint("TOPLEFT", mainFrame.priorityMode, "BOTTOMLEFT", 0, -14)
  mainFrame.priorityPlanTitle:SetWidth(SIDEBAR_WIDTH - 28)
  mainFrame.priorityPlanTitle:SetJustifyH("LEFT")
  mainFrame.priorityPlanTitle:SetText(L("priorityTodayTitle"))
  StyleFont(mainFrame.priorityPlanTitle, 10, 1, 0.82, 0.24, "OUTLINE")

  mainFrame.priorityRows = {}

  for index = 1, PRIORITY_RECOMMENDATION_COUNT do
    local priorityRow = CreateFrame("Frame", nil, mainFrame.sidebar)

    priorityRow:SetSize(SIDEBAR_WIDTH - 28, 38)
    priorityRow:EnableMouse(true)

    if index == 1 then
      priorityRow:SetPoint("TOPLEFT", mainFrame.priorityPlanTitle, "BOTTOMLEFT", 0, -8)
    else
      priorityRow:SetPoint("TOPLEFT", mainFrame.priorityRows[index - 1], "BOTTOMLEFT", 0, -5)
    end

    priorityRow.background = priorityRow:CreateTexture(nil, "BACKGROUND")
    priorityRow.background:SetAllPoints()
    priorityRow.background:SetColorTexture(0.015, 0.022, 0.044, 0.46)

    priorityRow.leftLine = priorityRow:CreateTexture(nil, "BORDER")
    priorityRow.leftLine:SetPoint("TOPLEFT", priorityRow, "TOPLEFT", 0, -1)
    priorityRow.leftLine:SetPoint("BOTTOMLEFT", priorityRow, "BOTTOMLEFT", 0, 1)
    priorityRow.leftLine:SetWidth(2)
    priorityRow.leftLine:SetColorTexture(0.12, 0.54, 1, 0.44)

    priorityRow.name = priorityRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    priorityRow.name:SetPoint("TOPLEFT", priorityRow, "TOPLEFT", 5, -3)
    priorityRow.name:SetWidth(SIDEBAR_WIDTH - 34)
    priorityRow.name:SetJustifyH("LEFT")
    SafeCall(priorityRow.name.SetWordWrap, priorityRow.name, false)
    StyleFont(priorityRow.name, 10, 0.95, 0.95, 1, "OUTLINE")

    priorityRow.reason = priorityRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    priorityRow.reason:SetPoint("TOPLEFT", priorityRow.name, "BOTTOMLEFT", 0, -2)
    priorityRow.reason:SetWidth(SIDEBAR_WIDTH - 34)
    priorityRow.reason:SetJustifyH("LEFT")
    SafeCall(priorityRow.reason.SetWordWrap, priorityRow.reason, false)
    StyleFont(priorityRow.reason, 9, 0.66, 0.74, 0.86, "OUTLINE")

    mainFrame.priorityRows[index] = priorityRow
  end

  mainFrame.priorityPotential = mainFrame.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.priorityPotential:SetPoint("TOPLEFT", mainFrame.priorityRows[PRIORITY_RECOMMENDATION_COUNT], "BOTTOMLEFT", 0, -9)
  mainFrame.priorityPotential:SetWidth(SIDEBAR_WIDTH - 28)
  mainFrame.priorityPotential:SetJustifyH("LEFT")
  mainFrame.priorityPotential:SetText(L("priorityNoItems"))
  StyleFont(mainFrame.priorityPotential, 10, 0.26, 0.95, 0.56, "OUTLINE")

  mainFrame.statCards = {
    total = CreateStatCard(mainFrame, "statTotalMounts", CONTENT_LEFT, UI_THEME.blue),
    collected = CreateStatCard(mainFrame, "statCollected", CONTENT_LEFT + 188, UI_THEME.green),
    missing = CreateStatCard(mainFrame, "statMissing", CONTENT_LEFT + 376, UI_THEME.red),
    attempted = CreateStatCard(mainFrame, "statAttempted", CONTENT_LEFT + 564, UI_THEME.cyan),
    favorites = CreateStatCard(mainFrame, "statFavorites", CONTENT_LEFT + 752, UI_THEME.gold)
  }

  mainFrame.summaryText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame.summaryText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_LEFT, -138)
  mainFrame.summaryText:SetWidth(FRAME_WIDTH - CONTENT_LEFT - 30)
  mainFrame.summaryText:SetJustifyH("LEFT")
  StyleFont(mainFrame.summaryText, 10, 0.83, 0.88, 1, "OUTLINE")

  mainFrame.filterBar = CreateFrame("Frame", nil, mainFrame)
  mainFrame.filterBar:SetSize(FRAME_WIDTH - CONTENT_LEFT - 18, 34)
  mainFrame.filterBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_LEFT - 6, -151)
  DecoratePanel(mainFrame.filterBar, { 0.018, 0.018, 0.032 }, UI_THEME.goldSoft, 0.78, 0.42)

  mainFrame.expansionPrevButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.expansionPrevButton:SetSize(28, 24)
  mainFrame.expansionPrevButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_LEFT, -156)
  mainFrame.expansionPrevButton:SetText("<")
  DecorateButton(mainFrame.expansionPrevButton, UI_THEME.gold, 0.18)
  mainFrame.expansionPrevButton:SetScript("OnClick", function()
    currentExpansionFilter = PreviousOption(expansionFilterOptions, currentExpansionFilter)
    ShowAllMountsForExpansion()
  end)

  mainFrame.expansionButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.expansionButton:SetSize(172, 24)
  mainFrame.expansionButton:SetPoint("LEFT", mainFrame.expansionPrevButton, "RIGHT", 4, 0)
  DecorateButton(mainFrame.expansionButton, UI_THEME.gold, 0.18)
  mainFrame.expansionButton:SetScript("OnClick", function()
    currentExpansionFilter = CycleOption(expansionFilterOptions, currentExpansionFilter)
    ShowAllMountsForExpansion()
  end)

  mainFrame.expansionNextButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.expansionNextButton:SetSize(28, 24)
  mainFrame.expansionNextButton:SetPoint("LEFT", mainFrame.expansionButton, "RIGHT", 4, 0)
  mainFrame.expansionNextButton:SetText(">")
  DecorateButton(mainFrame.expansionNextButton, UI_THEME.gold, 0.18)
  mainFrame.expansionNextButton:SetScript("OnClick", function()
    currentExpansionFilter = CycleOption(expansionFilterOptions, currentExpansionFilter)
    ShowAllMountsForExpansion()
  end)

  mainFrame.filterToggleButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.filterToggleButton:SetSize(86, 24)
  mainFrame.filterToggleButton:SetPoint("LEFT", mainFrame.expansionNextButton, "RIGHT", 8, 0)
  DecorateButton(mainFrame.filterToggleButton, UI_THEME.blue, 0.18)
  mainFrame.filterToggleButton:SetScript("OnClick", function()
    filtersAdvancedOpen = not filtersAdvancedOpen
    UpdateFilterButtons()
  end)

  mainFrame.sourceButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.sourceButton:SetSize(118, 24)
  mainFrame.sourceButton:SetPoint("LEFT", mainFrame.filterToggleButton, "RIGHT", 8, 0)
  DecorateButton(mainFrame.sourceButton, UI_THEME.green, 0.18)
  mainFrame.sourceButton:SetScript("OnClick", function()
    local options = currentMode == "sources" and sourceModeOptions or sourceFilterOptions

    currentSourceFilter = CycleOption(options, currentSourceFilter)
    ShowAllMountsForSource()
  end)

  mainFrame.collectionButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.collectionButton:SetSize(118, 24)
  mainFrame.collectionButton:SetPoint("LEFT", mainFrame.sourceButton, "RIGHT", 8, 0)
  DecorateButton(mainFrame.collectionButton, UI_THEME.purple, 0.18)
  mainFrame.collectionButton:SetScript("OnClick", function()
    currentCollectionFilter = CycleOption(collectionFilterOptions, currentCollectionFilter)

    ResetListScroll()
    RefreshWindow()
  end)

  mainFrame.clearFilterButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.clearFilterButton:SetSize(64, 24)
  mainFrame.clearFilterButton:SetPoint("LEFT", mainFrame.collectionButton, "RIGHT", 8, 0)
  mainFrame.clearFilterButton:SetText(L("buttonClearFilters"))
  DecorateButton(mainFrame.clearFilterButton, UI_THEME.orange, 0.18)
  mainFrame.clearFilterButton:SetScript("OnClick", function()
    currentExpansionFilter = "all"
    currentSourceFilter = "all"
    currentCollectionFilter = "missing"
    currentSearchText = ""
    ApplyModeDefaults(currentMode)

    if mainFrame.searchBox then
      mainFrame.searchBox:SetText("")
      mainFrame.searchBox:ClearFocus()
    end

    ShowAllMountsForSource()
  end)

  mainFrame.searchLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.searchLabel:SetPoint("LEFT", mainFrame.filterToggleButton, "RIGHT", 10, 0)
  mainFrame.searchLabel:SetText(L("searchLabel"))
  StyleFont(mainFrame.searchLabel, 10, 0.9, 0.94, 1, "OUTLINE")

  mainFrame.searchBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
  mainFrame.searchBox:SetSize(205, 24)
  mainFrame.searchBox:SetPoint("LEFT", mainFrame.searchLabel, "RIGHT", 8, 0)
  mainFrame.searchBox:SetAutoFocus(false)
  mainFrame.searchBox:SetText(currentSearchText)
  StyleFont(mainFrame.searchBox, 11, 1, 1, 1)
  mainFrame.searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  mainFrame.searchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  mainFrame.searchBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then
      return
    end

    currentSearchText = Trim(self:GetText())
    ResetListScroll()
    QueueRefreshWindow(AzerColectRuntime.SEARCH_REFRESH_DELAY)
  end)

  mainFrame.clearSearchButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.clearSearchButton:SetSize(28, 24)
  mainFrame.clearSearchButton:SetPoint("LEFT", mainFrame.searchBox, "RIGHT", 6, 0)
  mainFrame.clearSearchButton:SetText("X")
  DecorateButton(mainFrame.clearSearchButton, UI_THEME.red, 0.18)
  mainFrame.clearSearchButton:SetScript("OnClick", function()
    currentSearchText = ""

    if mainFrame.searchBox then
      mainFrame.searchBox:SetText("")
      mainFrame.searchBox:ClearFocus()
    end

    ResetListScroll()
    RefreshWindow()
  end)

  mainFrame.emptyText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  mainFrame.emptyText:SetPoint("CENTER", mainFrame, "CENTER", -84, -86)
  mainFrame.emptyText:SetWidth(ROW_WIDTH - 30)
  mainFrame.emptyText:SetJustifyH("CENTER")
  StyleFont(mainFrame.emptyText, 13, 0.95, 0.9, 0.78, "OUTLINE")
  mainFrame.emptyText:Hide()

  mainFrame.listPanel = CreateFrame("Frame", nil, mainFrame)
  mainFrame.listPanel:SetSize(ROW_WIDTH + 10, (ROW_COUNT * ROW_HEIGHT) + ((ROW_COUNT - 1) * ROW_GAP) + 16)
  mainFrame.listPanel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_LEFT - 6, LIST_TOP + 8)
  mainFrame.listPanel:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
  mainFrame.listPanel:EnableMouse(false)
  DecoratePanel(mainFrame.listPanel, { 0.009, 0.013, 0.028 }, UI_THEME.goldSoft, 0.72, 0.38)

  mainFrame.scrollTrack = mainFrame.listPanel:CreateTexture(nil, "BORDER")
  mainFrame.scrollTrack:SetPoint("TOPRIGHT", mainFrame.listPanel, "TOPRIGHT", -3, -8)
  mainFrame.scrollTrack:SetPoint("BOTTOMRIGHT", mainFrame.listPanel, "BOTTOMRIGHT", -3, 8)
  mainFrame.scrollTrack:SetWidth(3)
  mainFrame.scrollTrack:SetColorTexture(0.1, 0.18, 0.26, 0.75)

  mainFrame.scrollThumb = mainFrame.listPanel:CreateTexture(nil, "OVERLAY")
  mainFrame.scrollThumb:SetWidth(5)
  mainFrame.scrollThumb:SetColorTexture(1, 0.66, 0.1, 0.95)

  mainFrame.previewPanel = CreateFrame("Frame", nil, mainFrame)
  mainFrame.previewPanel:SetSize(PREVIEW_WIDTH, PREVIEW_HEIGHT)
  mainFrame.previewPanel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -18, LIST_TOP)
  mainFrame.previewPanel:EnableMouse(true)
  mainFrame.previewPanel:EnableMouseWheel(true)
  mainFrame.previewPanel:SetScript("OnMouseWheel", function(_, delta)
    ScrollList(delta)
  end)
  DecoratePanel(mainFrame.previewPanel, UI_THEME.panel, UI_THEME.goldSoft, 0.92, 0.62)

  mainFrame.previewTitle = mainFrame.previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame.previewTitle:SetPoint("TOPLEFT", mainFrame.previewPanel, "TOPLEFT", 12, -10)
  mainFrame.previewTitle:SetText(L("previewTitle"))
  StyleFont(mainFrame.previewTitle, 11, 1, 0.82, 0.24, "OUTLINE")

  mainFrame.previewName = mainFrame.previewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  mainFrame.previewName:SetPoint("TOPLEFT", mainFrame.previewPanel, "TOPLEFT", 12, -34)
  mainFrame.previewName:SetWidth(PREVIEW_WIDTH - 24)
  mainFrame.previewName:SetJustifyH("LEFT")
  StyleFont(mainFrame.previewName, 16, 1, 1, 1, "OUTLINE")

  mainFrame.previewModelFrame = CreateFrame("Frame", nil, mainFrame.previewPanel)
  mainFrame.previewModelFrame:SetSize(PREVIEW_WIDTH - 24, 118)
  mainFrame.previewModelFrame:SetPoint("TOPLEFT", mainFrame.previewPanel, "TOPLEFT", 12, -62)
  DecoratePanel(mainFrame.previewModelFrame, { 0.004, 0.008, 0.02 }, UI_THEME.blue, 0.94, 0.44)

  local modelReady, previewModel = pcall(CreateFrame, "PlayerModel", nil, mainFrame.previewModelFrame)

  if modelReady and previewModel then
    mainFrame.previewModel = previewModel
    mainFrame.previewModel:SetAllPoints(mainFrame.previewModelFrame)
    mainFrame.previewModel:SetScript("OnUpdate", function(self, elapsed)
      if self.displayActive then
        self.previewFacing = (self.previewFacing or 0) + (elapsed * 0.22)
        SafeCall(self.SetFacing, self, self.previewFacing)
      end
    end)
  end

  mainFrame.previewEmptyText = mainFrame.previewModelFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  mainFrame.previewEmptyText:SetPoint("CENTER", mainFrame.previewModelFrame, "CENTER", 0, 0)
  mainFrame.previewEmptyText:SetText(L("previewNoModel"))
  StyleFont(mainFrame.previewEmptyText, 12, 0.72, 0.72, 0.72, "OUTLINE")

  mainFrame.previewInfoTitle = mainFrame.previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  mainFrame.previewInfoTitle:SetPoint("TOPLEFT", mainFrame.previewModelFrame, "BOTTOMLEFT", 0, -9)
  mainFrame.previewInfoTitle:SetText(L("previewHowToGet"))
  StyleFont(mainFrame.previewInfoTitle, 10, 1, 0.82, 0.24, "OUTLINE")

  mainFrame.previewDetails = mainFrame.previewPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  mainFrame.previewDetails:SetPoint("TOPLEFT", mainFrame.previewInfoTitle, "BOTTOMLEFT", 0, -5)
  mainFrame.previewDetails:SetWidth(PREVIEW_WIDTH - 24)
  mainFrame.previewDetails:SetHeight(146)
  mainFrame.previewDetails:SetJustifyH("LEFT")
  mainFrame.previewDetails:SetJustifyV("TOP")
  SafeCall(mainFrame.previewDetails.SetWordWrap, mainFrame.previewDetails, true)
  StyleFont(mainFrame.previewDetails, 9, 0.9, 0.88, 0.78, "OUTLINE")

  mainFrame.previewWaypointButton = CreateFrame("Button", nil, mainFrame.previewPanel, "UIPanelButtonTemplate")
  mainFrame.previewWaypointButton:SetSize(92, 20)
  mainFrame.previewWaypointButton:SetPoint("BOTTOMRIGHT", mainFrame.previewPanel, "BOTTOMRIGHT", -12, 10)
  mainFrame.previewWaypointButton:SetText(L("buttonWaypoint"))
  DecorateButton(mainFrame.previewWaypointButton, UI_THEME.blue, 0.18)
  mainFrame.previewWaypointButton:SetScript("OnClick", function(self)
    if self.mount then
      AddTomTomWaypoint(self.mount)
    end
  end)
  mainFrame.previewWaypointButton:Hide()

  for i = 1, ROW_COUNT do
    local row = CreateFrame("Frame", nil, mainFrame)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_LEFT, LIST_TOP - ((i - 1) * (ROW_HEIGHT + ROW_GAP)))
    row:SetFrameLevel(mainFrame:GetFrameLevel() + 3)
    row:EnableMouse(true)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(_, delta)
      ScrollList(delta)
    end)
    row.baseR = i % 2 == 0 and 0.024 or 0.032
    row.baseG = i % 2 == 0 and 0.029 or 0.036
    row.baseB = i % 2 == 0 and 0.05 or 0.064
    row.baseA = 0.92

    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetColorTexture(row.baseR, row.baseG, row.baseB, row.baseA)

    row.glow = row:CreateTexture(nil, "BORDER")
    row.glow:SetAllPoints()
    row.glow:SetColorTexture(1, 0.56, 0.05, 0.16)
    row.glow:Hide()

    row.topLine = row:CreateTexture(nil, "BORDER")
    row.topLine:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.topLine:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.topLine:SetHeight(1)
    row.topLine:SetColorTexture(0.22, 0.36, 0.56, 0.48)

    row.bottomLine = row:CreateTexture(nil, "BORDER")
    row.bottomLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.bottomLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.bottomLine:SetHeight(1)
    row.bottomLine:SetColorTexture(0.02, 0.04, 0.08, 0.8)

    row.accent = row:CreateTexture(nil, "BORDER")
    row.accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.accent:SetWidth(4)
    row.accent:SetColorTexture(0.9, 0.14, 0.08, 0.72)

    row.iconBorder = row:CreateTexture(nil, "BORDER")
    row.iconBorder:SetSize(48, 48)
    row.iconBorder:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.iconBorder:SetColorTexture(0.95, 0.56, 0.12, 0.42)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(44, 44)
    row.icon:SetPoint("CENTER", row.iconBorder, "CENTER", 0, 0)
    row.icon:SetTexture(DEFAULT_MOUNT_ICON)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -6)
    row.name:SetWidth(430)
    row.name:SetJustifyH("LEFT")
    SafeCall(row.name.SetWordWrap, row.name, false)
    StyleFont(row.name, 12, 1, 0.83, 0.14, "OUTLINE")

    row.details = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.details:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -24)
    row.details:SetWidth(430)
    row.details:SetJustifyH("LEFT")
    SafeCall(row.details.SetWordWrap, row.details, false)
    StyleFont(row.details, 10, 0.94, 0.94, 0.9, "OUTLINE")

    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 70, -41)
    row.note:SetWidth(430)
    row.note:SetJustifyH("LEFT")
    SafeCall(row.note.SetWordWrap, row.note, false)
    StyleFont(row.note, 10, 0.68, 0.74, 0.86)

    row.doneButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.doneButton:SetSize(30, 22)
    row.doneButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -76, 7)
    DecorateButton(row.doneButton, UI_THEME.blue, 0.18)
    row.doneButton:EnableMouseWheel(true)
    row.doneButton:SetScript("OnMouseWheel", function(_, delta)
      ScrollList(delta)
    end)

    row.clearButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.clearButton:SetSize(30, 22)
    row.clearButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -42, 7)
    DecorateButton(row.clearButton, UI_THEME.orange, 0.18)
    row.clearButton:EnableMouseWheel(true)
    row.clearButton:SetScript("OnMouseWheel", function(_, delta)
      ScrollList(delta)
    end)

    row.favButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.favButton:SetSize(30, 22)
    row.favButton:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 7)
    DecorateButton(row.favButton, UI_THEME.gold, 0.18)
    row.favButton:EnableMouseWheel(true)
    row.favButton:SetScript("OnMouseWheel", function(_, delta)
      ScrollList(delta)
    end)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
    row.status:SetWidth(116)
    row.status:SetJustifyH("RIGHT")
    StyleFont(row.status, 10, 1, 0.82, 0.18, "OUTLINE")

    rows[i] = row
  end

  mainFrame.prevButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.prevButton:SetSize(92, 24)
  mainFrame.prevButton:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", CONTENT_LEFT, 18)
  mainFrame.prevButton:SetText(L("buttonPrevious"))
  DecorateButton(mainFrame.prevButton, UI_THEME.gold, 0.18)
  mainFrame.prevButton:SetScript("OnClick", function()
    currentScrollOffset = ClampScrollOffset(currentScrollOffset - ROW_COUNT, mainFrame.currentItemCount or 0)
    RefreshWindow()
  end)
  mainFrame.prevButton:Hide()

  mainFrame.nextButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.nextButton:SetSize(92, 24)
  mainFrame.nextButton:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", CONTENT_LEFT + ROW_WIDTH - 92, 18)
  mainFrame.nextButton:SetText(L("buttonNext"))
  DecorateButton(mainFrame.nextButton, UI_THEME.gold, 0.18)
  mainFrame.nextButton:SetScript("OnClick", function()
    currentScrollOffset = ClampScrollOffset(currentScrollOffset + ROW_COUNT, mainFrame.currentItemCount or 0)
    RefreshWindow()
  end)
  mainFrame.nextButton:Hide()

  mainFrame.pageText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  mainFrame.pageText:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", CONTENT_LEFT + math.floor(ROW_WIDTH / 2) - 100, 23)
  mainFrame.pageText:SetWidth(200)
  mainFrame.pageText:SetJustifyH("CENTER")
  mainFrame.pageText:SetText(L("listRange", 0, 0, 0))
  StyleFont(mainFrame.pageText, 11, 1, 0.86, 0.28, "OUTLINE")

  mainFrame.optionsButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
  mainFrame.optionsButton:SetSize(128, 24)
  mainFrame.optionsButton:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -38, 18)
  mainFrame.optionsButton:SetText(L("buttonOptions"))
  DecorateButton(mainFrame.optionsButton, UI_THEME.purple, 0.2)
  mainFrame.optionsButton:SetScript("OnClick", function()
    ToggleOptionsPanel()
  end)

  ClearMountPreview()
end

function PopulateMountRow(row, mount, listIndex)
  local attempted = IsAttempted(mount)
  local collected = HasMount(mount)
  local favorite = IsFavoriteMount(mount)
  local unavailableReason = GetMountUnavailableReason(mount)
  local reset = resetLabels[mount.reset] or mount.reset or L("unknownReset")
  local source = GetSourceDisplayName(mount.source or L("unknownSource"))
  local zone = LocalizeDataValue(mount.zone) or L("unknownZone")
  local boss = LocalizeDataValue(mount.boss) or L("unknownBoss")
  local vendor = GetMountVendor(mount)
  local mountName = GetMountDisplayName(mount)
  local note = BuildCompactMountNote(mount, boss, vendor)
  local namePrefix = ""

  if currentMode == "missingEasy" and listIndex then
    namePrefix = tostring(listIndex) .. ". "
  end

  if currentMode == "missingEasy" then
    local easyText = GetEasyMountActionText(mount)

    if easyText and easyText ~= "" then
      if note ~= "" then
        note = easyText .. " | " .. note
      else
        note = easyText
      end
    end
  end

  row.name:SetText(namePrefix .. mountName)
  row.details:SetText(source .. " | " .. zone .. " | " .. reset)
  row.note:SetText(note)

  if row.icon then
    row.icon:SetTexture(GetMountIcon(mount))
  end

  if unavailableReason then
    row.accent:SetColorTexture(0.72, 0.28, 0.92, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(0.72, 0.28, 0.92, 0.42)
    end
    row.status:SetText("|cffc084fc" .. L("statusUnavailable") .. "|r")
  elseif collected then
    row.accent:SetColorTexture(0.2, 0.9, 0.28, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(0.2, 0.9, 0.28, 0.38)
    end
    row.status:SetText("|cff66ff66" .. L("statusCollected") .. "|r")
  elseif attempted then
    row.accent:SetColorTexture(0.28, 0.58, 1, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(0.28, 0.58, 1, 0.38)
    end
    row.status:SetText("|cff66ccff" .. L("statusAttempted") .. "|r")
  else
    row.accent:SetColorTexture(1, 0.68, 0.12, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(1, 0.68, 0.12, 0.42)
    end
    row.status:SetText("|cffffd200" .. L("statusPending") .. "|r")
  end
  row.doneButton:Show()
  row.clearButton:Show()
  row.favButton:Show()
  ConfigureIconButton(row.doneButton, ACTION_ICON_DONE, L("buttonDone"), L("buttonActionDoneHint"), function()
    MarkAttempt(mount)
    Print(L("mountAttempted", GetMountDisplayName(mount)))
    RefreshWindow()
  end)
  ConfigureIconButton(row.clearButton, ACTION_ICON_CLEAR, L("buttonClear"), L("buttonActionClearHint"), function()
    ClearAttempt(mount)
    Print(L("mountAttemptCleared", GetMountDisplayName(mount)))
    RefreshWindow()
  end)
  ConfigureIconButton(row.favButton, ACTION_ICON_FAVORITE, favorite and L("buttonUnfavorite") or L("buttonFavorite"), L("buttonActionFavoriteHint"), function()
    ToggleFavoriteMount(mount)
    RefreshWindow()
  end)
  SetRowHover(row, false)

  row:SetScript("OnEnter", function()
    SetRowHover(row, true)
  end)

  row:SetScript("OnLeave", function()
    SetRowHover(row, false)
  end)

  row:SetScript("OnMouseDown", function()
    ShowMountPreview(mount)
  end)

  if unavailableReason then
    row.doneButton:Disable()
    row.clearButton:Disable()
  elseif collected then
    row.doneButton:Disable()
    row.clearButton:Disable()
  elseif attempted then
    row.doneButton:Disable()
    row.clearButton:Enable()
  else
    row.doneButton:Enable()
    row.clearButton:Disable()
  end

  row.favButton:Enable()
end

function PopulateAchievementRow(row, item)
  local missing = math.max(0, item.total - item.done)
  local favorite = IsFavoriteAchievement(item)
  local rewardText = LocalizeDataValue(item.reward) or L("previewEmpty")
  local itemNote = LocalizeDataValue(item.note)
  local note = L("reward") .. ": " .. rewardText
  local previewMount = GetAchievementPreviewMount(item)

  if itemNote and itemNote ~= "" then
    note = note .. " - " .. itemNote
  end

  if item.missingCriteria and item.missingCriteria[1] then
    note = note .. " | " .. L("missing") .. ": " .. item.missingCriteria[1]

    if #item.missingCriteria > 1 then
      note = note .. " +" .. (#item.missingCriteria - 1)
    end
  end

  row.name:SetText(item.name .. " (" .. item.percent .. "%)")
  if item.completed then
    row.details:SetText((item.expansion or "General") .. " | " .. L("statusCompleted") .. " | " .. item.done .. "/" .. item.total)
  else
    row.details:SetText((item.expansion or "General") .. " | " .. L("missing") .. " " .. missing .. " | " .. item.done .. "/" .. item.total)
  end

  row.note:SetText(note)
  if row.icon then
    row.icon:SetTexture(previewMount and GetMountIcon(previewMount) or DEFAULT_ACHIEVEMENT_ICON)
  end

  if item.completed then
    row.accent:SetColorTexture(0.2, 0.9, 0.28, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(0.2, 0.9, 0.28, 0.38)
    end
    row.status:SetText("|cff66ff66" .. L("statusCompleted") .. "|r")
  else
    row.accent:SetColorTexture(1, 0.68, 0.12, 0.85)
    if row.iconBorder then
      row.iconBorder:SetColorTexture(1, 0.68, 0.12, 0.42)
    end
    row.status:SetText("|cffffd200" .. L("statusPending") .. "|r")
  end
  row.doneButton:Show()
  row.clearButton:Hide()
  row.favButton:Show()
  ConfigureIconButton(row.doneButton, ACTION_ICON_VIEW, L("buttonView"), L("buttonActionViewHint"), function()
    OpenAchievement(item.achievementID)
  end)
  ConfigureIconButton(row.favButton, ACTION_ICON_FAVORITE, favorite and L("buttonUnfavorite") or L("buttonFavorite"), L("buttonActionFavoriteHint"), function()
    ToggleFavoriteAchievement(item)
    RefreshWindow()
  end)
  SetRowHover(row, false)

  row:SetScript("OnEnter", function()
    SetRowHover(row, true)
  end)

  row:SetScript("OnLeave", function()
    SetRowHover(row, false)
  end)

  row:SetScript("OnMouseDown", function()
    if previewMount then
      ShowMountPreview(previewMount)
    else
      ClearMountPreview(L("previewNoAchievementModel"))
    end
  end)

  row.doneButton:Enable()
  row.favButton:Enable()
end

RefreshWindow = function()
  if not mainFrame then
    return
  end

  local items, emptyText = BuildItems()
  local itemCount = #items

  mainFrame.currentItemCount = itemCount
  currentScrollOffset = ClampScrollOffset(currentScrollOffset, itemCount)
  currentPage = math.floor(currentScrollOffset / ROW_COUNT) + 1

  local attempted = CountAttempted(items)
  local pending = #items - attempted
  local startIndex = currentScrollOffset + 1
  local totalMounts, collectedMounts, missingMounts, favoriteMounts = GetCollectionStats()
  local collectionPercent = totalMounts > 0 and math.floor((collectedMounts / totalMounts) * 100 + 0.5) or 0
  local sourceFilterLabel = currentMode == "sources" and L("filterSource") or L("filterType")
  local filterText = " | " .. L("filterExpansion") .. ": " .. GetOptionLabel(expansionFilterOptions, currentExpansionFilter)
    .. " | " .. sourceFilterLabel .. ": " .. GetSourceDisplayName(currentSourceFilter)
    .. " | " .. L("filterCollection") .. ": " .. GetOptionLabel(collectionFilterOptions, currentCollectionFilter)

  if currentMode == "weekly" then
    filterText = filterText .. " | " .. GetWeeklyResetText()
  end

  if AzerColectRuntime.autoCatalogLoading then
    filterText = filterText .. " | " .. L("catalogLoading")
  end

  if SearchText() ~= "" then
    filterText = filterText .. " | " .. L("filterSearch") .. ": " .. currentSearchText
  end

  mainFrame.titleText:SetText(ADDON_DISPLAY_NAME)
  if mainFrame.progressPercent then
    mainFrame.progressPercent:SetText(collectionPercent .. "%")
  end

  if mainFrame.progressBar then
    mainFrame.progressBar:SetValue(collectionPercent)
  end

  if mainFrame.progressDetails then
    mainFrame.progressDetails:SetText(collectedMounts .. " / " .. totalMounts)
  end

  if mainFrame.expansionProgressDetails then
    mainFrame.expansionProgressDetails:SetText(GetCurrentExpansionProgressText())
  end

  if mainFrame.priorityMode then
    mainFrame.priorityMode:SetText(modeLabels[currentMode] or L("modeToday"))
  end

  UpdateSmartPriorityPanel()
  UpdateDailyRoutePanel()

  if mainFrame.statCards then
    UpdateStatCard(mainFrame.statCards.total, totalMounts, L("statRegistered"))
    UpdateStatCard(mainFrame.statCards.collected, collectedMounts, L("statCollectedSub"))
    UpdateStatCard(mainFrame.statCards.missing, missingMounts, L("statMissingSub"))
    UpdateStatCard(mainFrame.statCards.attempted, attempted, L("statCurrentView"))
    UpdateStatCard(mainFrame.statCards.favorites, favoriteMounts, L("statMarked"))
  end

  UpdateFilterButtons()

  if currentMode == "achievements" then
    mainFrame.summaryText:SetText(L("achievementsSummary", #items, filterText))
  elseif currentMode == "favorites" then
    mainFrame.summaryText:SetText(L("favoritesSummary", #items, GetCharacterKey(), filterText))
  elseif currentMode == "missingEasy" then
    mainFrame.summaryText:SetText(L("missingEasySummary", #items, filterText))
  elseif currentMode == "sources" then
    mainFrame.summaryText:SetText(L("sourceWindowSummary", #items, filterText))
  else
    mainFrame.summaryText:SetText(L("mountsSummary", pending, attempted, GetCharacterKey(), filterText))
  end

  for mode, button in pairs(mainFrame.tabs) do
    SetButtonSelected(button, mode == currentMode)
  end

  if mainFrame.missingEasyButton then
    SetButtonSelected(mainFrame.missingEasyButton, currentMode == "missingEasy")
  end

  for i = 1, ROW_COUNT do
    local row = rows[i]
    local item = items[startIndex + i - 1]

    if item then
      row:Show()

      if item.kind == "mount" then
        PopulateMountRow(row, item.mount, startIndex + i - 1)
      else
        PopulateAchievementRow(row, item)
      end
    else
      row:Hide()
    end
  end

  local previewMount

  for index = startIndex, math.min(#items, startIndex + ROW_COUNT - 1) do
    local item = items[index]

    if item.kind == "mount" then
      previewMount = item.mount
    else
      previewMount = GetAchievementPreviewMount(item)
    end

    if previewMount then
      break
    end
  end

  if #items == 0 then
    ClearMountPreview(L("previewNoResults"))
  elseif previewMount then
    ClearMountPreview(L("previewClickToLoad"))
  else
    ClearMountPreview(L("previewNoPageModel"))
  end

  if #items == 0 then
    mainFrame.emptyText:SetText(emptyText or L("previewEmpty"))
    mainFrame.emptyText:Show()
  else
    mainFrame.emptyText:Hide()
  end

  local visibleStart = itemCount > 0 and startIndex or 0
  local visibleEnd = itemCount > 0 and math.min(itemCount, startIndex + ROW_COUNT - 1) or 0

  mainFrame.pageText:SetText(L("listRange", visibleStart, visibleEnd, itemCount))

  if mainFrame.scrollThumb and mainFrame.scrollTrack then
    if itemCount <= ROW_COUNT then
      mainFrame.scrollThumb:Hide()
      mainFrame.scrollTrack:Hide()
    else
      local trackHeight = math.max(1, mainFrame.listPanel:GetHeight() - 16)
      local thumbHeight = math.max(28, trackHeight * (ROW_COUNT / itemCount))
      local progress = currentScrollOffset / math.max(1, itemCount - ROW_COUNT)
      local yOffset = -8 - ((trackHeight - thumbHeight) * progress)

      mainFrame.scrollTrack:Show()
      mainFrame.scrollThumb:Show()
      mainFrame.scrollThumb:SetHeight(thumbHeight)
      mainFrame.scrollThumb:ClearAllPoints()
      mainFrame.scrollThumb:SetPoint("TOPRIGHT", mainFrame.listPanel, "TOPRIGHT", -2, yOffset)
    end
  end
end

SetMode = function(mode)
  currentMode = mode or "today"
  ApplyModeDefaults(currentMode)
  ResetListScroll()
  RefreshWindow()
end

function OpenWindow(mode)
  CreateWindow()
  currentMode = mode or currentMode or "today"
  ApplyModeDefaults(currentMode)
  ResetListScroll()
  mainFrame:Show()
  RefreshWindow()
end

function ToggleWindow()
  if mainFrame and mainFrame:IsShown() then
    mainFrame:Hide()
    return
  end

  OpenWindow(currentMode or "today")
end

function Atan2(y, x)
  if math.atan2 then
    return math.atan2(y, x)
  end

  if x > 0 then
    return math.atan(y / x)
  end

  if x < 0 and y >= 0 then
    return math.atan(y / x) + math.pi
  end

  if x < 0 and y < 0 then
    return math.atan(y / x) - math.pi
  end

  if y > 0 then
    return math.pi / 2
  end

  if y < 0 then
    return -math.pi / 2
  end

  return 0
end

function SetMinimapButtonPosition(angle)
  if not minimapButton or not Minimap then
    return
  end

  local radius = 80
  local radians = math.rad(angle or 225)

  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

function ShowMinimapButton()
  if not minimapButton or not Minimap then
    return
  end

  minimapButton:SetParent(Minimap)
  minimapButton:SetSize(32, 32)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 5)
  minimapButton:SetAlpha(1)
  minimapButton:EnableMouse(true)
  minimapButton:Show()
  SetMinimapButtonPosition(AzerColectDB.minimap.angle)
end

function UpdateMinimapButtonDrag()
  if not minimapButton or not Minimap then
    return
  end

  local centerX, centerY = Minimap:GetCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()

  if not centerX or not centerY or not cursorX or not cursorY or not scale or scale == 0 then
    return
  end

  cursorX = cursorX / scale
  cursorY = cursorY / scale
  AzerColectDB.minimap = AzerColectDB.minimap or {}
  AzerColectDB.minimap.angle = math.deg(Atan2(cursorY - centerY, cursorX - centerX))

  SetMinimapButtonPosition(AzerColectDB.minimap.angle)
  minimapButton:Show()
end

function CreateMinimapButton()
  if not Minimap then
    return
  end

  EnsureDB()

  if minimapButton then
    ShowMinimapButton()
    return
  end

  local existingButton = _G and _G["AzerColectMinimapButton"]

  if existingButton then
    minimapButton = existingButton
    ShowMinimapButton()
    return
  end

  minimapButton = CreateFrame("Button", "AzerColectMinimapButton", Minimap)
  minimapButton:SetSize(32, 32)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
  minimapButton.icon:SetSize(22, 22)
  minimapButton.icon:SetPoint("CENTER", -1, 1)
  minimapButton.icon:SetTexture(MINIMAP_ICON_TEXTURE)
  minimapButton.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

  minimapButton.border = minimapButton:CreateTexture(nil, "OVERLAY")
  minimapButton.border:SetSize(53, 53)
  minimapButton.border:SetPoint("TOPLEFT")
  minimapButton.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  minimapButton:SetScript("OnClick", function(self, mouseButton)
    if self.isDragging then
      return
    end

    if mouseButton == "RightButton" then
      OpenWindow("achievements")
    else
      ToggleWindow()
    end
  end)

  minimapButton:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", UpdateMinimapButtonDrag)
  end)

  minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    UpdateMinimapButtonDrag()

    if C_Timer and C_Timer.After then
      local draggedButton = self
      C_Timer.After(0.1, function()
        draggedButton.isDragging = false
      end)
    else
      self.isDragging = false
    end
  end)

  minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(ADDON_DISPLAY_NAME)
    GameTooltip:AddLine(L("minimapLeft"), 1, 1, 1)
    GameTooltip:AddLine(L("minimapRight"), 1, 1, 1)
    GameTooltip:AddLine(L("minimapDrag"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)

  minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  ShowMinimapButton()
end

function TryCreateMinimapButton()
  local ok, errorMessage = pcall(CreateMinimapButton)
  lastMinimapError = ok and nil or tostring(errorMessage or "")

  if not ok or not minimapButton then
    if C_Timer and C_Timer.After then
      C_Timer.After(1, function()
        local retryOk, retryError = pcall(CreateMinimapButton)
        lastMinimapError = retryOk and nil or tostring(retryError or "")
      end)

      C_Timer.After(3, function()
        local retryOk, retryError = pcall(CreateMinimapButton)
        lastMinimapError = retryOk and nil or tostring(retryError or "")
      end)
    end
  end

  return ok and minimapButton ~= nil
end

RestoreMinimapButton = function()
  minimapButton = nil
  local ready = TryCreateMinimapButton()

  if ready then
    Print(L("minimapRestored"))
  elseif lastMinimapError and lastMinimapError ~= "" then
    Print(L("minimapError", lastMinimapError))
  else
    Print(L("minimapUnavailable"))
  end
end

function PrintFilters()
  Print(L("filtersExpansionLine", GetOptionLabel(expansionFilterOptions, currentExpansionFilter)))
  Print(L("filtersSourceLine", GetSourceDisplayName(currentSourceFilter)))
  Print(L("filtersCollectionLine", GetOptionLabel(collectionFilterOptions, currentCollectionFilter)))
  Print(L("filtersSearchLine", currentSearchText ~= "" and currentSearchText or L("searchNone")))
end

function ShowHelp()
  Print(L("helpCommands"))
  Print(L("helpShortcut"))
  Print(L("helpMinimap"))
  Print(L("helpSummary"))
  Print(L("helpFilters"))
  Print(L("helpRoutes"))
  Print(L("helpOptions"))
  Print(L("helpDailyRoute"))
  Print(L("helpDone"))
  Print(L("helpClear"))
  Print(L("helpFavorite"))
  Print(L("helpAchievement"))
  Print(L("helpNewMountAlert"))
  Print(L("helpAchievementTab"))
end

HandleSlashCommand = function(msg)
  local rawCommand = Normalize(Trim(msg or ""))

  if rawCommand == "minimap"
    or rawCommand == "minimapa"
    or rawCommand == "mini"
    or rawCommand == "icono" then
    RestoreMinimapButton()
    return
  end

  if rawCommand == "debug" then
    Print("debug: " .. ADDON_REVISION .. ", slash-ok, minimap=" .. tostring(minimapButton ~= nil) .. ", error=" .. tostring(lastMinimapError or "none"))
    return
  end

  local command, rest = rawCommand:match("^(%S*)%s*(.-)$")
  command = Normalize(command)
  rest = Trim(rest)

  if command == "opciones"
    or command == "options"
    or command == "config"
    or command == "configuracion" then
    OpenWindow(currentMode or "today")

    if mainFrame then
      if not mainFrame.optionsPanel then
        CreateOptionsPanel(mainFrame)
      end

      RefreshOptionsPanel()
      UpdateDailyRoutePanel()
      mainFrame.optionsPanel:Show()
    end

    return
  end

  if (command == "ruta" and (rest == "diaria" or rest == "iniciar"))
    or rawCommand == "daily route"
    or rawCommand == "start route"
    or rawCommand == "iniciar ruta" then
    OpenWindow("today")
    StartDailyRoute()
    return
  end

  if (command == "ruta" and rest == "siguiente")
    or rawCommand == "siguiente ruta"
    or rawCommand == "next route" then
    AdvanceDailyRoute()
    return
  end

  if (command == "ruta" and (rest == "parar" or rest == "detener"))
    or rawCommand == "parar ruta"
    or rawCommand == "detener ruta"
    or rawCommand == "stop route" then
    StopDailyRoute()
    return
  end

  if command == "" or command == "ventana" or command == "window" or command == "janela" or command == "fenetre" or command == "fenster" then
    TryCreateMinimapButton()
    OpenWindow("today")
    return
  end

  if command == "alerta"
    or command == "alert"
    or command == "testalert"
    or command == "nueva"
    or command == "premio" then
    local mount = rest ~= "" and FindMount(rest) or nil

    if mount then
      QueueNewMountAlert(GetMountJournalID(mount), GetMountDisplayName(mount))
    else
      QueueNewMountAlert(nil, rest ~= "" and rest or "Ashes of Al'ar")
    end

    return
  end

  if command == "hoy" or command == "today" or command == "hoje" or command == "heute" or command == "aujourdhui" then
    OpenWindow("today")
    return
  end

  if command == "semanal" or command == "weekly" or command == "hebdo" or command == "woche" then
    OpenWindow("weekly")
    return
  end

  if command == "reputacion" or command == "rep" or command == "reputation" or command == "reputacao" or command == "ruf" then
    OpenWindow("reputation")
    return
  end

  if command == "eventos" or command == "evento" or command == "events" or command == "event" then
    OpenWindow("events")
    return
  end

  if command == "rutas" or command == "ruta" or command == "routes" or command == "route" or command == "farm" then
    OpenWindow("routes")
    return
  end

  if command == "falta"
    or command == "faltan"
    or command == "faciles"
    or command == "easy"
    or command == "missing"
    or command == "missingeasy" then
    OpenWindow("missingEasy")
    return
  end

  if command == "todas" or command == "all" or command == "toutes" or command == "alle" then
    OpenWindow("all")
    return
  end

  if command == "favoritos" or command == "favorites" or command == "favoris" or command == "favoriten" then
    OpenWindow("favorites")
    return
  end

  if command == "resumen" or command == "summary" or command == "resumo" or command == "resume" or command == "zusammenfassung" then
    PrintSummary()
    return
  end

  if command == "filtros" or command == "filters" or command == "filtres" or command == "filter" then
    PrintFilters()
    return
  end

  if command == "minimap" or command == "minimapa" or command == "mini" or command == "icono" then
    RestoreMinimapButton()
    return
  end

  if command == "limpiar" or command == "clearfilters" or command == "limpar" or command == "effacer" or command == "loeschen" then
    currentExpansionFilter = "all"
    currentSourceFilter = "all"
    currentCollectionFilter = "missing"
    currentSearchText = ""
    ApplyModeDefaults(currentMode)

    if mainFrame and mainFrame.searchBox then
      mainFrame.searchBox:SetText("")
      mainFrame.searchBox:ClearFocus()
    end

    Print(L("filtersCleared"))
    ShowAllMountsForSource()
    return
  end

  if command == "estado" or command == "status" or command == "collection" or command == "coleccion" then
    local value = FindOptionValue(collectionFilterOptions, rest)

    if value then
      currentCollectionFilter = value

      Print(L("collectionFilterSet", GetOptionLabel(collectionFilterOptions, currentCollectionFilter)))
      ResetListScroll()

      if mainFrame and mainFrame:IsShown() then
        RefreshWindow()
      else
        OpenWindow(currentMode or "all")
      end
    else
      Print(L("collectionNotFound"))
    end

    return
  end

  if command == "expansion" or command == "expansionfilter" then
    local value = FindOptionValue(expansionFilterOptions, rest)

    if value then
      currentExpansionFilter = value
      currentSourceFilter = "all"
      ApplyModeDefaults(currentMode)
      Print(L("expansionFilterSet", GetOptionLabel(expansionFilterOptions, currentExpansionFilter)))
      ShowAllMountsForExpansion()
    else
      Print(L("expansionNotFound"))
    end

    return
  end

  if command == "tipo" or command == "fuente" or command == "source" or command == "fonte" or command == "quelle" then
    if rest == "" then
      OpenWindow("sources")
      return
    end

    local value = FindOptionValue(sourceFilterOptions, rest)

    if value then
      currentSourceFilter = value
      if currentMode == "reputation" or currentMode == "events" then
        currentMode = "sources"
      end
      Print(L("sourceFilterSet", GetSourceDisplayName(currentSourceFilter)))
      ShowAllMountsForSource()
    else
      Print(L("sourceNotFound"))
    end

    return
  end

  if command == "fuentes" or command == "sources" or command == "fontes" or command == "quellen" then
    OpenWindow("sources")
    return
  end

  if command == "vendedores" or command == "vendor" or command == "vendors" or command == "vendeurs" or command == "haendler" then
    currentSourceFilter = "Vendor"
    OpenWindow("sources")
    return
  end

  if command == "buscar" or command == "search" or command == "busca" or command == "chercher" or command == "suche" then
    currentSearchText = rest

    if mainFrame and mainFrame.searchBox then
      mainFrame.searchBox:SetText(currentSearchText)
      mainFrame.searchBox:ClearFocus()
    end

    Print(currentSearchText ~= "" and L("searchSet", currentSearchText) or L("searchCleared"))
    OpenWindow(currentMode or "all")
    return
  end

  if command == "logros" or command == "achievements" or command == "conquistas" or command == "erfolge" or command == "hautsfaits" then
    OpenWindow("achievements")
    return
  end

  if command == "fav" or command == "favorito" then
    if rest == "" then
      OpenWindow("favorites")
      return
    end

    local mount = FindMount(rest)

    if mount then
      ToggleFavoriteMount(mount)
      RefreshWindow()
      return
    end

    local achievement = FindAchievement(rest)

    if achievement then
      ToggleFavoriteAchievement(achievement)
      RefreshWindow()
    else
      Print(L("mountOrAchievementNotFound"))
    end

    return
  end

  if command == "logro" or command == "achievement" then
    if rest == "" then
      Print(L("achievementCommandHelp"))
      OpenWindow("achievements")
      return
    end

    local achievement = FindAchievement(rest)

    if achievement then
      OpenAchievement(GetAchievementID(achievement))
    else
      Print(L("achievementNotFound"))
    end

    return
  end

  if command == "umbral" or command == "threshold" then
    Print(L("achievementTabAll"))
    OpenWindow("achievements")

    return
  end

  if command == "hecho" or command == "done" then
    local mount = FindMount(rest)

    if mount then
      MarkAttempt(mount)
      Print(L("mountAttempted", GetMountDisplayName(mount)))
      RefreshWindow()
    else
      Print(L("mountNotFound"))
    end

    return
  end

  if command == "borrar" or command == "clear" then
    local mount = FindMount(rest)

    if mount then
      ClearAttempt(mount)
      Print(L("mountAttemptCleared", GetMountDisplayName(mount)))
      RefreshWindow()
    else
      Print(L("mountNotFound"))
    end

    return
  end

  ShowHelp()
end

RegisterSlashCommands()

addon:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGOUT" then
    UpdateCurrentCharacterSnapshot(true)
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    TryCreateMinimapButton()
    ScheduleCharacterSnapshot(5)
    ScheduleMountCollectionScan(false)
    return
  end

  if event == "UPDATE_FACTION"
    or event == "CRITERIA_UPDATE"
    or event == "ACHIEVEMENT_EARNED"
    or event == "QUEST_TURNED_IN"
    or event == "QUEST_ACCEPTED"
    or event == "QUEST_LOG_UPDATE" then
    UpdateCurrentCharacterSnapshot()

    if mainFrame and mainFrame:IsShown() then
      QueueRefreshWindow(0.25)
    end

    return
  end

  if event ~= "PLAYER_LOGIN" then
    activeCalendarEventsCacheKey = nil
    activeCalendarEventsCache = nil
    activeCalendarEventsCanRead = false

    if event == "COMPANION_LEARNED"
      or event == "NEW_MOUNT_ADDED" then
      InvalidateMountJournalCaches()
      ScheduleMountCollectionScan(true)
    elseif event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
      InvalidateMountJournalCaches()
      ScheduleMountCollectionScan(true)
    else
      InvalidateAzerColectDataCache()
    end

    if mainFrame and mainFrame:IsShown() then
      QueueRefreshWindow(0.25)
    end

    return
  end

  RegisterSlashCommands()

  local dbReady = pcall(EnsureDB)
  local minimapReady = false

  if dbReady then
    minimapReady = TryCreateMinimapButton()
  end

  Print(L("loaded"))

  if not dbReady then
    Print(L("dbUnavailable"))
    return
  end

  if not minimapReady then
    Print(L("minimapUnavailable"))
  end

  SafeCall(addon.RegisterEvent, addon, "CALENDAR_UPDATE_EVENT_LIST")
  SafeCall(addon.RegisterEvent, addon, "PLAYER_ENTERING_WORLD")
  SafeCall(addon.RegisterEvent, addon, "UPDATE_FACTION")
  SafeCall(addon.RegisterEvent, addon, "CRITERIA_UPDATE")
  SafeCall(addon.RegisterEvent, addon, "ACHIEVEMENT_EARNED")
  SafeCall(addon.RegisterEvent, addon, "QUEST_TURNED_IN")
  SafeCall(addon.RegisterEvent, addon, "QUEST_ACCEPTED")
  SafeCall(addon.RegisterEvent, addon, "QUEST_LOG_UPDATE")
  SafeCall(addon.RegisterEvent, addon, "COMPANION_LEARNED")
  SafeCall(addon.RegisterEvent, addon, "NEW_MOUNT_ADDED")
  SafeCall(addon.RegisterEvent, addon, "MOUNT_JOURNAL_USABILITY_CHANGED")

  ScheduleCharacterSnapshot(5)
  ScheduleMountCollectionScan(false)
end)
