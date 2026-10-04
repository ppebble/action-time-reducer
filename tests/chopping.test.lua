local options = SandboxVars.ActionTimeReducer
options.ChopTreeAction = 30
local originalEmulate = emulateAnimEvent
local calls = {}
emulateAnimEvent = function(netAction, period, event)
    calls[#calls + 1] = {netAction, period, event}
end
local axe = {setJobType = function() end, setJobDelta = function() end}
local chopper = {
    getPrimaryHandItem = function() return axe end,
    isTimedActionInstant = function() return false end,
    getVariableFloat = function() return 0.8 end,
}
local action = ISChopTreeAction:new(chopper, {})
action.netAction = {}
check(action:getDuration() == -1, "chopping remains event-controlled")
action:serverStart()
check(calls[1][2] == 1050 and calls[1][3] == "ChopTree", "native server chopping interval reduced")
local registeredEmulate = emulateAnimEvent
local animation, variable, speed
action.setActionAnim = function(self, value) animation = value end
action.setAnimVariable = function(self, name, value) variable, speed = name, value end
action.setOverrideHandModels = function() end
local originalText, originalAnims = getText, CharacterActionAnims
getText = function(text) return text end
CharacterActionAnims = {Chop_tree = "chop_tree"}
action:start()
check(animation == "ATR_ChopTree", "use owned animation node, not read-only native speed slot")
check(variable == "ATR_ChopTreeSpeed" and type(speed) == "string",
    "writable action variable uses native Java string overload")
check(math.abs(tonumber(speed) - 0.8 / 0.7) < 0.00001, "native tool/profession animation speed retained")
check(ISChopTreeAction.animEvent == action.animEvent and ISChopTreeAction.complete == action.complete,
    "original damage, consumption and completion handlers preserved")
check(emulateAnimEvent == registeredEmulate, "global scheduling function restored")

local failing = ISBaseTimedAction.new(ISChopTreeAction, chopper)
failing.netAction = {}
-- Exercise restoration when the ORIGINAL scheduler throws.
emulateAnimEvent = function() error("scheduler failure") end
local throwing = emulateAnimEvent
local ok = pcall(function() failing:serverStart() end)
check(not ok and emulateAnimEvent == throwing, "scheduler restored after native failure")
emulateAnimEvent = originalEmulate
getText, CharacterActionAnims = originalText, originalAnims
options.ChopTreeAction = 50
print("PASS native chopping scheduling and animation contract; visual proof pending")
