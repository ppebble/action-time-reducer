ActionTimeReducer = ActionTimeReducer or {}
local ATR = ActionTimeReducer
ATR.decorators = ATR.decorators or {}
if ATR._liquidsInstalled then return end

-- Fluid/fuel/food callbacks already derive quantities from action progress or
-- apply their original target at completion. Shorten duration only: changing
-- their polling intervals as well would needlessly alter resource processing.
local function reducedTime(time, factor)
    if type(time) ~= "number" or time ~= time or time == math.huge or time == -math.huge or time <= 1 then
        return time
    end
    return math.max(1, time * factor)
end

table.insert(ATR.decorators, function(action, class, factor)
    -- MP transaction duration is server-owned and is intentionally untouched.
    if not ISInventoryTransferAction or class ~= ISInventoryTransferAction or isClient() or isServer() then return end
    if action._ATR_transferQueueWrapped then return end
    local original = action.checkQueueList
    if type(original) ~= "function" then return end
    action.checkQueueList = function(self, ...)
        -- Native merging copies later actions' maxTime and then wipes those
        -- actions. Capture any already-created sources before that happens.
        local createdItems = {}
        local queue = ISTimedActionQueue.getTimedActionQueue(self.character)
        if queue and queue.queue then
            for _, pending in ipairs(queue.queue) do
                if pending ~= self and pending._ATR_created and pending.item then
                    createdItems[pending.item] = true
                end
            end
        end
        local result = original(self, ...)
        for _, entry in ipairs(self.queueList or {}) do
            if not entry._ATR_timeScaled then
                if not (entry.items and createdItems[entry.items[1]]) then
                    entry.time = reducedTime(entry.time, factor)
                end
                entry._ATR_timeScaled = true
            end
        end
        return result
    end
    action._ATR_transferQueueWrapped = true
end)

ATR._liquidsInstalled = true
