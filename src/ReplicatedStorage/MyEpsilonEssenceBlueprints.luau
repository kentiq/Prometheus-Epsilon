-- Example Epsilon Essence Blueprint Module
return {
   KnowledgeKeeperEpsilon = {
       enabled = true,
       scriptPath = "KnowledgeKeeperLogic", -- This should be the name of the ModuleScript in the EssencesRoot folder
       config = {
           knowledgeDomain = "RobloxLUA",
           maxEntries = 150,
       },
       providesServices = {
           {interface="IEpsilonKnowledgeQueryService", version="1.0"}
       }
   },

   -- This is a new system-level essence for managing player sessions.
   PlayerSessionManager = {
       enabled = true, -- It must be enabled to listen for players.
       scriptPath = "PlayerSessionManager",
       config = {}, -- No specific config needed for now
   },

   -- This is a template for player essences that will be instantiated on demand by the PlayerSessionManager.
   -- It is disabled by default because it's not meant to be loaded at startup.
   PlayerEssenceTemplate = {
       enabled = false,
       scriptPath = "PlayerEssence",
       config = {
           -- Default values for a new player can go here
           name = "DefaultPlayerName",
           firstLogin = 0,
           stats = {
               logins = 0,
           },
       },
   },
} 