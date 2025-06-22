-- PlayerEssence.luau
-- This essence represents a single player's data and logic.
-- It is dynamically instantiated by the PlayerSessionManager.

--!strict

local PlayerEssence = {}
PlayerEssence.__index = PlayerEssence

local engineInterfaceRef = nil
local state = {} -- This table holds all the player's data

-- This is the API this essence might expose to other essences if needed
local serviceAPI = {}

function PlayerEssence:OnInitialize(engine, config)
	engineInterfaceRef = engine
	state = config or {} -- The initial data is passed as config

	engine.Scribe.Info("PlayerEssence for '%s' initialized.", state.name)
	return true
end

function PlayerEssence:OnActivate(engine)
	engine.Scribe.Info("PlayerEssence for '%s' activated.", state.name)
	return true
end

function PlayerEssence:OnShutdown(engine, reason)
	engine.Scribe.Info("PlayerEssence for '%s' shutting down. Reason: %s", state.name, reason or "N/A")
end

-- This function is crucial for the StateManager to retrieve the latest data.
function PlayerEssence:GetState()
	return state
end

return PlayerEssence 