originals = {}
for _, class in ipairs({ISCraftAction, ISHandcraftAction, ISDismantleAction}) do
    originals[class.Type] = {
        new = class.new, getDuration = class.getDuration,
        complete = class.complete, stop = class.stop, perform = class.perform,
        isValid = class.isValid,
    }
end
baseCreate = ISBaseTimedAction.create
baseAdjust = ISBaseTimedAction.adjustMaxTime
