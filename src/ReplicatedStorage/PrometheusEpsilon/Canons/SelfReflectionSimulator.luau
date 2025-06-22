local PE_Promise = require(script.Parent.Parent.Lib.Promise)

local Canon_SelfReflectionSimulator = {
    Interface = "IPrometheusEpsilonSelfReflectionSimulator",
    Name = "SelfReflectionSimulator"
}

function Canon_SelfReflectionSimulator:Initialize(codex, scribe)
    scribe:GetRealmLogger(self.Name).Info("%s Canon initialized (stub).", self.Name)
    return PE_Promise.Resolve(true)
end

function Canon_SelfReflectionSimulator:Shutdown()
    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then
        engine._scribe:GetRealmLogger(self.Name).Info("%s Canon shutting down (stub).", self.Name)
    end
    return PE_Promise.Resolve(true)
end

return Canon_SelfReflectionSimulator 