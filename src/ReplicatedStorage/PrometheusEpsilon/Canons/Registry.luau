local PE_Promise = require(script.Parent.Parent.Lib.Promise)

local Canon_Registry = { Interface = "IPrometheusEpsilonRegistry", Name = "Registry" }
Canon_Registry._services = {} -- interfaceName -> { version -> instance }
Canon_Registry._waitList = {} -- interfaceName -> list of promises

function Canon_Registry:Initialize(codex, scribe)
    self._codex = codex -- Store reference to codex to make module self-contained
    self._scribe = scribe:GetRealmLogger(self.Name)
    self._scribe.Info("Registry Canon initialized.")
    return PE_Promise.Resolve(true)
end

function Canon_Registry:Shutdown()
    self._scribe.Info("Registry Canon shutting down.")
    return PE_Promise.Resolve(true)
end

function Canon_Registry:Register(interfaceName, version, instance)
    self._services[interfaceName] = self._services[interfaceName] or {}
    if self._services[interfaceName][version] then
        self._scribe.Warn("Service %s v%s re-registered.", interfaceName, version)
    end
    self._services[interfaceName][version] = instance
    self._scribe.Info("Service %s v%s registered.", interfaceName, version)

    if self._waitList[interfaceName] then
        for _, p in ipairs(self._waitList[interfaceName]) do
            p:_resolve(instance) -- Resolve with first available for simplicity
        end
        self._waitList[interfaceName] = nil
    end
    return PE_Promise.Resolve(true)
end

function Canon_Registry:Get(interfaceName, versionConstraint) -- Simplified: "LATEST" or exact version
    local promise = PE_Promise.New()
    local versions = self._services[interfaceName]
    if versions then
        local instance
        if versionConstraint == "LATEST" or not versionConstraint then
            local highestV = "0"
            for v in pairs(versions) do
                -- Naive version compare, should be improved for production with semantic versioning
                if v > highestV then
                    highestV=v
                end
            end
            instance = versions[highestV]
        else
            instance = versions[versionConstraint]
        end

        if instance then
            promise:_resolve(instance)
        else
            self:_addToWaitlist(interfaceName, promise, versionConstraint)
        end
    else
        self:_addToWaitlist(interfaceName, promise, versionConstraint)
    end
    return promise
end

function Canon_Registry:_addToWaitlist(interfaceName, promise, versionConstraint)
    self._waitList[interfaceName] = self._waitList[interfaceName] or {}
    table.insert(self._waitList[interfaceName], promise)
    -- Use the stored codex reference instead of a global one
    local timeout = self._codex:Get("Registry.ServiceWaitTimeoutMs", 10000)
    promise:SetTimeout(timeout, "ServiceWaitTimeout:"..interfaceName)
    self._scribe.Debug("Service %s (constraint: %s) added to waitlist.", interfaceName, versionConstraint or "any")
end

return Canon_Registry 