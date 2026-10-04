require "TimedActions/ISBaseTimedAction"

ActionTimeReducer = ActionTimeReducer or {}
local ATR = ActionTimeReducer
if ATR.installed then return end
ATR.decorators = ATR.decorators or {}

-- Resolve exact class identities at allocation time; vanilla modules may load later.
ATR.groups = {
    Crafting = {"ISCraftAction", "ISHandcraftAction", "ISResearchRecipe"},
    Construction = {"ISBuildAction", "ISMultiStageBuild", "ISDismantleAction",
        "ISDestroyStuffAction", "ISBarricadeAction", "ISUnbarricadeAction",
        "ISPaintAction", "ISPaintSignAction", "ISPlasterAction", "ISWallpaperAction", "ISChopTreeAction"},
    Medical = {"ISApplyBandage", "ISDisinfect", "ISStitch", "ISSplint",
        "ISRemoveGlass", "ISRemoveBullet", "ISCleanBurn", "ISTakePillAction",
        "ISComfreyCataplasm", "ISGarlicCataplasm", "ISPlantainCataplasm", "ISMedicalCheckAction"},
    ClothingAndRepair = {"ISWearClothing", "ISRepairClothing", "ISRemovePatch", "ISFixAction", "ISFixGenerator"},
    VehicleMaintenance = {"ISInstallVehiclePart", "ISUninstallVehiclePart",
        "ISFixVehiclePartAction", "ISRepairEngine", "ISTakeEngineParts",
        "ISInflateTire", "ISDeflateTire", "ISRepairLightbar"},
    Hygiene = {"ISWashYourself", "ISWashClothing", "ISCleanBandage"},
    Reading = {"ISReadABook"},
    Consumption = {"ISEatFoodAction", "ISDrinkFromBottle", "ISDrinkFluidAction"},
    Liquids = {"ISFluidTransferAction", "ISFluidEmptyAction", "ISTakeWaterAction",
        "ISAddFluidFromItemAction", "ISDumpWaterAction", "ISDumpContentsAction",
        "ISAddFuel", "ISTakeFuel", "ISAddGasolineToVehicle", "ISTakeGasolineFromVehicle",
        "ISRefuelFromGasPump", "ISConsolidateDrainable", "ISTransferWaterAction"},
    AnimalCare = {"ISMilkAnimal", "ISShearAnimal", "ISHutchCleanFloor", "ISHutchCleanNest",
        "ISGiveWaterToAnimal", "ISGatherBloodFromAnimal", "ISFeedAnimalFromHand",
        "ISButcherAnimal", "ISCutAnimalOnHook", "ISGetAnimalBones", "ISRemoveHeadFromAnimal",
        "ISRemoveLeatherFromAnimal", "ISRemoveMeatFromAnimal", "ISKillAnimalInInventory"},
    InventoryTransfer = {"ISInventoryTransferAction"},
}

local conflicts = {"TwisTonFireFasterActions", "yxjs_FasterAction", "FasterActionsB42",
    "b42FasterActions", "vac_mod_b42_15"}

local storedDurationNames = {"ISSplint", "ISInstallVehiclePart", "ISRepairEngine",
    "ISTakeEngineParts", "ISRepairLightbar", "ISDrinkFluidAction", "ISCartTransferAction"}

local function usesStoredDuration(class, getter)
    if getter == ISBaseTimedAction.getDuration then return true end
    for _, name in ipairs(storedDurationNames) do
        if class == rawget(_G, name) then return true end
    end
    return false
end

function ATR.category(class)
    if not class then return nil end
    for group, names in pairs(ATR.groups) do
        for _, name in ipairs(names) do
            if class == rawget(_G, name) then return group end
        end
    end
end

-- Each exact native action has its own setting; groups only organize the UI.
function ATR.optionKey(class, action)
    if not class then return nil end
    -- Optional exact-class compatibility. Never require or alter the cart mod.
    if class == rawget(_G, "ISCartTransferAction") and getActivatedMods then
        local mods = getActivatedMods()
        if mods and mods:contains("SaucedCarts") then return "CartTransfer" end
    end
    for _, names in pairs(ATR.groups) do
        for _, name in ipairs(names) do
            if class == rawget(_G, name) then
                if name == "ISInventoryTransferAction" then return "InventoryTransfer" end
                if name == "ISEatFoodAction" and action and action.item and ItemTag
                    and ItemTag.SMOKABLE and action.item:hasTag(ItemTag.SMOKABLE) then
                    return "Smoking"
                end
                return string.sub(name, 3)
            end
        end
    end
end

local function hasConflict()
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    if not mods then return false end
    for _, id in ipairs(conflicts) do
        if mods:contains(id) then return true end
    end
    return false
end

function ATR.factorFor(class, action)
    ATR.conflictBlocked = hasConflict()
    local key = ATR.optionKey(class, action)
    local options = SandboxVars and SandboxVars.ActionTimeReducer
    if not key or ATR.conflictBlocked then return 1 end
    local multiplayer = (isClient and isClient()) or (isServer and isServer())
    -- Java packets own these MP deadlines, independently of Lua action maxTime.
    if (class == ISBuildAction or class == ISInventoryTransferAction)
        and multiplayer then return 1 end
    local reduction = options and options[key]
    -- The SP sandbox editor updates native options without refreshing SandboxVars.
    if not multiplayer and getSandboxOptions then
        local nativeOption = getSandboxOptions():getOptionByName("ActionTimeReducer." .. key)
        if nativeOption then reduction = nativeOption:getValue() end
    end
    if type(reduction) ~= "number" or reduction ~= reduction
        or reduction == math.huge or reduction == -math.huge then return 1 end
    return 1 - math.max(0, math.min(95, reduction)) / 100
end

function ATR.scale(duration, factor)
    if type(duration) ~= "number" or duration ~= duration
        or duration == math.huge or duration == -math.huge or duration <= 1 then return duration end
    return math.max(1, duration * factor)
end

function ATR.prepare(action, class)
    if not action or action._ATR_prepared then return action end
    -- Food and smoking share a constructor which fills item after allocation.
    -- Resolve lazily on either duration query (server) or create (client/SP).
    if class == ISEatFoodAction and not action.item then
        if not action._ATR_deferredDuration then
            action._ATR_deferredDuration = action.getDuration
            action.getDuration = function(self, ...)
                if not self.item then return self._ATR_deferredDuration(self, ...) end
                ATR.prepare(self, class)
                return self:getDuration(...)
            end
        end
        return action
    end
    if action._ATR_deferredDuration then
        action.getDuration = action._ATR_deferredDuration
        action._ATR_deferredDuration = nil
    end
    local factor = ATR.factorFor(class, action)
    if factor == 1 then return action end
    action._ATR_prepared = true
    action._ATR_factor = factor
    action._ATR_class = class
    local originalDuration = action.getDuration
    if type(originalDuration) == "function" then
        local stored = usesStoredDuration(class, originalDuration)
        action.getDuration = function(self, ...)
            -- Calculated getters must see fields assigned after the constructor's
            -- first query (e.g. metal barricades). Preserve their native queries.
            if not stored then return ATR.scale(originalDuration(self, ...), factor) end
            -- Only maxTime-backed getters need caching to avoid shortening their
            -- already shortened result again at create/server execution.
            if not self._ATR_durationCached then
                local duration = originalDuration(self, ...)
                self._ATR_nativeDuration = duration
                self._ATR_scaledDuration = ATR.scale(duration, factor)
                self._ATR_durationCached = true
            end
            return self._ATR_scaledDuration
        end
    end
    for _, decorate in ipairs(ATR.decorators) do decorate(action, class, factor) end
    return action
end

local originalNew = ISBaseTimedAction.new
ISBaseTimedAction.new = function(class, character, ...)
    return ATR.prepare(originalNew(class, character, ...), class)
end

local originalCreate = ISBaseTimedAction.create
function ISBaseTimedAction:create(...)
    -- Build/transfer allocate their own tables; intercept execution, not constructors.
    ATR.prepare(self, getmetatable(self))
    if self._ATR_prepared and not self._ATR_created then
        -- Constructors may apply an instant/disabled/event sentinel AFTER
        -- their initial getter (e.g. vanilla wallpaper build cheat).
        if type(self.maxTime) == "number" and self.maxTime > 1 then
            self.maxTime = self:getDuration()
        end
        self._ATR_created = true
    end
    return originalCreate(self, ...)
end

ATR.installed = true
ATR.conflictBlocked = hasConflict()
ATR.version = "0.5.1"
if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(function() ATR.conflictBlocked = hasConflict() end)
end
