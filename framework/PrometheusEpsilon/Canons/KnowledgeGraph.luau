local PE_Promise = require(script.Parent.Parent.Lib.Promise)

local Canon_KnowledgeGraph = {
    Interface = "IPrometheusEpsilonKnowledgeGraph",
    Name = "KnowledgeGraph"
}

function Canon_KnowledgeGraph:Initialize(codex, scribe)
    scribe:GetRealmLogger(self.Name).Info("%s Canon initialized (stub).", self.Name)
    return PE_Promise.Resolve(true)
end

function Canon_KnowledgeGraph:Shutdown()
    local engine = _G.PrometheusEpsilonEngineInstance
    if engine and engine._scribe then
        engine._scribe:GetRealmLogger(self.Name).Info("%s Canon shutting down (stub).", self.Name)
    end
    return PE_Promise.Resolve(true)
end

return Canon_KnowledgeGraph 