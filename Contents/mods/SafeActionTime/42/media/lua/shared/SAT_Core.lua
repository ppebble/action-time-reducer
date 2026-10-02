require "TimedActions/ISBaseTimedAction"

SafeActionTime = SafeActionTime or {}
local SAT = SafeActionTime
if SAT.installed then return end

local conflicts = {
    "TwisTonFireFasterActions", "yxjs_FasterAction", "FasterActionsB42",
    "b42FasterActions", "vac_mod_b42_15",
}

local function hasConflict()
    if not getActivatedMods then return false end
    local mods = getActivatedMods()
    if not mods then return false end
    for _, id in ipairs(conflicts) do
        if mods:contains(id) then return true end
    end
    return false
end

local function category(class)
    -- Exact class identity excludes derived mod actions, even with a reused Type.
    if class == ISCraftAction or class == ISHandcraftAction then return "Crafting" end
    if class == ISDismantleAction then return "Dismantling" end
end

local function speedFor(class)
    local group = category(class)
    local options = SandboxVars and SandboxVars.SafeActionTime
    -- Missing/unsynchronised sandbox state must not silently enable acceleration.
    if not group or not options or options.Enabled ~= true or options[group] ~= true then
        return 1
    end
    if hasConflict() then return 1 end
    local percent = options.SpeedPercent
    if type(percent) ~= "number" or percent ~= percent or percent == math.huge or percent == -math.huge then
        return 1
    end
    return math.max(100, math.min(400, percent)) / 100
end

local function scale(duration, speed)
    -- Keep instant, indefinite/event-driven and invalid values untouched.
    if type(duration) ~= "number" or duration ~= duration or duration == math.huge or duration == -math.huge then
        return duration
    end
    if duration <= 1 then return duration end
    return math.max(1, duration / speed)
end

local originalNew = ISBaseTimedAction.new
ISBaseTimedAction.new = function(class, character, ...)
    local action = originalNew(class, character, ...)
    local speed = speedFor(class)
    if not action or speed == 1 or action._SAT_durationWrapped then return action end
    local originalDuration = action.getDuration
    if type(originalDuration) ~= "function" then return action end

    -- Both constructors and server NetTimedAction call this instance-local method.
    -- Recompute the ORIGINAL duration each time; never divide a stored result again.
    -- Snapshot the multiplier per action. Live reconfiguration while queued is unsupported.
    action.getDuration = function(self, ...)
        return scale(originalDuration(self, ...), speed)
    end
    action._SAT_durationWrapped = true
    return action
end

SAT.installed = true
SAT.version = "0.1.0"
