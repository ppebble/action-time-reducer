local options = SandboxVars.ActionTimeReducer
check(ActionTimeReducer.conflictBlocked == false, "server helper starts with an explicit conflict decision")
check(type(gameBootHook) == "function", "server conflict state must refresh at game boot")
for _, names in pairs(ActionTimeReducer.groups) do
    for _, name in ipairs(names) do options[ActionTimeReducer.optionKey(_G[name])] = 50 end
end
local function craft()
    return ISCraftAction:new(character, {}, recipe, inventory, {})
end
local function handcraft()
    return ISHandcraftAction:new(character, recipe, {}, nil, nil, nil, nil, nil, 1, 0)
end
local function dismantle()
    return ISDismantleAction:new(character, {})
end

for _, factory in ipairs({craft, handcraft, dismantle}) do
    local action = factory()
    local original = originals[action.Type].getDuration(action)
    check(action.maxTime == original / 2, "constructor must see half duration")
    for i = 1, 10 do
        check(action:getDuration() == original / 2, "repeated query must not double-scale")
    end
    check(type(rawget(action, "getDuration")) == "function", "server needs instance-local duration")
end
for _, class in ipairs({ISCraftAction, ISHandcraftAction, ISDismantleAction}) do
    for key, value in pairs(originals[class.Type]) do
        check(class[key] == value, "class method changed: " .. key)
    end
end
check(ISBaseTimedAction.create ~= baseCreate, "shared execution boundary must handle raw-table allocators")
check(ISBaseTimedAction.adjustMaxTime == baseAdjust, "must preserve moodles and injury modifiers")

options.CraftAction = 0
check(craft().maxTime == 120, "0 reduction must remain vanilla")
options.CraftAction = 75
check(craft().maxTime == 30, "75 reduction must quarter duration")
options.CraftAction = 9999
check(math.abs(craft().maxTime - 6) < 0.0001, "cap reduction at 95%")
options.CraftAction = 0
check(craft().maxTime == 120, "zero reduction")
for _, invalid in ipairs({"200", false, math.huge, -math.huge}) do
    options.CraftAction = invalid
    check(craft().maxTime == 120, "invalid multiplier must fail closed")
end
options.CraftAction = 0/0
check(craft().maxTime == 120, "NaN multiplier must fail closed")
options.CraftAction = 50
options.Enabled = false
check(craft().maxTime == 60, "obsolete master toggle must not silently disable numeric settings")
options.Enabled = nil
options.CraftAction = 0
check(craft().maxTime == 120, "crafting toggle")
check(dismantle().maxTime == 75, "other category remains enabled")
options.CraftAction = 50
options.DismantleAction = 0
check(dismantle().maxTime == 150, "dismantling toggle")
options.DismantleAction = 50
SandboxVars.ActionTimeReducer = nil
check(craft().maxTime == 120, "missing namespace must remain vanilla")
SandboxVars.ActionTimeReducer = options
SandboxVars = nil
check(craft().maxTime == 120, "missing sandbox must remain vanilla")
SandboxVars = {ActionTimeReducer = options}

for _, id in ipairs({"TwisTonFireFasterActions", "yxjs_FasterAction", "FasterActionsB42", "b42FasterActions", "vac_mod_b42_15"}) do
    activeMods[id] = true
    gameBootHook()
    check(ActionTimeReducer.conflictBlocked == true, "server helper must see boot-time conflict without an action allocation")
    check(craft().maxTime == 120, "known conflict must disable acceleration")
    activeMods[id] = nil
    gameBootHook()
    check(ActionTimeReducer.conflictBlocked == false, "server helper must recover when conflict is absent")
end

local unknown = ISBaseTimedAction:derive("TABAS_Wash")
function unknown:getDuration() return 120 end
check(ISBaseTimedAction.new(unknown, character):getDuration() == 120, "unknown mod action unchanged")
local derived = ISCraftAction:derive("ISCraftAction")
check(ISBaseTimedAction.new(derived, character).getDuration == ISCraftAction.getDuration, "derived class with reused Type excluded")
for _, name in ipairs({"TABAS_TakeShower", "ISFitnessAction", "ISRestAction", "ISMoveablesAction", "ISReloadWeaponAction", "ISAttachItemHotbar"}) do
    local excluded = ISBaseTimedAction:derive(name)
    function excluded:getDuration() return 120 end
    check(ISBaseTimedAction.new(excluded, character):getDuration() == 120, "excluded " .. name)
end

local wrapped = craft()
options.CraftAction = 75
check(wrapped:getDuration() == 60, "active action retains captured multiplier")
check(craft():getDuration() == 30, "new action uses new multiplier")
options.CraftAction = 50
local rawDuration = ISCraftAction.getDuration
for _, duration in ipairs({-1, 0, 1, 1.1, 2, math.huge, -math.huge, "invalid"}) do
    ISCraftAction.getDuration = function() return duration end
    local result = ISBaseTimedAction.new(ISCraftAction, character):getDuration()
    local expected = duration
    if type(duration) == "number" and duration > 1 and duration ~= math.huge then
        expected = math.max(1, duration / 2)
    end
    check(result == expected, "sentinel/minimum duration handling")
end
ISCraftAction.getDuration = function() return nil end
check(ISBaseTimedAction.new(ISCraftAction, character):getDuration() == nil, "nil duration passthrough")
ISCraftAction.getDuration = function() return 0/0 end
local nan = ISBaseTimedAction.new(ISCraftAction, character):getDuration()
check(nan ~= nan, "NaN duration passthrough")
ISCraftAction.getDuration = rawDuration
print("PASS " .. checks .. " checks in " .. TEST_MODE .. " fixture; not live multiplayer proof")
