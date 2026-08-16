local AdventureHandoff = {}

function AdventureHandoff.new()
    return {
        characterCreationFinished = false,
    }
end

function AdventureHandoff.markCharacterCreationFinished(state)
    state.characterCreationFinished = true
end

function AdventureHandoff.shouldRecover(state, adventureActive, levelName)
    return state.characterCreationFinished == true
        and adventureActive == true
        and type(levelName) == "string"
        and levelName:match("^SYS_CC_") ~= nil
end

return AdventureHandoff
