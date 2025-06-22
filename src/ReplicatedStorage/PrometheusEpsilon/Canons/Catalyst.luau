local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)
local EpsilonEssence_Pragmatic = require(script.Parent.Parent.Essences.EpsilonEssence)

local Canon_Catalyst = { Interface = "IPrometheusEpsilonCatalyst", Name = "Catalyst" }
Canon_Catalyst._essenceBlueprints = {}
Canon_Catalyst._rootEssencePath = nil

function Canon_Catalyst:Initialize(codex, scribe, registry, scheduler, eventBus)
    self._scribe = scribe:GetRealmLogger(self.Name)
    self._codex = codex
    self._registry = registry
    self._scheduler = scheduler
    self._eventBus = eventBus
    self._engineInterfaceFactory = function(essence) return self:_createEngineInterface(essence) end
    self._scribe.Info("Catalyst Canon initialized.")
    return PE_Promise.Resolve(true)
end

function Canon_Catalyst:Shutdown()
    self._scribe.Info("Catalyst Canon shutting down. Shutting down all essences...")
    local shutdownPromises = {}
    local engine = _G.PrometheusEpsilonEngineInstance
    if engine then
        for id, essence in pairs(engine._essences) do
            if essence.Shutdown then
                table.insert(shutdownPromises, essence:Shutdown("EngineShutdown"))
            end
        end
    end
    return PE_Promise.All(shutdownPromises):Then(function()
        self._scribe.Info("All essences processed for shutdown.")
    end)
end

function Canon_Catalyst:LoadEssenceBlueprints(blueprintsTable, rootPathInstance)
    self._essenceBlueprints = PE_Utility.DeepCopy(blueprintsTable or {})
    self._rootEssencePath = rootPathInstance
    self._scribe.Info("Loaded %d essence blueprints. Root path: %s", #PE_Utility.GetKeys(self._essenceBlueprints), rootPathInstance and rootPathInstance:GetFullName() or "N/A")
    return PE_Promise.Resolve(true)
end

function Canon_Catalyst:InstantiateAndInitializeEssences(essenceIdsToInit)
    local initPromises = {}
    local engine = _G.PrometheusEpsilonEngineInstance

    for _, id in ipairs(essenceIdsToInit) do
        table.insert(initPromises, self:InstantiateEssence(id, nil, "EngineStartup"))
    end

    return PE_Promise.All(initPromises):Then(function(results)
        local successfulEssences = {}
        for _, res in ipairs(results) do
            if res then table.insert(successfulEssences, res) end
        end
        self._scribe.Info(
            "Initialization attempted for %d essences. Successes: %d",
            #essenceIdsToInit,
            #successfulEssences
        )
        return successfulEssences
    end)
end

function Canon_Catalyst:InstantiateEssence(blueprintId, overrideConfig, context, newInstanceId)
    local engine = _G.PrometheusEpsilonEngineInstance
    local EpsilonEssence_Pragmatic = require(script.Parent.Parent.Essences.EpsilonEssence)

    local bp = self._essenceBlueprints[blueprintId]
    local idForInstance = newInstanceId or blueprintId

    if not bp then
        self._scribe.Error("No blueprint found for essence ID: %s. Context: %s", blueprintId, context or "N/A")
        return PE_Promise.Reject("NoBlueprint:" .. blueprintId)
    end

    -- Prevent re-instantiation if an essence with the same ID is already active
    if engine._essences[idForInstance] and context ~= "EngineStartup" then
        self._scribe.Warn("Essence %s already instantiated. Skipping. Context: %s", idForInstance, context or "N/A")
        return PE_Promise.Reject("AlreadyInstantiated:" .. idForInstance)
    end

    -- If there's an override config, merge it over the blueprint's default config
    local finalConfig = bp.config
    if overrideConfig then
        finalConfig = PE_Utility.MergeTables(bp.config, overrideConfig)
    end

    local finalBlueprint = PE_Utility.DeepCopy(bp)
    finalBlueprint.config = finalConfig
    finalBlueprint.id = idForInstance -- Ensure the blueprint passed to the essence has the correct ID

    local essence = EpsilonEssence_Pragmatic.New(idForInstance, finalBlueprint, self)
    engine._essences[idForInstance] = essence

    return essence:Initialize()
end

function Canon_Catalyst:_createEngineInterface(essence) -- Sandboxed access for Essences
    local engine = _G.PrometheusEpsilonEngineInstance
    return {
        EssenceID = essence.id,
        Scribe = engine._scribe:GetRealmLogger("Essence:"..essence.id),
        Codex = { Get = function(p,d) return engine._codex:Get(p,d) end },
        EventBus = {
            Publish = function(t,p,o) return engine._eventBus:Publish(t,p,o) end,
            Subscribe = function(t,cb) return engine._eventBus:Subscribe(t,cb,essence.id) end,
            Unsubscribe = function(sId) return engine._eventBus:Unsubscribe(sId) end
        },
        Scheduler = { Submit = function(f,a,p,o) return engine._scheduler:Submit(f,a,p,o) end },
        Registry = {
            Get = function(iN,vC) return engine._registry:Get(iN,vC) end,
            Register = function(iN,v,inst) return engine._registry:Register(iN,v,inst) end
        }, -- Allow essence to register itself
        -- Expose other Canons carefully if needed
        KnowledgeGraph = engine._canons.KnowledgeGraph,
        Policy = engine._canons.PolicyEnforcer,
        Telemetry = engine._canons.Telemetry,
        StateManager = engine._canons.StateManager,
        RequestEngineShutdown = function(reason)
            engine:Shutdown("EssenceRequest:" .. essence.id .. ":" .. reason)
        end,
        Utilities = {
            GenerateID = PE_Utility.GenerateID,
            PreciseTime = PE_Utility.PreciseTime,
            DeepCopy = PE_Utility.DeepCopy,
            Serialize = PE_Utility.Serialize,
            GetKeys = PE_Utility.GetKeys,
        },
        -- Expose a sandboxed version of the Catalyst's instantiation function
        -- This is a significant architectural decision allowing essences to create other essences.
        InstantiateEssence = function(blueprintId, overrideConfig, newEssenceId)
            return self:InstantiateEssence(blueprintId, overrideConfig, "EssenceRequest:" .. essence.id, newEssenceId)
        end,
    }
end

function Canon_Catalyst:_getEssenceRootPath()
    return self._rootEssencePath
end

return Canon_Catalyst 