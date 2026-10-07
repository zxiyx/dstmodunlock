return function(ctx)
    local G = ctx.G
    local common = {}

    local function Log(message)
        G.print("[皮肤解锁] " .. message)
    end

    local function IsValid(inst)
        return inst ~= nil and inst.IsValid ~= nil and inst:IsValid()
    end

    local function Upvalue(fn, wanted)
        if G.type(fn) ~= "function" or G.debug == nil
            or G.type(G.debug.getupvalue) ~= "function" then return end
        for index = 1, 100 do
            local name, value = G.debug.getupvalue(fn, index)
            if name == nil then return end
            if name == wanted then return value, index end
        end
    end

    function common.GetSkin(target)
        return target.skinname
    end

    function common.Reskin(target, skin, userid)
        G.TheSim:ReskinEntity(target.GUID, target.skinname, skin, nil, userid or "")
    end

    common.Log = Log
    common.IsValid = IsValid
    common.Upvalue = Upvalue
    return common
end
