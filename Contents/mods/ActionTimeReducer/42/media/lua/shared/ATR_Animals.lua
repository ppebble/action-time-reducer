require "TimedActions/Animals/ISMilkAnimal"
require "TimedActions/Animals/ISShearAnimal"
require "TimedActions/Animals/ISHutchCleanFloor"
require "TimedActions/Animals/ISHutchCleanNest"
require "TimedActions/Animals/ISGiveWaterToAnimal"
require "TimedActions/Animals/ISGatherBloodFromAnimal"

ActionTimeReducer = ActionTimeReducer or {}
local ATR = ActionTimeReducer
if ATR.animalsInstalled then return end
ATR.decorators = ATR.decorators or {}

local function intervalField(class)
    if class == ISMilkAnimal or class == ISShearAnimal or class == ISGatherBloodFromAnimal then
        return "timePerLiter"
    end
    if class == ISHutchCleanFloor or class == ISHutchCleanNest then return "timePerDirt" end
    if class == ISGiveWaterToAnimal then return "timePerUse" end
end

local function pack(...) return { n = select("#", ...), ... } end

local function wrapInterval(action, method, field, factor)
    local original = action[method]
    if type(original) ~= "function" then return end
    action[method] = function(self, ...)
        local interval = self[field]
        if type(interval) ~= "number" or interval <= 0 or interval ~= interval
            or interval == math.huge then
            return original(self, ...)
        end
        -- Constructors initialise these fields AFTER the shared base allocator.
        -- Change only the cadence during the original call. Keeping the stored
        -- interval vanilla avoids applying the generic duration factor twice.
        self[field] = math.max(1, interval * factor)
        local result = pack(pcall(original, self, ...))
        self[field] = interval
        if not result[1] then error(result[2]) end
        return unpack(result, 2, result.n)
    end
end

table.insert(ATR.decorators, function(action, class, factor)
    local field = intervalField(class)
    if not field or factor >= 1 or factor <= 0 or action._ATR_animalWrapped then return end
    -- Multiplayer schedules the original authoritative event; singleplayer
    -- uses the original update timer. Production, XP, depletion and stopping
    -- remain exclusively in the native handlers.
    wrapInterval(action, "serverStart", field, factor)
    wrapInterval(action, "update", field, factor)
    action._ATR_animalWrapped = true
end)

ATR.animalsInstalled = true
