-- The native SP sandbox editor changes SandboxOptions without calling toLua().
-- Keep its backing settings separate from the stale SandboxVars table.
local savedAccessor = getSandboxOptions
local savedClient, savedServer = isClient, isServer
local savedValues = SandboxVars.ActionTimeReducer
local backing = {CraftAction = 30, EatFoodAction = 30, InventoryTransfer = 40}
SandboxVars.ActionTimeReducer = {CraftAction = 0, EatFoodAction = 0, InventoryTransfer = 0}
getSandboxOptions = function()
    return {getOptionByName = function(self, name)
        local group = string.sub(name, string.len("ActionTimeReducer.") + 1)
        if backing[group] == nil then return nil end
        return {getValue = function() return backing[group] end}
    end}
end
isClient = function() return false end
isServer = function() return false end
check(math.abs(ActionTimeReducer.factorFor(ISCraftAction) - 0.7) < 0.0001, "SP must read edited native setting despite stale Lua zero")
check(math.abs(ActionTimeReducer.factorFor(ISEatFoodAction) - 0.7) < 0.0001, "food must read live SP setting")
check(math.abs(ActionTimeReducer.factorFor(ISInventoryTransferAction) - 0.6) < 0.0001, "transfer must read live SP setting")
backing.CraftAction = 0
SandboxVars.ActionTimeReducer.CraftAction = 80
check(ActionTimeReducer.factorFor(ISCraftAction) == 1, "SP zero must override stale Lua nonzero")
backing.CraftAction = 50
check(ActionTimeReducer.factorFor(ISCraftAction) == 0.5, "SP next action observes another edit without restart")
backing.CraftAction = false
check(ActionTimeReducer.factorFor(ISCraftAction) == 1, "invalid live option fails closed")
backing.CraftAction = nil
SandboxVars.ActionTimeReducer.CraftAction = 30
check(math.abs(ActionTimeReducer.factorFor(ISCraftAction) - 0.7) < 0.0001, "missing native option retains Lua fallback")
backing.CraftAction = 90
isClient = function() return true end
check(math.abs(ActionTimeReducer.factorFor(ISCraftAction) - 0.7) < 0.0001, "MP client uses server-synchronized Lua setting")
check(ActionTimeReducer.factorFor(ISInventoryTransferAction) == 1, "MP transfer stays Java-owned")
isClient = function() return false end
isServer = function() return true end
check(math.abs(ActionTimeReducer.factorFor(ISCraftAction) - 0.7) < 0.0001, "MP server retains authoritative Lua setting")
getSandboxOptions = savedAccessor
isClient, isServer = savedClient, savedServer
SandboxVars.ActionTimeReducer = savedValues
