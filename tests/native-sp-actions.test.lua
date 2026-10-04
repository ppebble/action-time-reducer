-- Installed native constructors and create(), with a recording substitute for
-- the Java allocation boundary. This is Kahlua coverage, not live game proof.
if TEST_MODE == "singleplayer" then
    local savedSandbox, savedAllocator = getSandboxOptions, LuaTimedActionNew
    local savedTags, savedTraits, savedCore = ItemTag, CharacterTrait, getCore
    local savedTimestamp, savedQueue, savedRound = getTimestampMs, ISTimedActionQueue, round
    local savedWipe = table.wipe
    local options = SandboxVars.ActionTimeReducer
    local savedEatFoodAction, savedTransfer = options.EatFoodAction, options.InventoryTransfer
    local live = {EatFoodAction = 30, InventoryTransfer = 40}
    -- Match SandboxSettings: the option objects changed but SandboxVars is stale.
    options.EatFoodAction, options.InventoryTransfer = 0, 0
    getSandboxOptions = function()
        return {getOptionByName = function(self, name)
            local category = string.sub(name, string.len("ActionTimeReducer.") + 1)
            if live[category] == nil then return nil end
            return {getValue = function() return live[category] end}
        end}
    end
    local submitted = {}
    LuaTimedActionNew = {new = function(action)
        table.insert(submitted, action.maxTime)
        return {}
    end}
    ItemTag = {SMOKABLE = "smokable", SPOON = "spoon", FAST_READ = "fastread"}
    CharacterTrait = {DEXTROUS = "dextrous", ALL_THUMBS = "allthumbs"}
    getTimestampMs = function() return 0 end
    getCore = function() return {getGameMode = function() return "Sandbox" end} end
    local inv = {
        getFirstTagEvalRecurse = function() return nil end,
        getFirstTypeEvalRecurse = function() return nil end,
    }
    local player = {}
    for key, value in pairs(character) do player[key] = value end
    player.getInventory = function() return inv end
    local food = {
        getContainer = function() return inv end,
        hasTag = function() return false end,
        getEatType = function() return "EatSmall" end,
        getBaseHunger = function() return -0.2 end,
        getHungerChange = function() return -0.2 end,
        getCustomMenuOption = function() return nil end,
        getEatTime = function() return 0 end,
        getCustomEatSound = function() return nil end,
    }
    local savedText = getText
    getText = function(key) return key end
    local eating = ISEatFoodAction:new(player, food, 1)
    check(eating.maxTime == 232, "native food constructor retains its direct class-getter result")
    eating:create()
    check(math.abs(submitted[1] - 232 * 0.7) < 0.00001,
        "native food create must submit live 30 percent reduction despite stale SandboxVars")
    check(math.abs(eating:getDuration() - 232 * 0.7) < 0.00001,
        "native food instance getter remains reduced without compounding")
    live.EatFoodAction = 0
    local unmodifiedEating = ISEatFoodAction:new(player, food, 1)
    unmodifiedEating:create()
    check(submitted[2] == 232, "live zero restores original native food duration for new actions")

    local source = inv
    local target = {
        getType = function() return "crate" end,
        isInCharacterInventory = function() return false end,
        isVehicleSeat = function() return false end,
    }
    source.getType = function() return "inventory" end
    source.isVehicleSeat = function() return false end
    source.isInCharacterInventory = function() return true end
    local function transferItem(name, weight)
        return {getActualWeight = function() return weight end,
            getWeight = function() return weight end,
            isFavorite = function() return false end,
            getFullType = function() return name end}
    end
    local first = ISInventoryTransferAction:new(player, transferItem("Base.Hammer", 1), source, target)
    local second = ISInventoryTransferAction:new(player, transferItem("Base.Axe", 2), source, target)
    check(first.maxTime == 50 and second.maxTime == 100, "native transfer constructors calculate original weight timings")
    local queue = {queue = {first, second}}
    queue.indexOf = function(self, action)
        for index, candidate in ipairs(self.queue) do
            if candidate == action then return index end
        end
        return -1
    end
    ISTimedActionQueue = {getTimedActionQueue = function() return queue end}
    round = function(value) return value end
    table.wipe = function(value)
        for key in pairs(value) do value[key] = nil end
    end
    first:create()
    check(submitted[3] == 30, "native transfer create submits live 40 percent reduction")
    first:checkQueueList()
    check(#queue.queue == 1 and #first.queueList == 2, "native transfer merging retains its original queue behavior")
    check(first.queueList[1].time == 30 and first.queueList[2].time == 60,
        "first and native merged second batch both receive exactly one live reduction")
    first:checkQueueList()
    check(first.queueList[1].time == 30 and first.queueList[2].time == 60,
        "native repeated merge polling cannot compound reduction")

    local savedMenu = ISInventoryPaneContextMenu
    ISInventoryPaneContextMenu = {hasOpenFlame = function() return false end}
    player.getVehicle = function() return nil end
    local tobacco = {}
    for key, value in pairs(food) do tobacco[key] = value end
    tobacco.hasTag = function(self, tag) return tag == ItemTag.SMOKABLE end
    tobacco.getBaseHunger = function() return 0 end
    tobacco.getHungerChange = function() return 0 end
    live.EatFoodAction, live.Smoking = 0, 40
    local smoking = ISEatFoodAction:new(player, tobacco, 1)
    check(smoking.maxTime == 460, "native smoking constructor retains native duration")
    check(smoking:getDuration() == 276, "native smoking server-style query applies own option")
    smoking:create()
    check(smoking.maxTime == 276, "native smoking create remains singly reduced")
    live.EatFoodAction, live.Smoking = 60, 0
    local smokingZero = ISEatFoodAction:new(player, tobacco, 1)
    smokingZero:create()
    check(smokingZero.maxTime == 460, "native smoking zero ignores nonzero food setting")
    ISInventoryPaneContextMenu = savedMenu

    getSandboxOptions, LuaTimedActionNew = savedSandbox, savedAllocator
    ItemTag, CharacterTrait, getCore = savedTags, savedTraits, savedCore
    getTimestampMs, ISTimedActionQueue, round = savedTimestamp, savedQueue, savedRound
    table.wipe = savedWipe
    getText = savedText
    options.EatFoodAction, options.InventoryTransfer = savedEatFoodAction, savedTransfer
    print("PASS native SP food and transfer constructors, allocation boundary and merged batch fixture")
end
