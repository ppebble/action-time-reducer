-- Executed against the installed SaucedCarts action, loaded AFTER ATR_Core.
local ATR = ActionTimeReducer
local savedMods, savedOptions, savedNative = activeMods, SandboxVars.ActionTimeReducer, getSandboxOptions
activeMods = {SaucedCarts = true}
SandboxVars.ActionTimeReducer = {CartTransfer = 30, InventoryTransfer = 0}
getSandboxOptions = nil
local nativeNew, nativePerform, nativeStop = ISCartTransferAction.new, ISCartTransferAction.perform, ISCartTransferAction.stop
local function make(time, direction)
    return ISCartTransferAction:new(character, {}, {}, {}, direction or "in", {}, time)
end
for _, direction in ipairs({"in", "out"}) do
    local action = make(100, direction)
    check(action.maxTime == 100, "cart constructor retains native calculation")
    check(action:getDuration() == 70, "cart duration query reduced on " .. TEST_MODE)
    action:create()
    check(action.maxTime == 70, "cart create receives reduced duration")
    action:create()
    check(action:getDuration() == 70 and action.maxTime == 70, "cart reduction does not compound")
    check(action.perform == nativePerform and action.stop == nativeStop, "cart lifecycle untouched")
end
check(ISCartTransferAction.new == nativeNew, "cart constructor untouched")
check(ATR.factorFor(ISInventoryTransferAction) == 1, "cart setting cannot accelerate vanilla transfer")
SandboxVars.ActionTimeReducer.CartTransfer = 0
SandboxVars.ActionTimeReducer.InventoryTransfer = 90
local disabled = make(100)
disabled:create()
check(disabled.maxTime == 100 and not disabled._ATR_prepared, "cart zero ignores normal transfer setting")
SandboxVars.ActionTimeReducer.CartTransfer = 30
activeMods = {}
local inactive = make(100)
inactive:create()
check(inactive.maxTime == 100 and not inactive._ATR_prepared, "inactive cart mod fails closed")
activeMods.SaucedCarts = true
local class = ISCartTransferAction
ISCartTransferAction = nil
check(ATR.optionKey(class) == nil, "missing cart class fails closed")
ISCartTransferAction = class
local derived = class:derive("UnreviewedCartSubclass")
check(ATR.optionKey(derived) == nil, "cart subclasses are not accelerated")
activeMods.TwisTonFireFasterActions = true
check(ATR.factorFor(class) == 1, "cart obeys existing conflict guard")
activeMods.TwisTonFireFasterActions = nil
local instant = make(1)
instant:create()
check(instant.maxTime == 1, "instant cart sentinel retained")
local item = {getActualWeight = function() return 2 end}
local src = character:getInventory()
local dst = {isInCharacterInventory = function() return false end, getType = function() return "cart" end}
local computed = class:new(character, item, src, dst, "in", {})
check(computed.maxTime == 100 and computed:getDuration() == 70, "real cart weight formula scales once")
if TEST_MODE == "singleplayer" then
    getSandboxOptions = function()
        return {getOptionByName = function(self, key)
            if key == "ActionTimeReducer.CartTransfer" then return {getValue = function() return 50 end} end
        end}
    end
    local live = make(100)
    live:create()
    check(live.maxTime == 50, "live native SP cart option overrides stale SandboxVars")
end
activeMods, SandboxVars.ActionTimeReducer, getSandboxOptions = savedMods, savedOptions, savedNative
