local Friendlevels = Class(function(self, inst)
    self.inst = inst

    self.friendlytasks = {}
    self.annoytasks = {}

    self.enabled = true
    self.level = 0
    self.levelrewards = {}
    self.defaultrewards = nil
    self.queuedrewards = {}
end)

function Friendlevels:GetDebugString()
    return string.format("number of tasks:%s, level:%s", tostring(#self.friendlytasks), tostring(self.level))
end

function Friendlevels:Enable(enabled)
    self.enabled = enabled
    self:SetIsInMood(false, false)
end

function Friendlevels:SetDefaultRewards(fn)
    self.defaultrewards = fn
end

function Friendlevels:SetLevelRewards(data)
    self.levelrewards = data
end

function Friendlevels:SetFriendlyTasks(data)
    self.friendlytasks = data
end

function Friendlevels:DoRewards(target)
    local gifts = {}
    for i, reward in ipairs(self.queuedrewards) do
        if reward.level == nil then
            gifts = ConcatArrays(gifts, self.defaultrewards(self.inst, target, reward.task))
        else
            gifts = ConcatArrays(gifts, self.levelrewards[reward.level](self.inst, target, reward.task))
        end
    end

    self.queuedrewards = {}
    return gifts
end

function Friendlevels:CompleteTask(task,doer)
    local defaulttask = false

    if not self.friendlytasks[task].complete and self.level < #self.levelrewards then
        self.level = self.level + 1
        table.insert(self.queuedrewards, {level = self.level, task = task})
    elseif not self.friendlytasks[task] or not self.friendlytasks[task].complete or not self.friendlytasks[task].onetime then
        defaulttask = true
        if self.defaultrewards then
            table.insert(self.queuedrewards,{level = nil, task = task })
        end
    end

    if self.friendlytasks[task] and not self.friendlytasks[task].complete then
        self.friendlytasks[task].complete = true
    end

    self.inst:PushEvent("friend_task_complete", defaulttask)
end

function Friendlevels:GetLevel()
    return self.level
end

function Friendlevels:GetMaxLevel()
    return #self.levelrewards
end

function Friendlevels:OnSave()
    local taskscomplete = {}
    for i,task in ipairs(self.friendlytasks)do
        table.insert(taskscomplete,{complete = task.complete})
    end
    return {enabled = self.enabled, level = self.level, taskscomplete = taskscomplete, queuedrewards = self.queuedrewards}
end

function Friendlevels:OnLoad(data)
    self.enabled = data.enabled
    self.level = data.level
    self.queuedrewards = data.queuedrewards or {}
    if #self.queuedrewards > 0 then
        self.inst:PushEvent("friend_task_complete")
    end
end

function Friendlevels:LoadPostPass(newents, data)
	if data ~= nil and data.taskscomplete ~= nil then
		for i,task in ipairs(self.friendlytasks) do
			if data.taskscomplete[i] then
				task.complete = data.taskscomplete[i].complete
			end
		end
	end
end

return Friendlevels

