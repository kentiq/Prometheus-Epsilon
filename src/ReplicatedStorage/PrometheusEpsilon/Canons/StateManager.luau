--!strict

local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local DataStoreService = game:GetService("DataStoreService")

local Canon_StateManager = {
	Interface = "IPrometheusEpsilonStateManager",
	Name = "StateManager",
	_dataStore = nil,
	_scribe = nil,
}

function Canon_StateManager:Initialize(codex, scribe)
	self._scribe = scribe:GetRealmLogger(self.Name)
	local dataStoreName = codex:Get("StateManager.DataStoreName", "PrometheusEpsilon_DefaultStore")

	local success, dataStore = pcall(function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)

	if not success then
		self._scribe.Error("Failed to get DataStore: %s", tostring(dataStore))
		return PE_Promise.Reject("DataStoreFailure:" .. tostring(dataStore))
	end

	self._dataStore = dataStore
	self._scribe.Info("StateManager Canon initialized. Using DataStore: '%s'", dataStoreName)
	return PE_Promise.Resolve(true)
end

function Canon_StateManager:Shutdown()
	self._scribe.Info("StateManager Canon shutting down.")
	return PE_Promise.Resolve(true)
end

function Canon_StateManager:Save(key, data)
	if not self._dataStore then
		return PE_Promise.Reject("DataStoreNotInitialized")
	end

	return PE_Promise.Wrap(function()
		local s, e = pcall(function()
			local serializedData = PE_Utility.Serialize(data)
			self._dataStore:SetAsync(key, serializedData)
		end)
		if not s then
			self._scribe.Error("Failed to save data for key '%s': %s", tostring(key), tostring(e))
			error(e) -- Propagate error to be caught by Promise.Wrap
		end
		self._scribe.Debug("Data saved for key: %s", tostring(key))
		return true
	end)
end

function Canon_StateManager:Load(key)
	if not self._dataStore then
		return PE_Promise.Reject("DataStoreNotInitialized")
	end

	return PE_Promise.Wrap(function()
		local s, result = pcall(function()
			return self._dataStore:GetAsync(key)
		end)

		if not s then
			self._scribe.Error("Failed to load data for key '%s': %s", tostring(key), tostring(result))
			error(result) -- Propagate error
		end

		if result then
			self._scribe.Debug("Data loaded for key: %s", tostring(key))
			local deserializedData = PE_Utility.Deserialize(result)
			return deserializedData
		else
			self._scribe.Info("No data found for key '%s'. Returning nil.", tostring(key))
			return nil
		end
	end)
end

return Canon_StateManager 