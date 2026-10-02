check(craft == nil, "fixture locals must remain local")
check(ISCraftAction:new(character, {}, recipe, inventory, {}).maxTime == 60, "reload must not double wrap")
