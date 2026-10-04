require "TimedActions/ISChopTreeAction"

ActionTimeReducer = ActionTimeReducer or {}
local ATR = ActionTimeReducer
ATR.decorators = ATR.decorators or {}
if ATR.choppingInstalled then return end

local function pack(...) return { n = select("#", ...), ... } end

table.insert(ATR.decorators, function(action, class, factor)
    if not ISChopTreeAction or class ~= ISChopTreeAction or factor >= 1
        or action._ATR_chopWrapped then return end
    local originalStart = action.start
    action.start = function(self, ...)
        local result = pack(originalStart(self, ...))
        -- Action-owned animation overrides are cleared by vanilla action cleanup.
        -- Keep the original profession/tool speed and multiply only this action.
        local speed = self.character:getVariableFloat("ChopTreeSpeed", 1)
        if type(speed) ~= "number" or speed <= 0 or speed ~= speed then speed = 1 end
        -- Vanilla ChopTreeSpeed is a read-only callback. Use our own node and
        -- writable variable while referencing the original animation clip.
        self:setActionAnim("ATR_ChopTree")
        self:setAnimVariable("ATR_ChopTreeSpeed", tostring(speed / factor))
        return unpack(result, 1, result.n)
    end

    local originalServerStart = action.serverStart
    action.serverStart = function(self, ...)
        local originalEmulate = emulateAnimEvent
        -- serverStart is synchronous in the Lua VM. Scope the transform to the
        -- exact net action and native ChopTree event; restore even on failure.
        emulateAnimEvent = function(netAction, period, event, parameter)
            if netAction == self.netAction and event == "ChopTree" then
                period = math.max(1, math.floor(period * factor))
            end
            return originalEmulate(netAction, period, event, parameter)
        end
        local result = pack(pcall(originalServerStart, self, ...))
        emulateAnimEvent = originalEmulate
        if not result[1] then error(result[2]) end
        return unpack(result, 2, result.n)
    end
    action._ATR_chopWrapped = true
end)

ATR.choppingInstalled = true
