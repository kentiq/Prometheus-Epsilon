local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local Canon_Scribe = { Interface = "IPrometheusEpsilonScribe", Name = "Scribe" }
Canon_Scribe.Severity = { TRACE=0, DEBUG=1, INFO=2, WARN=3, ERROR=4, FATAL=5 }
Canon_Scribe._minSeverity = Canon_Scribe.Severity.INFO
Canon_Scribe._logHistory = {}
Canon_Scribe._maxHistory = 1000

function Canon_Scribe:Initialize(codex)
    self._codex = codex
    self._minSeverity = self.Severity[codex:Get("Scribe.MinSeverity", "INFO"):upper()] or self.Severity.INFO
    self._maxHistory = codex:Get("Scribe.MaxHistory", 1000)
    self:Info(self.Name, "Scribe Canon initialized. MinSeverity: %s", codex:Get("Scribe.MinSeverity", "INFO"))
    return PE_Promise.Resolve(true)
end

function Canon_Scribe:Shutdown()
    self:Info(self.Name, "Scribe Canon shutting down.")
    return PE_Promise.Resolve(true)
end

function Canon_Scribe:_log(severity, realm, message, ...)
    if severity < self._minSeverity then return end
    
    local args = {...}
    local formattedMsg = string.format(message, unpack(args))

    local entry = {ts=PE_Utility.PreciseTime(), sev=self:_sevStr(severity), rlm=realm, msg=formattedMsg}
    
    -- Correctly use os.date() to get the current wall-clock time for display.
    -- The high-precision `entry.ts` is still stored for potential performance analysis.
    -- Replacing "%T" with its explicit equivalent to bypass potential environment-specific issues.
    print(string.format("[%s][%s][%s] %s", os.date("%H:%M:%S"), entry.sev, entry.rlm, entry.msg))
    
    table.insert(self._logHistory, 1, entry)
    if #self._logHistory > self._maxHistory then table.remove(self._logHistory) end
end

function Canon_Scribe:_sevStr(sevVal)
    for s,v in pairs(self.Severity) do
        if v==sevVal then return s end
    end
    return "?"
end

for sevName, sevVal in pairs(Canon_Scribe.Severity) do
    Canon_Scribe[sevName:sub(1,1):upper()..sevName:sub(2):lower()] = function(self, realm, msg, ...)
        self:_log(sevVal, realm, msg, ...)
    end
end

function Canon_Scribe:GetRealmLogger(realm)
    local rl={}
    for sN,sV in pairs(self.Severity) do
        local mN=sN:sub(1,1):upper()..sN:sub(2):lower()
        rl[mN]=function(m,...) self:_log(sV,realm,m,...) end
    end
    return rl
end

return Canon_Scribe 