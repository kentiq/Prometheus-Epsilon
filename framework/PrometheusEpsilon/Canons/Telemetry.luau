local PE_Promise = require(script.Parent.Parent.Lib.Promise)

local Canon_Telemetry = {
    Interface = "IPrometheusEpsilonTelemetry",
    Name = "Telemetry"
}

function Canon_Telemetry:Initialize(codex, scribe)
    scribe:GetRealmLogger(self.Name).Info("%s Canon initialized (stub).", self.Name)
    return PE_Promise.Resolve(true)
end

function Canon_Telemetry:Shutdown()
    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then
        engine._scribe:GetRealmLogger(self.Name).Info("%s Canon shutting down (stub).", self.Name)
    end
    return PE_Promise.Resolve(true)
end

return Canon_Telemetry 