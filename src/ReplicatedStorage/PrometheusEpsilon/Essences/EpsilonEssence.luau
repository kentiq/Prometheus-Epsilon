--!strict

-- This is the base class for all cognitive "Essences" within the engine.
-- It manages the lifecycle and provides a sandboxed interface to the engine's core services.
local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local EpsilonEssence_Pragmatic = {}
EpsilonEssence_Pragmatic.__index = EpsilonEssence_Pragmatic

function EpsilonEssence_Pragmatic.New(id, blueprint, catalyst)
    local self = setmetatable({
        id = id, blueprint = PE_Utility.DeepCopy(blueprint), catalystRef = catalyst,
        engine = nil, scribe = nil, state = "CREATED", lastStateChange = 0,
        coreModule = nil, coreAPI = nil, proxiedAPI = nil,
        internalState = {}, -- For the essence's own data
    }, EpsilonEssence_Pragmatic)
    self:_logState("Essence object created.")
    return self
end

function EpsilonEssence_Pragmatic:_logState(reason)
    self.lastStateChange = PE_Utility.PreciseTime()
    if self.scribe then
        self.scribe.Info("State -> %s. Reason: %s", self.state, reason)
    elseif _G.PrometheusEpsilonEngineInstance and _G.PrometheusEpsilonEngineInstance._scribe then
        -- Fallback to global scribe if essence's own scribe is not yet initialized
        _G.PrometheusEpsilonEngineInstance._scribe:Info("Essence:"..self.id, "State -> %s. Reason: %s", self.state, reason)
    end
end

function EpsilonEssence_Pragmatic:Initialize()
    self.state = "INITIALIZING"; self:_logState("Initialization started.")
    self.engine = self.catalystRef:_createEngineInterface(self)
    self.scribe = self.engine.Scribe

    local scriptPath = self.blueprint.scriptPath
    if not scriptPath then
        self.scribe.Error("Blueprint missing scriptPath!")
        self.state="INIT_FAILED"
        return PE_Promise.Reject("MissingScriptPath")
    end
    
    local rootPath = self.catalystRef:_getEssenceRootPath()
    if not rootPath then
        self.scribe.Error("Catalyst root path for essences not set!")
        self.state="INIT_FAILED"
        return PE_Promise.Reject("NoRootPathForEssences")
    end
    
    local moduleScript = rootPath:FindFirstChild(scriptPath, true)
    if not moduleScript or not moduleScript:IsA("ModuleScript") then
        self.scribe.Error("ModuleScript not found at: %s", scriptPath)
        self.state="INIT_FAILED"
        return PE_Promise.Reject("ModuleNotFound:"..scriptPath)
    end

    local s, requiredModule = xpcall(require, debug.traceback, moduleScript)
    if not s or type(requiredModule) ~= "table" then
        self.scribe.Error("Failed to require or invalid module from %s: %s", scriptPath, tostring(requiredModule):sub(1,200))
        self.state="INIT_FAILED"
        return PE_Promise.Reject("ModuleRequireFail")
    end
    self.coreModule = moduleScript; self.coreAPI = requiredModule;
    self:_createAPIProxy()

    self.scribe.Info("Core logic loaded and proxied.")
    if self.proxiedAPI.OnInitialize then
        self.state = "INITIALIZING_LOGIC"; self:_logState("Calling OnInitialize.")
        return PE_Promise.Wrap(self.proxiedAPI.OnInitialize, self.engine, self.blueprint.config or {})
            :Then(function()
                self.state="INITIALIZED"; self:_logState("OnInitialize successful.")
                return self
            end,
            function(err)
                self.scribe.Error("OnInitialize failed: %s", tostring(err):sub(1,200))
                self.state="INIT_FAILED"
                return PE_Promise.Reject(err)
            end)
    else
        self.state = "INITIALIZED"; self:_logState("No OnInitialize method.")
        return PE_Promise.Resolve(self)
    end
end

-- The proxy ensures that all calls to the essence's API are logged
-- and can be subjected to policy checks in the future.
function EpsilonEssence_Pragmatic:_createAPIProxy()
    self.proxiedAPI = {}
    local essenceSelf = self
    setmetatable(self.proxiedAPI, {
        __index = function(_, key)
            local func = essenceSelf.coreAPI[key]
            if type(func) == "function" then
                return function(...)
                    essenceSelf.scribe.Trace("API CALL: %s.%s", essenceSelf.id, key)
                    -- Conceptual policy check example
                    if essenceSelf.engine.Policy and essenceSelf.engine.Policy.CanExecuteAPICall then -- Assuming PolicyEnforcer has this method
                        local allowed, reason = essenceSelf.engine.Policy:CanExecuteAPICall(essenceSelf.id, key, {...})
                        if not allowed then
                            essenceSelf.scribe.Warn("Policy denied call to %s.%s: %s", essenceSelf.id, key, reason or "PolicyViolation")
                            return nil -- Or throw an error / return a rejected promise
                        end
                    end
                    return func(essenceSelf.coreAPI, ...) -- Pass original API table as self, then actual args
                end
            else
                return func
            end
        end
    })
end

function EpsilonEssence_Pragmatic:Activate()
    if self.state ~= "INITIALIZED" then
        self.scribe.Warn("Cannot activate, not INITIALIZED.")
        return PE_Promise.Reject("NotInInitializedState")
    end
    self.state = "ACTIVATING"; self:_logState("Activation started.")
    if self.proxiedAPI.OnActivate then
        return PE_Promise.Wrap(self.proxiedAPI.OnActivate, self.engine)
            :Then(function()
                self.state="ACTIVE"; self:_logState("OnActivate successful.")
                return self
            end,
            function(err)
                self.scribe.Error("OnActivate failed: %s", tostring(err):sub(1,200))
                self.state="ACTIVATION_FAILED"
                return PE_Promise.Reject(err)
            end)
    else
        self.state = "ACTIVE"; self:_logState("No OnActivate method.")
        return PE_Promise.Resolve(self)
    end
end

function EpsilonEssence_Pragmatic:Shutdown(reason)
    self.state = "SHUTTING_DOWN"; self:_logState("Shutdown initiated: " .. (reason or "N/A"))
    if self.proxiedAPI and self.proxiedAPI.OnShutdown then
        return PE_Promise.Wrap(self.proxiedAPI.OnShutdown, self.engine, reason)
            :Then(function()
                self.state="SHUTDOWN"; self:_logState("OnShutdown successful.")
                return true
            end,
            function(err)
                self.scribe.Error("OnShutdown failed: %s", tostring(err):sub(1,200))
                self.state="SHUTDOWN_FAILED"
                return PE_Promise.Reject(err)
            end)
    else
        self.state = "SHUTDOWN"; self:_logState("No OnShutdown method.")
        return PE_Promise.Resolve(true)
    end
end

return EpsilonEssence_Pragmatic 