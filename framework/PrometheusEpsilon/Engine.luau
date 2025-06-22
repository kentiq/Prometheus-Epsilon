-- Prometheus Epsilon
-- Author: Kentiq
--
-- Version: 1.0.0-ALPHA
--
-- Prometheus Epsilon is a server-side orchestration framework for Roblox.
-- It is designed to build scalable, event-driven, and maintainable game architectures
-- through a powerful, service-oriented paradigm.

--!strict
--!optimize 2

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Prometheus Epsilon Core Dependencies
local PE_Promise = require(script.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Lib.Utility)

-- Canon Dependencies
local Canons = {
    Scribe = require(script.Parent.Canons.Scribe),
    Codex = require(script.Parent.Canons.Codex),
    EventBus = require(script.Parent.Canons.EventBus),
    Scheduler = require(script.Parent.Canons.Scheduler),
    Registry = require(script.Parent.Canons.Registry),
    Catalyst = require(script.Parent.Canons.Catalyst),
    KnowledgeGraph = require(script.Parent.Canons.KnowledgeGraph),
    PolicyEnforcer = require(script.Parent.Canons.PolicyEnforcer),
    Telemetry = require(script.Parent.Canons.Telemetry),
    StateManager = require(script.Parent.Canons.StateManager),
    SelfReflectionSimulator = require(script.Parent.Canons.SelfReflectionSimulator),
}

-- Constants
local PROMETHEUS_EPSILON_SIGNATURE = "PrometheusEpsilon"

-- [[ PROMETHEUS_EPSILON_ENGINE - ORCHESTRATOR ]]
local PrometheusEpsilon_Engine = {
    _epsilonVersion = "1.0.0-ALPHA",
    _cycleCount = 0,
    _engineState = "DORMANT", -- DORMANT, INITIALIZING, ACTIVE, SHUTTING_DOWN, HALTED
    _canons = {}, -- Instances of functional Canons
    _essences = {}, -- Instances of Cognitive Essences

    -- Direct references to key Canons for the Engine itself
    _scribe = nil,
    _codex = nil,
    _eventBus = nil,
    _scheduler = nil,
    _registry = nil,
    _catalyst = nil,

    _isEngineActive = false,
    _lastActivationTime = 0,
    _lastShutdownTime = 0,
}
PrometheusEpsilon_Engine.__index = PrometheusEpsilon_Engine

PrometheusEpsilon_Engine.DEFAULT_ENGINE_CONFIG = {
    Scribe = { MinSeverity = "INFO", MaxHistory = 2000 },
    Scheduler = { QuantumMs = 10 },
    Registry = { ServiceWaitTimeoutMs = 15000 },
    Catalyst = { AutoActivateInitializedEssences = true },
    Essences = {
        Default = {}
    }
}

function PrometheusEpsilon_Engine:Initialize(userConfig, essenceBlueprints, essenceRootPath)
    if self._engineState ~= "DORMANT" then return PE_Promise.Reject("Engine already initialized or active.") end
    self._engineState = "INITIALIZING"; self._cycleCount = self._cycleCount + 1
    
    -- Set global reference for modules with temporary dependencies
    _G.PrometheusEpsilonEngineInstance = self
    
    self._codex = Canons.Codex
    local mergedConfig = PE_Utility.MergeTables(self.DEFAULT_ENGINE_CONFIG, userConfig or {})
    self._codex:Initialize(mergedConfig, self.DEFAULT_ENGINE_CONFIG)

    self._scribe = Canons.Scribe
    self._scribe:Initialize(self._codex)
    self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Prometheus Epsilon Engine V%s Initializing (Cycle %d)...", self._epsilonVersion, self._cycleCount)

    local canonClasses = { Canons.EventBus, Canons.Scheduler, Canons.Registry, Canons.Catalyst,
                           Canons.KnowledgeGraph, Canons.PolicyEnforcer, Canons.Telemetry,
                           Canons.StateManager, Canons.SelfReflectionSimulator }
    local initPromises = {}
    
    -- Manually add the core canons first
    self._canons[Canons.Scribe.Name] = Canons.Scribe
    self._canons[Canons.Codex.Name] = Canons.Codex

    for _, CanonClass in ipairs(canonClasses) do
        local canonInstance = CanonClass
        self._canons[CanonClass.Name] = canonInstance
        self["_"..string.lower(CanonClass.Name)] = canonInstance
        
        local deps = {self._codex, self._scribe, self._registry, self._scheduler, self._eventBus}
        table.insert(initPromises, canonInstance:Initialize(unpack(deps)))
    end

    return PE_Promise.All(initPromises):Then(function()
        self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "All Canons initialized.")
        if self._catalyst and essenceBlueprints then
            return self._catalyst:LoadEssenceBlueprints(essenceBlueprints, essenceRootPath)
        else return PE_Promise.Resolve(true) end
    end):Then(function()
        self._engineState = "INITIALIZED"; self._isEngineActive = false;
        self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Engine Initialized successfully.")
        if self._eventBus then self._eventBus:Publish("Engine.Initialized", {version=self._epsilonVersion, cycle=self._cycleCount}) end
        return true
    end):Catch(function(err)
        if self._scribe then self._scribe:Fatal(PROMETHEUS_EPSILON_SIGNATURE, "ENGINE INITIALIZATION FAILED: %s", tostring(err):sub(1,500))
        else print("ENGINE INITIALIZATION FAILED (Scribe not up):", err) end
        self._engineState = "INIT_FAILED"; self._isEngineActive = false;
        return PE_Promise.Reject(err)
    end)
end

function PrometheusEpsilon_Engine:Activate()
    if self._engineState ~= "INITIALIZED" then return PE_Promise.Reject("Engine not in INITIALIZED state.") end
    self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Activating Engine...")
    self._engineState = "ACTIVATING"; self._isEngineActive = true; self._lastActivationTime = PE_Utility.PreciseTime();

    local activationPromises = {}
    if self._catalyst then
        local essenceIdsToInit = {}
        for id, bp in pairs(self._catalyst._essenceBlueprints or {}) do if bp.enabled then table.insert(essenceIdsToInit, id) end end
        if #essenceIdsToInit > 0 then
            self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Instantiating and initializing %d enabled essences...", #essenceIdsToInit)
            table.insert(activationPromises, self._catalyst:InstantiateAndInitializeEssences(essenceIdsToInit))
        end
    end
    
    return PE_Promise.All(activationPromises):Then(function(results)
        local initializedEssences = {}
        if results and results[1] then
            for _, res in ipairs(results[1]) do
                if type(res)=="table" and res.id then
                    table.insert(initializedEssences, res)
                end
            end
        end

        if self._codex:Get("Catalyst.AutoActivateInitializedEssences", true) and #initializedEssences > 0 then
            self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Auto-activating %d initialized essences...", #initializedEssences)
            local autoActivatePromises = {}
            for _, essenceInstance in ipairs(initializedEssences) do table.insert(autoActivatePromises, essenceInstance:Activate()) end
            return PE_Promise.All(autoActivatePromises)
        else return PE_Promise.Resolve(true) end
    end):Then(function()
        self._engineState = "ACTIVE"
        self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Engine Activated and Running.")
        if self._eventBus then self._eventBus:Publish("Engine.Activated", {}) end
        return true
    end):Catch(function(err)
        self._scribe:Fatal(PROMETHEUS_EPSILON_SIGNATURE, "ENGINE ACTIVATION FAILED: %s", tostring(err):sub(1,500))
        self._engineState = "ACTIVATION_FAILED"; self._isEngineActive = false;
        return PE_Promise.Reject(err)
    end)
end

function PrometheusEpsilon_Engine:Shutdown(reason)
    if self._engineState == "SHUTTING_DOWN" or self._engineState == "HALTED" then return PE_Promise.Resolve(true) end
    self._scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Engine Shutdown initiated. Reason: %s", reason or "N/A")
    self._engineState = "SHUTTING_DOWN"; self._isEngineActive = false; self._lastShutdownTime = PE_Utility.PreciseTime();

    local shutdownPromises = {}
    if self._catalyst and self._catalyst.Shutdown then table.insert(shutdownPromises, self._catalyst:Shutdown()) end
    
    local canonsToShutdown = { self._scheduler, self._eventBus, self._registry,
                               self._canons.SelfReflectionSimulator, self._canons.StateManager,
                               self._canons.Telemetry, self._canons.PolicyEnforcer, self._canons.KnowledgeGraph }

    for _, canon in ipairs(canonsToShutdown) do
        if canon and canon.Shutdown then
            table.insert(shutdownPromises, canon:Shutdown())
        end
    end

    return PE_Promise.All(shutdownPromises):Then(function()
        if self._scribe and self._scribe.Shutdown then return self._scribe:Shutdown() else return PE_Promise.Resolve(true) end
    end):Then(function()
        if self._codex and self._codex.Shutdown then return self._codex:Shutdown() else return PE_Promise.Resolve(true) end
    end):Then(function()
        self._engineState = "HALTED"
        local scribe = self._scribe
        if scribe then scribe:Info(PROMETHEUS_EPSILON_SIGNATURE, "Engine Halted.")
        else print(PROMETHEUS_EPSILON_SIGNATURE.." Engine Halted (Scribe was already down).") end
        -- Clear global reference on halt
        _G.PrometheusEpsilonEngineInstance = nil
        return true
    end):Catch(function(err)
        if self._scribe then self._scribe:Fatal(PROMETHEUS_EPSILON_SIGNATURE, "ENGINE SHUTDOWN FAILED: %s", tostring(err):sub(1,500))
        else print("ENGINE SHUTDOWN FAILED (Scribe not up):", err) end
        self._engineState = "SHUTDOWN_ERROR";
        return PE_Promise.Reject(err)
    end)
end

function PrometheusEpsilon_Engine:GetCanon(interfaceNameOrCanonName)
    for name, canon in pairs(self._canons) do
        if canon.Name == interfaceNameOrCanonName or canon.Interface == interfaceNameOrCanonName then
            return canon
        end
    end
    -- Fallback for direct access via _name
    if self["_"..string.lower(interfaceNameOrCanonName)] then
        return self["_"..string.lower(interfaceNameOrCanonName)]
    end
    return nil
end

return PrometheusEpsilon_Engine 