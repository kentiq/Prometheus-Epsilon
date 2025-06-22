local PE_Promise = require(script.Parent.Parent.Lib.Promise)
local PE_Utility = require(script.Parent.Parent.Lib.Utility)

local PROMETHEUS_EPSILON_SIGNATURE = "PrometheusEpsilonPragmatic"

local Canon_Scheduler = { Interface = "IPrometheusEpsilonScheduler", Name = "Scheduler" }
Canon_Scheduler._taskQueues = { HIGH={}, NORMAL={}, LOW={} } -- Simplified priorities
Canon_Scheduler._activeTasks = {}
Canon_Scheduler._taskIdCounter = 0
Canon_Scheduler._workerCoroutine = nil
Canon_Scheduler._keepRunning = false

function Canon_Scheduler:Initialize(codex, scribe)
    self._scribe = scribe:GetRealmLogger(self.Name)
    self._quantumMs = codex:Get("Scheduler.QuantumMs", 10)
    self._keepRunning = true
    self:_startWorker()
    self._scribe.Info("Scheduler Canon initialized. Quantum: %dms", self._quantumMs)
    return PE_Promise.Resolve(true)
end

function Canon_Scheduler:Shutdown()
    self._keepRunning = false
    self._scribe.Info("Scheduler Canon shutting down. Waiting for tasks to complete (max 5s)...")
    -- Simple wait, real shutdown would be more graceful or forceful
    local shutdownPromise = PE_Promise.New()
    task.delay(5, function()
        if self._workerCoroutine and coroutine.status(self._workerCoroutine) ~= "dead" then
            self._scribe.Warn("Scheduler worker did not terminate gracefully.")
        end
        shutdownPromise:_resolve(true)
    end)
    return shutdownPromise
end

function Canon_Scheduler:_startWorker()
    if self._workerCoroutine then return end
    self._workerCoroutine = coroutine.create(function()
        while self._keepRunning do
            local taskToExecute, priority = self:_getNextTask()
            if taskToExecute then
                self._activeTasks[taskToExecute.id] = taskToExecute
                local startTime = PE_Utility.PreciseTime()
                local s, r = xpcall(taskToExecute.func, debug.traceback, unpack(taskToExecute.args or {}))
                local duration = (PE_Utility.PreciseTime() - startTime) * 1000
                self._activeTasks[taskToExecute.id] = nil

                if s then taskToExecute.promise:_resolve(r)
                else
                    taskToExecute.promise:_reject(r)
                    self._scribe.Error("Task %s failed: %s", taskToExecute.id, tostring(r):sub(1,200))
                end

                if duration > self._quantumMs * 2 then
                    self._scribe.Warn("Task %s exceeded quantum: %.2fms", taskToExecute.id, duration)
                end
                task.wait() -- Yield to Roblox scheduler
            else
                task.wait(0.01) -- Wait a bit if idle
            end
        end
        self._scribe.Info("Scheduler worker coroutine terminated.")
    end)
    task.spawn(self._workerCoroutine) -- Let Roblox manage the coroutine
end

function Canon_Scheduler:_getNextTask()
    for _, prio in ipairs({"HIGH", "NORMAL", "LOW"}) do
        if #self._taskQueues[prio] > 0 then
            return table.remove(self._taskQueues[prio], 1), prio
        end
    end
    return nil
end

function Canon_Scheduler:Submit(func, args, priority, options)
    options = options or {}
    priority = priority or "NORMAL"
    self._taskIdCounter = self._taskIdCounter + 1
    local taskId = PROMETHEUS_EPSILON_SIGNATURE .. "_Task_" .. self._taskIdCounter
    local promise = PE_Promise.New()
    local taskData = {id=taskId, func=func, args=args, promise=promise, name=options.name or taskId}
    if options.timeoutMs then promise:SetTimeout(options.timeoutMs, "TaskTimeout:"..taskId) end
    table.insert(self._taskQueues[priority:upper()] or self._taskQueues.NORMAL, taskData)
    return promise, taskId
end

function Canon_Scheduler:CancelTask(taskId) -- Very basic cancellation (prevents starting if not started)
    for _,prioQueue in pairs(self._taskQueues) do
        for i=#prioQueue,1,-1 do
            if prioQueue[i].id == taskId then
                table.remove(prioQueue,i).promise:_reject("TaskCancelled")
                return true
            end
        end
    end
    return false -- Cannot cancel active tasks this simply
end

return Canon_Scheduler 