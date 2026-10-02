require = function() end -- game files below are explicitly loaded by the harness
isClient = function() return TEST_MODE == "client" end
isServer = function() return TEST_MODE == "server" end
log = function() end
DebugType = { CraftLogic = "craft" }
CharacterTrait = { ALL_THUMBS = "allthumbs" }
Perks = { Strength = "strength" }
convertToPZNetTable = function(value) return value end
SandboxVars = { SafeActionTime = {
    Enabled = true, SpeedPercent = 200, Crafting = true, Dismantling = true,
} }
activeMods = {}
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
