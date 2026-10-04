require = function() end -- game files below are explicitly loaded by the harness
ISInventoryPage = {}
isClient = function() return TEST_MODE == "client" end
isServer = function() return TEST_MODE == "server" end
log = function() end
DebugType = { CraftLogic = "craft" }
CharacterTrait = { ALL_THUMBS = "allthumbs" }
Perks = { Strength = "strength" }
convertToPZNetTable = function(value) return value end
SandboxVars = { ActionTimeReducer = {} }
Metabolics = {LightDomestic = "light", HeavyDomestic = "heavy", MediumWork = "medium"}
ItemTag = {FAST_READ = "fastread"}
ItemBodyLocation = {EYES = "eyes"}
MoodleType = {UNHAPPY = "unhappy", DRUNK = "drunk"}
BodyPartType = {Hand_L = 0, ForeArm_R = 1, ToIndex = function(value) return value end,
    FromIndex = function(value) return value end}
LuaTimedActionNew = {new = function() return {} end}
getGameTime = function() return {getMinutesPerDay = function() return 60 end} end
activeMods = {}
Events = {OnGameBoot = {Add = function(callback) gameBootHook = callback end}}
getActivatedMods = function()
    return { contains = function(self, id) return activeMods[id] == true end }
end
inventory = {}
character = {
    getInventory = function() return inventory end,
    isTimedActionInstant = function() return false end,
    getPerkLevel = function() return 5 end,
    hasTrait = function() return false end,
    isWearingAwkwardGloves = function() return false end,
    isMechanicsCheat = function() return false end,
    getMoodles = function() return {getMoodleLevel = function() return fixtureMoodle or 0 end} end,
    getBodyDamage = function() return {getBodyPart = function() return {getPain = function() return 0 end} end} end,
    getTimedActionTimeModifier = function() return 1 end,
    getWornItems = function() return {getItem = function() return nil end} end,
    isSitting = function() return false end,
}
recipe = {
    isCanBeDoneFromFloor = function() return false end,
    isStopOnWalk = function() return true end,
    isStopOnRun = function() return true end,
    getTimeToMake = function() return 120 end,
    getName = function() return "fixture recipe" end,
    getTimedActionScript = function() return {} end,
    isCanWalk = function() return false end,
    getTime = function() return 24 end,
}
checks = 0
function check(value, message)
    checks = checks + 1
    if not value then error(message) end
end
