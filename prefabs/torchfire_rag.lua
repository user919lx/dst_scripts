local MakeTorchFire = require("prefabs/torchfire_common")

local SMOKE_TEXTURE = "fx/smoke.tex"
local EMBER_TEXTURE = "fx/snow.tex"
local FIRE_TEXTURE = "fx/torchfire.tex"

local SHADER = "shaders/vfx_particle.ksh"
local ADD_SHADER = "shaders/vfx_particle_add.ksh"

local COLOUR_ENVELOPE_NAME_SMOKE = "torch_rag_colourenvelope_smoke"
local SCALE_ENVELOPE_NAME_SMOKE = "torch_rag_scaleenvelope_smoke"
local COLOUR_ENVELOPE_NAME = "torch_rag_colourenvelope"
local SCALE_ENVELOPE_NAME = "torch_rag_scaleenvelope"
local COLOUR_ENVELOPE_NAME_EMBER = "torch_rag_colourenvelope_ember"
local SCALE_ENVELOPE_NAME_EMBER = "torch_rag_scaleenvelope_ember"

local assets =
{
    Asset("IMAGE", SMOKE_TEXTURE),
    Asset("IMAGE", EMBER_TEXTURE),
    Asset("IMAGE", FIRE_TEXTURE),
    Asset("SHADER", SHADER),
    Asset("SHADER", ADD_SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
    return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME_SMOKE,
        {
            { 0,    IntColour(30, 22, 15, 0) },
            { .3,   IntColour(20, 18, 15, 100) },
            { .52,  IntColour(15, 15, 15, 20) },
            { 1,    IntColour(15, 15, 15, 0) },
        }
    )

    local smoke_max_scale = 2.5
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_SMOKE,
        {
            { 0,    { smoke_max_scale * .4, smoke_max_scale * .4 } },
            { .50,  { smoke_max_scale * .6, smoke_max_scale * .6 } },
            { .65,  { smoke_max_scale * .9, smoke_max_scale * .9 } },
            { 1,    { smoke_max_scale, smoke_max_scale } },
        }
    )

    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME,
        {
            { 0,    IntColour(200, 85, 60, 25) },
            { .19,  IntColour(200, 125, 80, 100) },
            { .35,  IntColour(255, 20, 10, 200) },
            { .51,  IntColour(255, 20, 10, 128) },
            { .75,  IntColour(255, 20, 10, 64) },
            { 1,    IntColour(255, 7, 5, 0) },
        }
    )

    local fire_max_scale = 4
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME,
        {
            { 0,    { fire_max_scale * .9, fire_max_scale } },
            { 1,    { fire_max_scale * .5, fire_max_scale * .4 } },
        }
    )

    EnvelopeManager:AddColourEnvelope(
        COLOUR_ENVELOPE_NAME_EMBER,
        {
            { 0,    IntColour(200, 85, 60, 25) },
            { .2,   IntColour(230, 140, 90, 200) },
            { .3,   IntColour(255, 90, 70, 255) },
            { .6,   IntColour(255, 90, 70, 255) },
            { .9,   IntColour(255, 90, 70, 230) },
            { 1,    IntColour(255, 70, 70, 0) },
        }
    )

    local ember_max_scale = .35
    EnvelopeManager:AddVector2Envelope(
        SCALE_ENVELOPE_NAME_EMBER,
        {
            { 0,    { ember_max_scale, ember_max_scale } },
            { 1,    { ember_max_scale, ember_max_scale } },
        }
    )

    InitEnvelope = nil
    IntColour = nil
end

--------------------------------------------------------------------------

local SMOKE_MAX_LIFETIME = 1.1
local FIRE_MAX_LIFETIME = .25
local EMBER_MAX_LIFETIME = .7

local function emit_smoke_fn(effect, sphere_emitter)
    local vx, vy, vz = .01 * UnitRand(), .08 + .02 * UnitRand(), .01 * UnitRand()
    local lifetime = SMOKE_MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()
    local uv_offset = math.random(0, 3) * .25

    effect:AddParticleUV(
        0,
        lifetime,           -- lifetime
        px, py + .2, pz,    -- position
        vx, vy, vz,         -- velocity
        uv_offset, 0        -- uv offset
   )
end

local function emit_fire_fn(effect, sphere_emitter)
    local vx, vy, vz = .01 * UnitRand(), 0, .01 * UnitRand()
    local lifetime = FIRE_MAX_LIFETIME * (.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()
    local uv_offset = math.random(0, 3) * .25

    effect:AddParticleUV(
        1,
        lifetime,           -- lifetime
        px, py, pz,         -- position
        vx, vy, vz,         -- velocity
        uv_offset, 0        -- uv offset
    )
end

local function emit_ember_fn(effect, sphere_emitter)
    local vx, vy, vz = .02 * UnitRand(), .08 + .03 * UnitRand(), .02 * UnitRand()
    local lifetime = EMBER_MAX_LIFETIME * (0.9 + UnitRand() * .1)
    local px, py, pz = sphere_emitter()

    effect:AddParticleUV(
        2,
        lifetime,           -- lifetime
        px, py + .4, pz,    -- position
        vx, vy, vz,         -- velocity
        0, 0                -- uv offset
    )
end

--------------------------------------------------------------------------

local function common_postinit(inst)
    --Dedicated server does not need to spawn local particle fx
    if TheNet:IsDedicated() then
        return
    elseif InitEnvelope ~= nil then
        InitEnvelope()
    end

    -----------------------------------------------------

    local effect = inst.entity:AddVFXEffect()
    effect:InitEmitters(3)

    --SMOKE
    effect:SetRenderResources(0, SMOKE_TEXTURE, SHADER)
    effect:SetMaxNumParticles(0, 128)
    effect:SetMaxLifetime(0, SMOKE_MAX_LIFETIME)
    effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME_SMOKE)
    effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME_SMOKE)
    effect:SetBlendMode(0, BLENDMODE.Premultiplied) --AlphaBlended Premultiplied
    effect:EnableBloomPass(0, true)
    effect:SetUVFrameSize(0, .25, 1)
    effect:SetSortOrder(0, 0)
    effect:SetSortOffset(0, 1)
    effect:SetRadius(0, 3) --only needed on a single emitter

    --FIRE
    effect:SetRenderResources(1, FIRE_TEXTURE, ADD_SHADER)
    effect:SetMaxNumParticles(1, 64)
    effect:SetMaxLifetime(1, FIRE_MAX_LIFETIME)
    effect:SetColourEnvelope(1, COLOUR_ENVELOPE_NAME)
    effect:SetScaleEnvelope(1, SCALE_ENVELOPE_NAME)
    effect:SetBlendMode(1, BLENDMODE.Additive)
    effect:EnableBloomPass(1, true)
    effect:SetUVFrameSize(1, .25, 1)
    effect:SetSortOrder(1, 0)
    effect:SetSortOffset(1, 2)

    --EMBER
    effect:SetRenderResources(2, EMBER_TEXTURE, ADD_SHADER)
    effect:SetMaxNumParticles(2, 128)
    effect:SetMaxLifetime(2, EMBER_MAX_LIFETIME)
    effect:SetColourEnvelope(2, COLOUR_ENVELOPE_NAME_EMBER)
    effect:SetScaleEnvelope(2, SCALE_ENVELOPE_NAME_EMBER)
    effect:SetBlendMode(2, BLENDMODE.Additive)
    effect:EnableBloomPass(2, true)
    effect:SetUVFrameSize(2, 1, 1)
    effect:SetSortOrder(2, 0)
    effect:SetSortOffset(2, 3)
    effect:SetDragCoefficient(2, .07)

    -----------------------------------------------------

    local tick_time = TheSim:GetTickTime()

    local smoke_desired_pps = 80
    local smoke_particles_per_tick = smoke_desired_pps * tick_time
    local smoke_num_particles_to_emit = -50 --start delay

    local fire_desired_pps = 40
    local fire_particles_per_tick = fire_desired_pps * tick_time
    local fire_num_particles_to_emit = 1

    local ember_time_to_emit = -2
    local ember_num_particles_to_emit = 1

    local sphere_emitter = CreateSphereEmitter(.05)
    local ember_sphere_emitter = CreateSphereEmitter(.1)

    EmitterManager:AddEmitter(inst, nil, function()
        --SMOKE
        while smoke_num_particles_to_emit > 1 do
            emit_smoke_fn(effect, sphere_emitter)
            smoke_num_particles_to_emit = smoke_num_particles_to_emit - 1
        end
        smoke_num_particles_to_emit = smoke_num_particles_to_emit + smoke_particles_per_tick

        --FIRE
        while fire_num_particles_to_emit > 1 do
            emit_fire_fn(effect, sphere_emitter)
            fire_num_particles_to_emit = fire_num_particles_to_emit - 1
        end
        fire_num_particles_to_emit = fire_num_particles_to_emit + fire_particles_per_tick * math.random() * 3

        --EMBERS
        if ember_time_to_emit < 0 then
            for i = 1, ember_num_particles_to_emit do
                emit_ember_fn(effect, ember_sphere_emitter)
            end
            ember_num_particles_to_emit = 2 + 3 * math.random() --4 + 9 * math.random()
            ember_time_to_emit = .2-- + (math.random() * .5)
        end
        ember_time_to_emit = ember_time_to_emit - tick_time
    end)
end

local function master_postinit(inst)
    inst.fx_offset = -120
end

return MakeTorchFire("torchfire_rag", assets, nil, common_postinit, master_postinit)
