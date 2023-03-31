require "behaviours/wander"
require "behaviours/leash"
require "behaviours/doaction"
require "behaviours/chaseandattack"
require "behaviours/runaway"
local BrainCommon = require("brains/braincommon")

local MAX_LEASH_DIST = 20
local MAX_WANDER_DIST = 6
local RUN_AWAY_DIST = 4
local STOP_RUN_AWAY_DIST = 8

local MAX_CHASE_DIST = 8
local MAX_CHASE_TIME = 10

local function GoHomeAction(inst)
    if inst.components.homeseeker and
       inst.components.homeseeker.home and
       inst.components.homeseeker.home:IsValid() then
        return BufferedAction(inst, inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

local function WanderTarget(inst)
	local combat = inst.components.combat
	if combat:ValidateTarget() then
		return Point(inst.components.combat.target.Transform:GetWorldPosition())
	end
	return inst.components.knownlocations:GetLocation("home")

	--return (inst.components.combat.target and inst.components.combat.target.Transform:GetWorldPosition())
			--or inst.components.knownlocations:GetLocation("home")
end

local function ShouldGoHome(inst)
    return TheWorld.state.iswinter or (TheWorld.state.isday and not inst.override_stay_out)
end

local MosquitoBrain = Class(Brain, function(self, inst)
    Brain._ctor(self, inst)
end)

function MosquitoBrain:OnStart()
	local wandertimes = {minwalktime=0.1,randwalktime=0.1,minwaittime=0.0,randwaittime=0.0}

    local root = PriorityNode(
    {
		BrainCommon.PanicTrigger(self.inst),
		Leash(self.inst, function() return self.inst.components.knownlocations:GetLocation("home") end, MAX_LEASH_DIST, MAX_WANDER_DIST),
        WhileNode( function() return self.inst.components.combat.target == nil or not self.inst.components.combat:InCooldown() end, "AttackMomentarily", ChaseAndAttack(self.inst, SpringCombatMod(MAX_CHASE_TIME), SpringCombatMod(MAX_CHASE_DIST)) ),
        WhileNode(function() return ShouldGoHome(self.inst) end, "ShouldGoHome",
            DoAction(self.inst, function() return GoHomeAction(self.inst) end, "go home", true )),
        WhileNode( function() return self.inst.components.combat.target and self.inst.components.combat:InCooldown() end, "Dodge", RunAway(self.inst, function() return self.inst.components.combat.target end, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST) ),
        Wander(self.inst, WanderTarget, MAX_WANDER_DIST, wandertimes)
    }, .25)

    self.bt = BT(self.inst, root)
end

function MosquitoBrain:OnInitializationComplete()
    self.inst.components.knownlocations:RememberLocation("home", Point(self.inst.Transform:GetWorldPosition()), true)
end

return MosquitoBrain
