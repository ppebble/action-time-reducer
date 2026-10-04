local ATR = ActionTimeReducer
local options = SandboxVars.ActionTimeReducer
for _, names in pairs(ATR.groups) do
    for _, name in ipairs(names) do options[ATR.optionKey(_G[name])] = 30 end
end

-- All declared classes were loaded from the installed game by test.ps1.
for group, names in pairs(ATR.groups) do
    for _, name in ipairs(names) do
        check(type(_G[name]) == "table", "native class missing: " .. name)
        check(ATR.category(_G[name]) == group, "category identity: " .. name)
    end
end
-- Exhaustive isolation: one selected action must not enable any other action.
local seenKeys = {}
for group, names in pairs(ATR.groups) do
    options[group] = 90 -- Old category values must have no effect, including zero overrides.
    for _, name in ipairs(names) do
        local class = _G[name]
        local key = ATR.optionKey(class)
        check(not seenKeys[key], "unique action option: " .. key)
        seenKeys[key] = true
        options[key] = 0
    end
end
for _, names in pairs(ATR.groups) do
    for _, name in ipairs(names) do
        local class = _G[name]
        local key = ATR.optionKey(class)
        options[key] = 30
        for _, peers in pairs(ATR.groups) do
            for _, peer in ipairs(peers) do
                local blockedMP = TEST_MODE ~= "singleplayer"
                    and (peer == "ISBuildAction" or peer == "ISInventoryTransferAction")
                local expected = peer == name and not blockedMP and 0.7 or 1
                check(math.abs(ATR.factorFor(_G[peer]) - expected) < 0.00001,
                    "isolated " .. name .. " from " .. peer)
            end
        end
        options[key] = 0
        check(ATR.factorFor(class) == 1, "explicit zero ignores legacy group: " .. name)
    end
end
for _, names in pairs(ATR.groups) do
    for _, name in ipairs(names) do options[ATR.optionKey(_G[name])] = 30 end
end

-- Food/smoking must resolve after constructor fields, also on server duration queries.
local savedTags = ItemTag
ItemTag = {SMOKABLE = "smokable"}
local eatGetter = ISEatFoodAction.getDuration
ISEatFoodAction.getDuration = function() return 100 end
options.EatFoodAction, options.Smoking = 0, 60
local smoke = ISBaseTimedAction.new(ISEatFoodAction, character)
smoke.item = {hasTag = function(self, tag) return tag == "smokable" end}
check(ATR.optionKey(ISEatFoodAction, smoke) == "Smoking", "smokable uses independent setting")
check(smoke:getDuration() == 40, "server-style duration query resolves smoking with food disabled")
check(smoke:getDuration() == 40, "smoking duration does not compound")
local food = ISBaseTimedAction.new(ISEatFoodAction, character)
food.item = {hasTag = function() return false end}
check(food:getDuration() == 100, "food remains vanilla while smoking enabled")
options.EatFoodAction, options.Smoking = 50, 0
local plainSmoke = ISBaseTimedAction.new(ISEatFoodAction, character)
plainSmoke.item = smoke.item
plainSmoke.maxTime = 100
plainSmoke:create()
check(plainSmoke.maxTime == 100, "zero smoking overrides enabled food at create")
local foodEnabled = ISBaseTimedAction.new(ISEatFoodAction, character)
foodEnabled.item = food.item
foodEnabled.maxTime = 100
foodEnabled:create()
check(foodEnabled.maxTime == 50, "food reduction independent at create")
ISEatFoodAction.getDuration, ItemTag = eatGetter, savedTags
options.EatFoodAction, options.Smoking = 30, 0

local function near(a, b) return math.abs(a - b) < 0.00001 end
local function allocate(class, fields)
    local action = ISBaseTimedAction.new(class, character)
    for key, value in pairs(fields or {}) do action[key] = value end
    return action
end
local samples = {
    {ISBarricadeAction, {}, 75},
    {ISApplyBandage, {bodyPart = {manipulatingUsername = function() return nil end}, doctorLevel = 5}, 100},
    {ISWearClothing, {item = {}}, 50},
    {ISFixVehiclePartAction, {}, 60},
    {ISCleanBandage, {recipe = recipe}, 120},
    {ISButcherAnimal, {perkLevel = 5}, 800},
    {ISDrinkFluidAction, {maxTime = 100}, 100},
    {ISFluidTransferAction, {maxTime = 100}, 100},
    {ISInstallVehiclePart, {part = {}, item = {}, maxTime = 100}, 100},
}
for _, sample in ipairs(samples) do
    local action = allocate(sample[1], sample[2])
    check(near(action:getDuration(), sample[3] * 0.7), "native reduction: " .. sample[1].Type)
    action.maxTime = action:getDuration()
    for i = 1, 3 do
        check(near(action:getDuration(), sample[3] * 0.7), "stored duration must not compound: " .. sample[1].Type)
    end
end

local barricade = allocate(ISBarricadeAction, {})
check(near(barricade:getDuration(), 52.5), "wood barricade baseline")
barricade.isMetal = true
check(near(barricade:getDuration(), 101.5), "metal flag assigned after initial duration query is respected")

local readingItem = {
    getNumberOfPages = function() return 0 end,
    hasTag = function() return false end,
}
local reading = allocate(ISReadABook, {item = readingItem, minutesPerPage = 1})
check(near(reading:getDuration(), 420), "native reading time is reduced")
reading.maxTime = reading:getDuration()
local savedEmulate = emulateAnimEvent
local period
emulateAnimEvent = function(netAction, interval) period = interval end
reading:serverStart()
check(near(period, 672), "native page cadence follows shortened duration")
emulateAnimEvent = savedEmulate

-- create() handles raw table allocators and inherited maxTime getters.
local rawTransfer = {character = character, maxTime = 100}
setmetatable(rawTransfer, ISInventoryTransferAction)
ISInventoryTransferAction.__index = ISInventoryTransferAction
rawTransfer:create()
local expected = TEST_MODE == "singleplayer" and 70 or 100
check(near(rawTransfer.maxTime, expected), "raw SP transfer accelerates; MP remains authoritative")
check(near(rawTransfer:getDuration(), expected), "raw transfer duration stays stable")

local rawBuild = {character = character, maxTime = 100}
setmetatable(rawBuild, ISBuildAction)
ISBuildAction.__index = ISBuildAction
rawBuild:create()
check(near(rawBuild.maxTime, expected), "raw SP build accelerates; MP remains authoritative")
check(ATR.factorFor(ISMultiStageBuild) == 0.7, "Lua multistage building still supported in MP")

local savedCell = getCell
getCell = function() return {getGridSquare = function() return {} end} end
local nativeBuild = ISBuildAction:new(character, {}, 1, 2, 0, false, "nativeSprite", 100)
nativeBuild:create()
local buildExpected = TEST_MODE == "client" and -1 or expected
check(near(nativeBuild.maxTime, buildExpected), "actual native build constructor and shared create")
getCell = savedCell

local savedMultiplayer, savedBuildMenu = isMultiplayer, ISBuildMenu
local savedWallpaper, savedInstanceof = WallPaper, instanceof
isMultiplayer = function() return false end
ISBuildMenu = {cheat = true}
WallPaper = {wall = {paper = "nativeSprite"}}
instanceof = function() return false end
local properties = {get = function() return "wall" end, has = function() return false end}
local wall = {getSprite = function() return {getProperties = function() return properties end} end}
local wallpaper = ISWallpaperAction:new(character, wall, {}, "paper")
wallpaper:create()
check(wallpaper.maxTime == 1, "native post-getter instant wallpaper override remains instant")
isMultiplayer, ISBuildMenu = savedMultiplayer, savedBuildMenu
WallPaper, instanceof = savedWallpaper, savedInstanceof

local scheduled
local savedAnimalEmulate = emulateAnimEvent
emulateAnimEvent = function(netAction, value) scheduled = value end
for _, sample in ipairs({
    {ISMilkAnimal, "timePerLiter"}, {ISShearAnimal, "timePerLiter"},
    {ISHutchCleanFloor, "timePerDirt"}, {ISHutchCleanNest, "timePerDirt"},
    {ISGiveWaterToAnimal, "timePerUse"}, {ISGatherBloodFromAnimal, "timePerLiter"},
}) do
    local action = allocate(sample[1], {
        animal = {getBehavior = function() return {setBlockMovement = function() end} end},
        hook = {getUsingPlayer = function() return true end},
    })
    action[sample[2]] = 10
    action:serverStart()
    check(scheduled == 140, "actual native animal event period: " .. sample[1].Type)
    check(action[sample[2]] == 10, "native interval restored: " .. sample[1].Type)
end
emulateAnimEvent = savedAnimalEmulate

local nativeGet = ISFixVehiclePartAction.getDuration
local unchanged = {character = character, maxTime = 100}
local excluded = ISBaseTimedAction:derive("ExcludedAction")
setmetatable(unchanged, excluded)
unchanged:create()
check(unchanged.maxTime == 100, "unknown action keeps original create behavior")
check(ISFixVehiclePartAction.getDuration == nativeGet, "native getter class reference preserved")

for key in pairs(options) do options[key] = 0 end
check(ISBaseTimedAction.new(ISCraftAction, character).getDuration == ISCraftAction.getDuration,
    "all-zero defaults do not wrap actions")
options.CraftAction = 50
options.DismantleAction = 50
print("PASS native categories, reading cadence, stored-duration idempotence and MP boundaries")
