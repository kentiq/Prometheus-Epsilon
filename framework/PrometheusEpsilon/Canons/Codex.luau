local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local Canon_Codex = { Interface = "IPrometheusEpsilonCodex", Name = "Codex" }
Canon_Codex._defaultConfig = {}
Canon_Codex._userConfig = {}
Canon_Codex._effectiveConfig = {}

function Canon_Codex:Initialize(initialUserConfig, defaultConfig)
    self._defaultConfig = PE_Utility.DeepCopy(defaultConfig or {})
    self._userConfig = PE_Utility.DeepCopy(initialUserConfig or {})
    self._effectiveConfig = PE_Utility.MergeTables(self._defaultConfig, self._userConfig)

    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then engine._scribe:Info(self.Name, "Codex Canon initialized.") end
    return PE_Promise.Resolve(true)
end

function Canon_Codex:Shutdown()
    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then engine._scribe:Info(self.Name, "Codex Canon shutting down.") end
    return PE_Promise.Resolve(true)
end

function Canon_Codex:Get(path, defaultValue)
    local parts = string.split(path, "."); local current = self._effectiveConfig
    for _, part in ipairs(parts) do
        if type(current) == "table" and current[part] ~= nil then current = current[part]
        else return defaultValue end
    end
    return PE_Utility.DeepCopy(current)
end

function Canon_Codex:Set(path, value, source) -- Simplified Set
    local parts = string.split(path, "."); local current = self._userConfig -- Set in user config
    for i=1,#parts-1 do
        local p=parts[i]
        if type(current[p])~="table" then current[p]={} end
        current=current[p]
    end
    current[parts[#parts]] = PE_Utility.DeepCopy(value)
    self._effectiveConfig = PE_Utility.MergeTables(self._defaultConfig, self._userConfig)

    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then engine._scribe:Info(self.Name, "Codex updated. Path: %s by %s", path, source or "Unknown") end
    if engine and engine._eventBus then engine._eventBus:Publish("Engine.Codex.Updated", {path=path, source=source}) end
    return PE_Promise.Resolve(true)
end

return Canon_Codex 