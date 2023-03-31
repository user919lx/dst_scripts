require("behaviours/chaseandattack")
require("behaviours/follow")
require("behaviours/faceentity")
require("behaviours/wander")

local BernieBigBrain = Class(Brain, function(self, inst)
    Brain._ctor(self,inst)
    self._leader = nil
    self._isincombat = false
end)

local MIN_FOLLOW_DIST = 1
local MAX_FOLLOW_DIST = 8
local TARGET_FOLLOW_DIST = 5
local WALK_FOLLOW_THRESHOLD = 11 --beyond this distance will start running
local RUN_FOLLOW_THRESHOLD = TARGET_FOLLOW_DIST + 1 --run until within this distance
local MIN_COMBAT_TARGET_DIST = 11
local MAX_COMBAT_TARGET_DIST = 14
local FIND_LEADER_DIST_SQ = 22 * 22
local LOSE_LEADER_DIST_SQ = 30 * 30
local MIN_ACTIVE_TIME = 4
local DEACTIVATE_DELAY = 16
local FOLLOWER_SANITY_THRESHOLD = .5

local function SetLeader(self, leader)
    if self._leader ~= leader then
        if self._leader ~= nil then
            self._leader.bigbernies[self.inst] = nil
            if next(self._leader.bigbernies) == nil then
                self._leader.bigbernies = nil
            end
        end
        if leader ~= nil then
            if leader.bigbernies == nil then
                leader.bigbernies = { [self.inst] = true }
            else
                leader.bigbernies[self.inst] = true
            end
        end
        self._leader = leader
    end
end

local function ShouldDeactivate(self)
    if self._leader ~= nil then
        if self.inst.sg:HasStateTag("busy") then
            return false
        end

        SetLeader(self, nil) --V2C: not redundant, this will clear .bigbernies
    end

    local closestleader = nil
    local iscrazy = false
    local rangesq = FIND_LEADER_DIST_SQ
    local x, y, z = self.inst.Transform:GetWorldPosition()
    for i, v in ipairs(AllPlayers) do
        if v:HasTag("bernieowner") and v.bigbernies == nil and (v.entity:IsVisible() or (v.sg ~= nil and v.sg.currentstate.name == "quicktele")) then
            if v.components.sanity:IsCrazy() then
                local distsq = v:GetDistanceSqToPoint(x, y, z)
                if distsq < (iscrazy and rangesq or FIND_LEADER_DIST_SQ) then
                    iscrazy = true
                    rangesq = distsq
                    closestleader = v
                end
            elseif not iscrazy and v.components.sanity:GetPercent() < FOLLOWER_SANITY_THRESHOLD then
                local distsq = v:GetDistanceSqToPoint(x, y, z)
                if distsq < rangesq then
                    rangesq = distsq
                    closestleader = v
                end
            end
        end
    end

    SetLeader(self, closestleader)

    if iscrazy or self.inst.sg:HasStateTag("busy") then
        return false
    elseif self._leader ~= nil then
        local t = GetTime()
        if self.inst.components.combat:GetLastAttackedTime() + DEACTIVATE_DELAY >= t or
            (self.inst.components.combat.lastdoattacktime or 0) + DEACTIVATE_DELAY >= t then
            return false
        end
    end
    return self.inst:GetTimeAlive() >= MIN_ACTIVE_TIME
end

local function KeepLeaderFn(inst, leader)
    --V2C: re-checking "bernieowner" tag is redundant
    return leader:IsValid()
        and (leader.entity:IsVisible() or (leader.sg ~= nil and leader.sg.currentstate.name == "quicktele"))
        and leader.components.sanity:GetPercent() < FOLLOWER_SANITY_THRESHOLD
        and inst:IsNear(leader, LOSE_LEADER_DIST_SQ)
end

local function GetLeader(self)
    --V2C: re-checking "bernieowner" tag is redundant
    if self._leader ~= nil and not KeepLeaderFn(self.inst, self._leader) then
        SetLeader(self, nil)
    end
    return self._leader
end

local function ShouldWalkToLeader(self)
    return not self.inst.sg:HasStateTag("running") and GetLeader(self) ~= nil and self.inst:IsNear(self._leader, WALK_FOLLOW_THRESHOLD)
end

local function ShouldRunToLeader(self)
    return GetLeader(self) ~= nil
        and not (   self.inst:IsNear(self._leader, RUN_FOLLOW_THRESHOLD) and
                    self._leader.sg ~= nil and
                    self._leader.sg:HasStateTag("moving")   )
end

function BernieBigBrain:OnStart()
    local root = PriorityNode({
        IfNode(function() return ShouldDeactivate(self) end, "No Leader",
            ActionNode(function() self.inst.sg:GoToState("deactivate") end)),

        WhileNode(
            function()
                local target = self.inst.components.combat.target
                if target ~= nil and target:IsValid() then
                    local leader = GetLeader(self)
                    self._isincombat = leader == nil or leader:IsNear(target, self._isincombat and MAX_COMBAT_TARGET_DIST or MIN_COMBAT_TARGET_DIST)
                else
                    self._isincombat = false
                end
                return self._isincombat
            end,
            "Combat",
            ChaseAndAttack(self.inst, nil, nil, nil, nil, true)),

        NotDecorator(ActionNode(function() self._isincombat = false end)),

        --V2C: smooth transitions between walk/run without stops when following the player
        WhileNode(function() return ShouldWalkToLeader(self) end, "Walk Follow",
            Follow(self.inst, function() return self._leader end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST, false)),
        WhileNode(function() return ShouldRunToLeader(self) end, "Run Follow",
            Follow(self.inst, function() return self._leader end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, MAX_FOLLOW_DIST, true)),
        IfNode(function() return self.inst.sg:HasStateTag("running") end, "Continue Walk Follow",
            Follow(self.inst, function() return GetLeader(self) end, MIN_FOLLOW_DIST, TARGET_FOLLOW_DIST, TARGET_FOLLOW_DIST, false)),
        --

        FaceEntity(self.inst, function() return GetLeader(self) end, KeepLeaderFn),
        Wander(self.inst),
    }, .2)
    self.bt = BT(self.inst, root)

    if self._onremove == nil then
        self._onremove = function() SetLeader(self, nil) end
        self.inst:ListenForEvent("onremove", self._onremove)
    end
end

function BernieBigBrain:OnStop()
    if self._onremove ~= nil then
        self.inst:RemoveEventCallback("onremove", self._onremove)
        self._onremove = nil
    end
    SetLeader(self, nil)
end

return BernieBigBrain
