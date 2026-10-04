-- Queue resets reuse one SP inventory action. Each batch must keep the same
-- reduction without changing item validation or the native transfer callback.
local savedTransfer = ISInventoryTransferAction
local savedQueue = ISTimedActionQueue
local savedClient, savedServer = isClient, isServer
ISInventoryTransferAction = {}
local firstItem, secondItem, thirdItem = {}, {}, {}
local pending = {item = secondItem, maxTime = 200}
local created = {item = thirdItem, maxTime = 70, _ATR_created = true}
local nativeQueue = {queue = {pending, created}}
ISTimedActionQueue = {getTimedActionQueue = function() return nativeQueue end}
local calls = 0
local originalCheck = function(self)
    calls = calls + 1
    if #nativeQueue.queue > 0 then
        for _, nextAction in ipairs(nativeQueue.queue) do
            table.insert(self.queueList, {items = {nextAction.item}, time = nextAction.maxTime})
            -- Match the native merge's destructive cleanup.
            nextAction.item = nil
            nextAction._ATR_created = nil
        end
        nativeQueue.queue = {}
    end
    return "native-result"
end
local action = {queueList = {{items = {firstItem}, time = 100}}, checkQueueList = originalCheck}
isClient = function() return false end
isServer = function() return false end
for _, decorate in ipairs(ActionTimeReducer.decorators) do decorate(action, ISInventoryTransferAction, 0.7) end
check(action:checkQueueList() == "native-result", "SP queue preserves native return")
check(action.queueList[1].time == 70, "first batch queue records 30 percent reduction")
check(action.queueList[2].time == 140, "merged raw action receives reduction")
check(action.queueList[3].time == 70, "already created merge is not reduced twice")
action:checkQueueList()
check(action.queueList[2].time == 140 and calls == 2, "repeated queue polling must not compound reduction")
for _, mode in ipairs({"client", "server"}) do
    isClient = function() return mode == "client" end
    isServer = function() return mode == "server" end
    local multiplayer = {checkQueueList = originalCheck}
    for _, decorate in ipairs(ActionTimeReducer.decorators) do decorate(multiplayer, ISInventoryTransferAction, 0.7) end
    check(multiplayer.checkQueueList == originalCheck, "MP transaction authority retained: " .. mode)
end
local derived = {}
local unknown = {checkQueueList = originalCheck}
isClient = function() return false end
isServer = function() return false end
for _, decorate in ipairs(ActionTimeReducer.decorators) do decorate(unknown, derived, 0.7) end
check(unknown.checkQueueList == originalCheck, "derived/unknown transfer class remains unchanged")
ISInventoryTransferAction = savedTransfer
ISTimedActionQueue = savedQueue
isClient, isServer = savedClient, savedServer

-- These fixtures call the installed game's original methods, loaded by the
-- harness. Compare resource results at the same progress after shortening.
if ISFluidTransferAction and ISFluidEmptyAction and ISDrinkFluidAction and ISEatFoodAction then
    local savedFluidContainer, savedInstanceof = FluidContainer, instanceof
    local source = {amount = 10}
    source.getAmount = function(self) return self.amount end
    local target = {amount = 0}
    FluidContainer = {Transfer = function(from, into, amount)
        from.amount = from.amount - amount
        into.amount = into.amount + amount
    end}
    local syncs = 0
    local function container(fluid)
        return {getFluidContainer = function() return fluid end,
            getOwner = function() return {} end, sync = function() syncs = syncs + 1 end}
    end
    instanceof = function() return false end
    local fluidAction = {
        source = container(source), target = container(target),
        sourceStartAmount = 10, amount = 4,
        character = {setMetabolicTarget = function() end},
        getJobDelta = function() return 0.5 end,
    }
    local wasClient = isClient
    isClient = function() return false end
    ISFluidTransferAction.update(fluidAction)
    check(source.amount == 8 and target.amount == 2, "native transfer preserves half-progress amount")
    ISFluidTransferAction.complete(fluidAction)
    check(source.amount == 6 and target.amount == 4, "native transfer completion preserves total amount")
    check(syncs == 4, "native source/target synchronization is retained")
    local emptied = {amount = 4, adjustAmount = function(self, amount) self.amount = amount end}
    local emptyAction = {container = container(emptied), amount = 4}
    ISFluidEmptyAction.updateEmpty(emptyAction, 0.5)
    check(emptied.amount == 2, "native empty preserves partial amount")
    ISFluidEmptyAction.updateEmpty(emptyAction, 1)
    check(emptied.amount == 0, "native empty preserves completion amount")

    local drinkFluid = {ratio = 1}
    drinkFluid.getFilledRatio = function(self) return self.ratio end
    local drinkItem = {syncItemFields = function() end}
    local drinkAction = {item = drinkItem, fluidContainer = drinkFluid,
        startRatio = 1, targetConsumedRatio = 0.5,
        character = {
            getInventory = function() return {contains = function() return true end} end,
            DrinkFluid = function(self, item, fraction)
                drinkFluid.ratio = drinkFluid.ratio * (1 - fraction)
            end,
        }}
    ISDrinkFluidAction.updateEat(drinkAction, 0.5)
    check(drinkFluid.ratio == 0.75, "native drink consumes planned partial ratio")
    ISDrinkFluidAction.updateEat(drinkAction, 1)
    check(drinkFluid.ratio == 0.5, "native drink preserves total requested ratio")
    ISDrinkFluidAction.updateEat(drinkAction, 1)
    check(drinkFluid.ratio == 0.5, "repeated progress does not consume twice")

    local consumed = 0
    local food = {getFullType = function() return "Base.Cigarettes" end,
        getHungerChange = function() return 0 end, getBaseHunger = function() return 0 end}
    local smoker = {item = food, percentage = 1,
        character = {Eat = function(self, item, amount) consumed = consumed + amount end,
            getInventory = function() return {contains = function() return true end} end},
        eat = ISEatFoodAction.eat,
        getJobDelta = function() return 0.5 end}
    ISEatFoodAction.serverStop(smoker)
    check(consumed == 0, "cancelled native cigarette applies no consumption/effects")
    ISEatFoodAction.complete(smoker)
    check(consumed == 1, "native smoking completion still consumes exactly once")
    isClient = wasClient
    FluidContainer, instanceof = savedFluidContainer, savedInstanceof
end
print("PASS inventory batches and native fluid/consumption resource contracts")
