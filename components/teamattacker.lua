local function onteamtype(self, team, oldteam)
    if oldteam ~= nil then
        self.inst:RemoveTag("team_"..oldteam)
    end
    if team ~= nil then
        self.inst:AddTag("team_"..team)
		self.teamsearchtags = {"teamleader_"..team}
    else
		self.teamsearchtags = nil
	end
end

local TeamAttacker = Class(function(self, inst)
	self.inst = inst
	self.inteam = false
	self.teamleader = nil
	self.formationpos = nil
	self.order = nil
	self.searchradius = 50
	self.leashdistance = 70
	self.inst:StartUpdatingComponent(self)
	self.team_type = "monster"
end,
nil,
{
    team_type = onteamtype,
})

function TeamAttacker:GetDebugString()
	local str = string.format("In Team %s, Current Orders: %s",
		tostring(self.inteam), self.orders and table.reverselookup(ORDERS, self.orders) or "NONE")
	return str
end

function TeamAttacker:SearchForTeam()
	local pt = Vector3(self.inst.Transform:GetWorldPosition())
	local ents = TheSim:FindEntities(pt.x, pt.y, pt.z, self.searchradius, self.teamsearchtags)

	for k,v in pairs(ents) do
		if not v.components.teamleader:IsTeamFull() then
			v.components.teamleader:NewTeammate(self.inst)
			return true
		end
    end
end

function TeamAttacker:OnEntitySleep()

	if self.teamleader then
		self.teamleader:OnLostTeammate(self.inst)
	end
	self.inst:StopUpdatingComponent(self)
end

function TeamAttacker:OnEntityWake()
	self.inst:StartUpdatingComponent(self)
end

function TeamAttacker:ShouldGoHome()
    local homePos = self.inst.components.knownlocations:GetLocation("home")
    local x,y,z = self.inst.Transform:GetWorldPosition()
    return (homePos and distsq(homePos.x, homePos.z, x, z) > self.leashdistance*self.leashdistance)
end

function TeamAttacker:LeaveTeam()
	if self.teamleader then
		self.teamleader:OnLostTeammate(self.inst)
	end
end

function TeamAttacker:OnUpdate(dt)
	if self:ShouldGoHome() then self:LeaveTeam() end

	if self.teamleader and self.teamleader:CanAttack() then --did you find a team?
		if self.orders == ORDERS.HOLD or self.orders == nil then --if you don't have anything to do.. look menacing
			self.inst.components.combat.target = nil
			if self.formationpos then
				local destpos = self.formationpos
        		local mypos = Point(self.inst.Transform:GetWorldPosition())
        		if destpos and mypos then
					if distsq(destpos, mypos) >= 0.15 then	--if you're almost at your target just stop.
						self.inst.components.locomotor:GoToPoint(self.formationpos)
					end
				end

				if self.inst.components.health.takingfiredamage then
					self.orders = ORDERS.ATTACK
				end

			end
		elseif self.orders == ORDERS.WARN then
			self.inst.components.combat.target = nil
			if self.formationpos then
				local destpos = self.formationpos
        		local mypos = Point(self.inst.Transform:GetWorldPosition())
        		if destpos and mypos then
					if distsq(destpos, mypos) >= 0.15 then	--if you're almost at your target just stop.
						self.inst.components.locomotor:GoToPoint(self.formationpos)
					end
				end
			end
		elseif self.orders == ORDERS.ATTACK then	--You have been told to attack. Get the target from your leader.
			self.inst.components.combat:SuggestTarget(self.teamleader.threat)
		end
	end
end

return TeamAttacker
