local assets =
{
    Asset("ANIM", "anim/dragon_scales.zip"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("dragon_scales")
    inst.AnimState:SetBuild("dragon_scales")
    inst.AnimState:PlayAnimation("idle")

    MakeInventoryFloatable(inst, "med", nil, 0.82)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
    inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("dragon_scales", fn, assets)