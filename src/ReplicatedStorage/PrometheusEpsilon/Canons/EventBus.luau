local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local Canon_EventBus = { Interface = "IPrometheusEpsilonEventBus", Name = "EventBus"}
Canon_EventBus._subscriptions = {}

function Canon_EventBus:Initialize(codex, scribe)
    self._scribe = scribe:GetRealmLogger(self.Name)
    self._scribe.Info("EventBus Canon initialized.")
    return PE_Promise.Resolve(true)
end

function Canon_EventBus:Shutdown()
    self._scribe.Info("EventBus Canon shutting down.")
    return PE_Promise.Resolve(true)
end

function Canon_EventBus:Publish(topic, payload, options)
    options = options or {}
    local subs = self._subscriptions[topic]
    if not subs then return PE_Promise.Resolve({publishedTo=0}) end

    local deliveryPromises = {}
    -- Use a deep copy to prevent subscribers from modifying the original payload for other subscribers.
    local payloadCopy = PE_Utility.DeepCopy(payload)

    for id, subDetails in pairs(subs) do
        table.insert(deliveryPromises, PE_Promise.Wrap(subDetails.callback, payloadCopy))
    end

    return PE_Promise.All(deliveryPromises):Then(function(results)
        return {publishedTo = #results}
    end)
end

function Canon_EventBus:Subscribe(topic, callback, sourceRealm)
    self._subscriptions[topic] = self._subscriptions[topic] or {}
    local subId = PE_Utility.GenerateID()
    self._subscriptions[topic][subId] = {callback=callback, realm=sourceRealm}
    self._scribe.Debug("New subscription to '%s' from '%s' (ID: %s)", topic, sourceRealm or "N/A", subId)
    return subId
end

function Canon_EventBus:Unsubscribe(subId)
    for topic, subs in pairs(self._subscriptions) do
        if subs[subId] then
            subs[subId] = nil
            self._scribe.Debug("Unsubscribed ID '%s' from '%s'", subId, topic)
            return true
        end
    end
    return false
end

return Canon_EventBus 