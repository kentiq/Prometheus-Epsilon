-- Example Epsilon Essence Logic
--!strict

local KnowledgeKeeper = {}
KnowledgeKeeper.__index = KnowledgeKeeper

-- In a real scenario, this would come from a DataStore or another persistent source.
local myKnowledge = {
    MeaningOfLife = "42, according to a rather advanced computer."
}
local myConfig = {}
local engineInterfaceRef = nil -- Store the engine interface

function KnowledgeKeeper:OnInitialize(engine, config) -- engine is the sandboxed engineInterface
   engineInterfaceRef = engine
   myConfig = config or {}
   engineInterfaceRef.Scribe.Info("KnowledgeKeeperEpsilon Initializing with domain: %s", myConfig.knowledgeDomain)
   
   -- Register this essence as a service provider
   if engineInterfaceRef.Registry.Register then
       engineInterfaceRef.Registry.Register("IEpsilonKnowledgeQueryService", "1.0", self)
       engineInterfaceRef.Scribe.Info("Registered as IEpsilonKnowledgeQueryService v1.0")
   end
   return true
end

function KnowledgeKeeper:OnActivate(engine)
   engineInterfaceRef.Scribe.Info("KnowledgeKeeperEpsilon Activated.")
   self:LoadKnowledge()
   return true
end

function KnowledgeKeeper:OnShutdown(engine, reason)
   engineInterfaceRef.Scribe.Info("KnowledgeKeeperEpsilon Shutting Down. Reason: %s", reason)
   self:SaveKnowledge()
end

-- IEpsilonKnowledgeQueryService method
function KnowledgeKeeper:Query(topic)
   engineInterfaceRef.Scribe.Debug("Query received for topic: %s", topic)
   return myKnowledge[topic] or "This Epsilon Keeper does not have knowledge on that specific topic yet."
end

function KnowledgeKeeper:AddEntry(topic, data)
   if not myConfig.maxEntries or #engineInterfaceRef.Utilities.GetKeys(myKnowledge) < myConfig.maxEntries then
       myKnowledge[topic] = data
       engineInterfaceRef.Scribe.Info("Added Epsilon knowledge: %s", topic)
       return true
   else
       engineInterfaceRef.Scribe.Warn("Epsilon Knowledge base full. Cannot add: %s", topic)
       return false
   end
end

function KnowledgeKeeper:LoadKnowledge()
    engineInterfaceRef.Scribe.Info("Simulating loading Epsilon knowledge for %s...", myConfig.knowledgeDomain)
    -- Let's add some default knowledge for this example
    self:AddEntry("MeaningOfLife", "42, according to a rather advanced computer.")
end

function KnowledgeKeeper:SaveKnowledge()
    engineInterfaceRef.Scribe.Info("Simulating saving Epsilon knowledge for %s...", myConfig.knowledgeDomain)
end

return KnowledgeKeeper 