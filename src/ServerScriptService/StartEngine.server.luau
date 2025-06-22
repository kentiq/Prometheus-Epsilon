-- StartEngine.server.luau
-- Main entry point for the server-side logic managed by the engine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Wait for the engine module to be available, just in case
local Engine = require(ReplicatedStorage:WaitForChild("PrometheusEpsilon"):WaitForChild("Engine"))
local MyEpsilonEssenceBlueprints = require(ReplicatedStorage:WaitForChild("MyEpsilonEssenceBlueprints"))
local EssencesRoot = ReplicatedStorage:WaitForChild("EpsilonEssences")

-- Custom configuration overrides for the engine
local MyEpsilonEngineConfig = {
    Scribe = { MinSeverity = "DEBUG" }, -- Use DEBUG for development, INFO for production
    Catalyst = { AutoActivateInitializedEssences = true },
}

local MainScribe -- To be initialized after engine init

Engine:Initialize(MyEpsilonEngineConfig, MyEpsilonEssenceBlueprints, EssencesRoot)
	:Then(function()
    -- The Scribe is now available. Let's get a logger for this main script.
		MainScribe = Engine:GetCanon("Scribe"):GetRealmLogger("MAIN")

		MainScribe.Info("Prometheus Epsilon Engine Initialized. Proceeding to Activation.")
		return Engine:Activate()
	end)
	:Then(function()
		MainScribe.Info("Prometheus Epsilon Engine Activated. System is live.")

    -- Example: Get a service provided by an essence after activation
    local knowledgeServicePromise = Engine:GetCanon("Registry"):Get("IEpsilonKnowledgeQueryService", "LATEST")
    
    knowledgeServicePromise:Then(function(service)
				if service and service.Query then
            MainScribe.Info("Querying Epsilon Knowledge Service...")
					local result = service:Query("MeaningOfLife")
            MainScribe.Info("Epsilon Knowledge Service Result: '%s'", result)
				else
					MainScribe.Warn("IEpsilonKnowledgeQueryService not found or does not have Query method.")
				end
			end):Catch(function(err)
				MainScribe.Error("Error getting/using IKnowledgeQueryService: %s", tostring(err))
			end)
	end)
	:Catch(function(err)
    -- If initialization or activation fails, this will be called.
		local scribe = Engine:GetCanon("Scribe")
    if scribe then
        scribe:Fatal("MAIN", "Critical Epsilon Engine Failure: %s", tostring(err):sub(1,1000))
		else
        -- Scribe might not even be up if the failure was very early.
			print("CRITICAL EPSILON ENGINE FAILURE (SCRIBE DOWN):", err)
		end
	end)

-- Ensure a graceful shutdown when the server closes
game:BindToClose(function()
	if Engine and Engine._engineState ~= "HALTED" and Engine._engineState ~= "DORMANT" then
		local scribe = Engine:GetCanon("Scribe")
        if scribe then
            scribe:GetRealmLogger("MAIN").Info("Server shutting down, initiating Epsilon Engine shutdown.")
		end

        -- Attempt to shut down the engine
		local shutdownPromise = Engine:Shutdown("ServerCloseEvent")
        
        -- Give it a few seconds to shut down gracefully
		local timeout = 5
		local start = tick()
        repeat task.wait() until shutdownPromise._state ~= "pending" or tick() - start > timeout

		if shutdownPromise._state == "pending" then
            if scribe then
                scribe:GetRealmLogger("MAIN").Error("Epsilon Engine shutdown timed out.")
			else
				print("Epsilon Engine shutdown timed out.")
			end
		end
	end
end) 