-- Standalone cadence contract fixture; the production adapter delegates all
-- native event handlers and never wraps concrete constructors.
if not TEST_ANIMALS_PREPARED then
require = function() end
ActionTimeReducer = { decorators = {} }
checks = 0
function check(value, message)
    checks = checks + 1
    if not value then error(message) end
end
local function nativeClass(field)
    return {
        serverStart = function(self)
            self.scheduledPeriod = self[field] * 20
            self.serverCalls = (self.serverCalls or 0) + 1
            return "native", nil, "result"
        end,
        update = function(self)
            self.timer = self.timer + 1
            if math.floor(self.timer / self[field]) > self.lastTimer then
                self.lastTimer = math.floor(self.timer / self[field])
                self.events = (self.events or 0) + 1
                self.material = self.material - 1
                self.xp = self.xp + 2
            end
        end,
        getDuration = function(self) return self[field] * 10 + 5 end,
    }
end
ISMilkAnimal = nativeClass("timePerLiter")
ISShearAnimal = nativeClass("timePerLiter")
ISGatherBloodFromAnimal = nativeClass("timePerLiter")
ISHutchCleanFloor = nativeClass("timePerDirt")
ISHutchCleanNest = nativeClass("timePerDirt")
ISGiveWaterToAnimal = nativeClass("timePerUse")
TEST_ANIMALS_PREPARED = true
return
end

local decorate = ActionTimeReducer.decorators[1]
check(type(decorate) == "function", "animal decorator must register")
local cases = {
    {ISMilkAnimal, "timePerLiter"}, {ISShearAnimal, "timePerLiter"},
    {ISGatherBloodFromAnimal, "timePerLiter"}, {ISHutchCleanFloor, "timePerDirt"},
    {ISHutchCleanNest, "timePerDirt"}, {ISGiveWaterToAnimal, "timePerUse"},
}
for _, entry in ipairs(cases) do
    local class, field = entry[1], entry[2]
    local action = setmetatable({}, {__index = class})
    decorate(action, class, 0.7)
    -- Matches the shared allocator: native constructor fields arrive later.
    action[field] = 10
    action.timer, action.lastTimer, action.material, action.xp = 0, 0, 100, 0
    local first, middle, last = action:serverStart()
    check(first == "native" and middle == nil and last == "result", "native return tuple preserved")
    check(action.scheduledPeriod == 140, "authoritative event cadence scales")
    check(action[field] == 10, "stored interval unchanged after scheduling")
    check(action:getDuration() == 105, "adapter does not double-scale generic duration")
    for i = 1, 70 do action:update() end
    check(action.events == 10, "singleplayer production cadence scales")
    check(action.material == 90 and action.xp == 20, "each event retains native consumption and XP")
    check(action[field] == 10, "stored interval unchanged after update")
    local update = action.update
    decorate(action, class, 0.7)
    check(action.update == update, "decorator is idempotent")
    local unchanged = setmetatable({}, {__index = class})
    decorate(unchanged, class, 1)
    check(rawget(unchanged, "update") == nil, "zero reduction does not install wrappers")
end
local unknown = {Type = "ISMilkAnimal", update = ISMilkAnimal.update}
local excluded = setmetatable({}, {__index = unknown})
decorate(excluded, unknown, 0.7)
check(rawget(excluded, "update") == nil, "same named mod class excluded")
local originalUpdate = ISMilkAnimal.update
ISMilkAnimal.update = function(self)
    check(self.timePerLiter == 7, "error path receives reduced interval")
    error("fixture native failure")
end
local failing = setmetatable({}, {__index = ISMilkAnimal})
decorate(failing, ISMilkAnimal, 0.7)
failing.timePerLiter = 10
local success, message = pcall(failing.update, failing)
check(not success and string.find(message, "fixture native failure"), "native errors propagate")
check(failing.timePerLiter == 10, "interval restores even when native handler errors")
ISMilkAnimal.update = originalUpdate
print("PASS animal cadence " .. checks .. " checks; not live animal or multiplayer proof")
