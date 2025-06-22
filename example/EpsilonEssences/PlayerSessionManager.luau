-- PlayerSessionManager.luau
-- This system-level essence is responsible for managing the lifecycle of player-specific essences.
-- It listens to PlayerAdded and PlayerRemoving events and orchestrates data loading/saving.

--!strict

local PlayerSessionManager = {}
PlayerSessionManager.__index = PlayerSessionManager

local Players = game:GetService("Players")

local engineInterfaceRef = nil
local activePlayerEssences = {} -- [number] -> essenceInstance | Associates UserId with their essence

function PlayerSessionManager:_onPlayerAdded(player: Player)
	local scribe = engineInterfaceRef.Scribe
	scribe.Info("Player '%s' (UserId: %s) has joined. Orchestrating session start...", player.Name, player.UserId)

	local stateManager = engineInterfaceRef.StateManager
	if not stateManager then
		scribe.Error("StateManager not available. Cannot manage player session for %s.", player.Name)
		return
	end

	-- 1. Load player data
	stateManager:Load(player.UserId)
		:Then(function(playerData)
			local isNewPlayer = playerData == nil
			if isNewPlayer then
				scribe.Info("No data found for player %s. Creating new session data.", player.Name)
				playerData = {
					name = player.Name,
					firstLogin = os.time(),
					stats = {
						logins = 1,
					},
				}
			else
				scribe.Info("Data loaded for player %s.", player.Name)
				playerData.stats.logins = (playerData.stats.logins or 0) + 1
			end

			-- 2. Instantiate the PlayerEssence
			local essenceId = "Player_" .. player.UserId
			engineInterfaceRef.InstantiateEssence("PlayerEssenceTemplate", playerData, essenceId)
				:Then(function(playerEssence)
					scribe.Info("PlayerEssence for %s successfully instantiated.", player.Name)
					activePlayerEssences[player.UserId] = playerEssence
				end)
				:Catch(function(err)
					scribe.Error(
						"Failed to instantiate PlayerEssence for %s: %s",
						player.Name,
						tostring(err)
					)
				end)
		end)
		:Catch(function(err)
			scribe.Error(
				"Failed to load data for player %s: %s. They may lose their progress.",
				player.Name,
				tostring(err)
			)
			-- Potentially kick the player or handle the error gracefully
		end)
end

function PlayerSessionManager:_onPlayerRemoving(player: Player)
	local scribe = engineInterfaceRef.Scribe
	scribe.Info("Player '%s' (UserId: %s) is leaving. Orchestrating session end...", player.Name, player.UserId)

	local essenceToSave = activePlayerEssences[player.UserId]
	if not essenceToSave then
		scribe.Warn("No active player essence found for player %s on shutdown. Nothing to save.", player.Name)
		return
	end

	-- 1. Get the latest data from the essence's proxied API
	local dataToSave = essenceToSave.proxiedAPI:GetState()

	-- 2. Save the data
	local stateManager = engineInterfaceRef.StateManager
	stateManager:Save(player.UserId, dataToSave)
		:Then(function()
			scribe.Info("Successfully saved data for player %s.", player.Name)
		end)
		:Catch(function(err)
			scribe.Error("CRITICAL: Failed to save data for player %s: %s", player.Name, tostring(err))
		end)
		:Finally(function()
			-- 3. Shutdown the specific essence
			if essenceToSave.Shutdown then
				essenceToSave:Shutdown("PlayerLeft")
			end
			activePlayerEssences[player.UserId] = nil
		end)
end

function PlayerSessionManager:OnInitialize(engine, config)
	engineInterfaceRef = engine
	local scribe = engineInterfaceRef.Scribe
	scribe.Info("PlayerSessionManager Initializing.")

	-- Connect to player events for future players
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	-- Handle players who might already be in the game when the script runs
	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	scribe.Info("PlayerSessionManager Initialized and listening for players.")
	return true -- Must return true or a resolving Promise for successful initialization
end

function PlayerSessionManager:OnShutdown(engine, reason)
	engineInterfaceRef.Scribe.Info("PlayerSessionManager Shutting Down. Reason: %s", reason or "N/A")
	-- In a real scenario, you might want to loop through all activePlayerEssences and trigger a save.
end

return PlayerSessionManager 