-- 登仙（3235319974）适配。
-- Dengxian 20.0: keep its public functions and skin callbacks intact.
-- The three ownership entry points share a private, skin-name predicate.
return function(ctx)
    local G = ctx.G
    local Upvalue, Log = ctx.common.Upvalue, ctx.common.Log
    local crafting = ctx.config.crafting_skins
    local adapter = { name = "Dengxian", ready = false }

    local function GetSkins()
        local skins = G.rawget(G, "XD_ITEMSKINS")
        return G.type(skins) == "table" and skins or nil
    end

    local function IsCharacterSkin(name)
        local skins = GetSkins()
        local data = skins ~= nil and G.rawget(skins, name) or nil
        return G.type(data) == "table" and data.ischaracterskins == true
    end

    function adapter.IsSkin(name, base)
        local skins = G.rawget(G, "XD_ITEMSKINS")
        local data = G.type(skins) == "table" and skins[name] or nil
        if G.type(name) ~= "string" or G.type(data) ~= "table"
            or data.ischaracterskins or (data.type ~= nil and data.type ~= "item")
            or G.type(data.base_prefab) ~= "string"
            or G.type(data.init_fn) ~= "function" or G.type(data.clear_fn) ~= "function" then
            return false
        end
        -- Some weapons and recipe products share another prefab's skin list.
        for _, skin in G.ipairs((G.PREFAB_SKINS or {})[base or data.base_prefab] or {}) do
            if skin == name then return true end
        end
        return false
    end

    local function Frame(fn, entry)
        if Upvalue(fn, "w") ~= entry then return end
        local frame = Upvalue(fn, "f")
        if G.type(frame) == "table" and Upvalue(fn, "Y") == frame then
            return frame
        end
    end

    local function EnsureEngineSkin(name)
        -- Dengxian ships engine-format skin data (skins.normal_skin). The live
        -- game does not always surface shop skins through the global registry
        -- that the vanilla spawn and wardrobe paths consult; fill the gap.
        local skins = GetSkins()
        local data = skins ~= nil and G.rawget(skins, name) or nil
        if G.type(data) ~= "table" or G.type(data.skins) ~= "table"
            or G.type(data.skins.normal_skin) ~= "string" then
            return
        end
        if G.Prefabs == nil then return end
        if G.rawget(G.Prefabs, name) == nil then
            G.rawset(G.Prefabs, name, data)
        end
    end

    -- Restore a requested character skin that the vanilla gates dropped.
    local function RestoreCharacterSkin(requested, prefab_name)
        if G.type(requested) ~= "string" or requested == "" then return nil end
        local skins = GetSkins()
        local data = skins ~= nil and G.rawget(skins, requested) or nil
        if G.type(data) ~= "table" then
            return nil
        end
        if data.ischaracterskins ~= true then
            return nil
        end
        if G.type(prefab_name) == "string" and data.base_prefab ~= prefab_name then
            return nil
        end
        EnsureEngineSkin(requested)
        return requested
    end

    local function InstallCharacterSkinHooks()
        if adapter.hooks_installed then return end
        adapter.hooks_installed = true
        -- Lobby: vanilla keeps a spawn skin only when its client-ownership
        -- check passes; restore managed character skins it dropped.
        local old_validate = G.rawget(G, "ValidateSpawnPrefabRequest")
        if G.type(old_validate) == "function" then
            G.ValidateSpawnPrefabRequest = function(user_id, prefab_name, skin_base, ...)
                local prefab, skin, a, b, c, d = old_validate(user_id, prefab_name, skin_base, ...)
                if skin == nil and G.type(skin_base) == "string" and skin_base ~= "" then
                    local restored = RestoreCharacterSkin(skin_base, prefab_name)
                    if restored ~= nil then
                        skin = restored
                        Log("Dengxian character skin restored at spawn: " .. G.tostring(restored))
                    end
                end
                return prefab, skin, a, b, c, d
            end
        end
        -- Wardrobe: vanilla only applies base skins found in Prefabs, and some
        -- shop skins are missing there; apply them through the native skinner.
        -- AddComponentPostInit lives in the mod environment only (not on the
        -- global table), so it arrives through ctx like the other post-inits.
        local add_component_post_init = ctx.AddComponentPostInit
        if G.type(add_component_post_init) == "function" then
            add_component_post_init("wardrobe", function(self)
                local old_apply = self.ApplySkins
                if G.type(old_apply) ~= "function" then return end
                function self:ApplySkins(doer, diff)
                    local ok, r = G.pcall(old_apply, self, doer, diff)
                    if ok and doer ~= nil and doer.prefab ~= nil and doer.components ~= nil
                        and doer.components.skinner ~= nil and G.type(diff) == "table"
                        and G.type(diff.base) == "string" then
                        local skinner = doer.components.skinner
                        if skinner.skin_name ~= diff.base then
                            local restored = RestoreCharacterSkin(diff.base, doer.prefab)
                            if restored ~= nil then
                                G.pcall(function()
                                    skinner:SetSkinName(restored)
                                    Log("Dengxian character skin applied at wardrobe: " .. G.tostring(restored))
                                end)
                            end
                        end
                    end
                    if not ok then G.error(r) end
                    return r
                end
            end)
        end
    end

    function adapter.Install()
        local check = G.rawget(G, "skdwdwswpp")
        local skins = G.rawget(G, "XD_ITEMSKINS")
        -- DST stores each mod's environment directly in ModManager.mods.
        if check == nil and G.type(skins) == "table" then
            local manager = G.rawget(G, "ModManager")
            for _, modenv in G.pairs(manager and manager.mods or {}) do
                if G.type(modenv) == "table" then
                    local candidate = G.rawget(modenv, "skdwdwswpp")
                    if G.type(candidate) == "function" then check = candidate; break end
                end
            end
        end
        if check == nil and skins == nil then return false end
        if adapter.check == check and adapter.ready then return true end
        adapter.ready = false
        local frame = Frame(check, 9167873)
        local cell = frame and frame[3]
        local original = G.type(cell) == "table" and cell[1] or nil
        local local_pending, client_pending, seen = {}, {}, {}
        local valid = G.type(skins) == "table" and G.type(original) == "function"
        if valid then
            for name, data in G.pairs(skins) do
                local item_skin = adapter.IsSkin(name)
                local character_skin = G.type(data) == "table" and data.ischaracterskins == true
                if (item_skin or character_skin) and (data.checkfn ~= nil or data.checkclientfn ~= nil) then
                    local local_frame = Frame(data.checkfn, 5155329)
                    local client_frame = Frame(data.checkclientfn, 4506113)
                    local matched = local_frame ~= nil and client_frame ~= nil
                        and local_frame[1] == cell and client_frame[1] == cell
                    if not matched then
                        -- Item skins are the adapter contract: fail closed on change.
                        -- A character skin only loses its own unlock, never the adapter.
                        if item_skin then
                            valid = false
                            break
                        end
                    else
                        -- Frames are shared between skins; collect each family once.
                        if not seen[local_frame] then
                            seen[local_frame] = true
                            local_pending[#local_pending + 1] = local_frame
                        end
                        if not seen[client_frame] then
                            seen[client_frame] = true
                            client_pending[#client_pending + 1] = client_frame
                        end
                    end
                end
            end
        end
        if not valid or (#local_pending == 0 and #client_pending == 0) then
            if adapter.failed ~= check then
                Log("Dengxian interface changed; adapter inactive. Expected version 20.0.")
                adapter.failed = check
            end
            return false
        end
        -- Replace capture cells, not public inventory methods or entitlement data.
        -- The check frames are shared between skins, so the split is by check
        -- family, not by skin: character skins always open (the lobby loadout
        -- reads the local check), while item skins follow the crafting_skins
        -- option on the local side and stay open on the client side so the
        -- sweeper keeps working when the option is off.
        local allowed_all = { function(name, ...)
            if adapter.IsSkin(name) or IsCharacterSkin(name) then return true end
            return original(name, ...)
        end }
        local allowed_local = { function(name, ...)
            if IsCharacterSkin(name) or (crafting and adapter.IsSkin(name)) then return true end
            return original(name, ...)
        end }
        frame[3] = allowed_all
        for _, candidate in G.ipairs(local_pending) do candidate[1] = allowed_local end
        for _, candidate in G.ipairs(client_pending) do candidate[1] = allowed_all end
        -- Character-skin hooks are a bonus layer: never let them break the adapter.
        local hooks_ok, hooks_err = G.pcall(InstallCharacterSkinHooks)
        if not hooks_ok then
            Log("Dengxian character-skin hooks skipped: " .. G.tostring(hooks_err))
        end
        adapter.check = check
        adapter.ready = true
        return true
    end

    function adapter.GetBase(target)
        if adapter.ready and G.type(G.rawget(G, "XD_ITEMSKINS")) == "table" then
            return target.prefab
        end
    end

    function adapter.FindInventoryDelegate(root, method)
        if G.type(G.rawget(G, "XD_ITEMSKINS")) ~= "table" then return end
        return ctx.inventory.FindDelegate(root, method, "oldTheInventory" .. method)
    end

    function adapter.AfterApply(target, skin)
        -- The native wrapper emits this for skins, but not for default.
        if skin == nil then target:PushEvent("xd_skinchange") end
    end

    local function DefaultVisuals(target, data)
        if target.AnimState ~= nil then
            if data.basebank ~= nil then target.AnimState:SetBank(data.basebank) end
            if data.baseanim ~= nil then target.AnimState:PlayAnimation(data.baseanim) end
            target.AnimState:SetBuild(data.basebuild or target.prefab)
        end
        if target.components ~= nil and target.components.inventoryitem ~= nil then
            local atlas = G.GetInventoryItemAtlas ~= nil and G.GetInventoryItemAtlas(target.prefab .. ".tex") or nil
            target.components.inventoryitem.atlasname = atlas or ("images/inventoryimages/" .. target.prefab .. ".xml")
            target.components.inventoryitem:ChangeImageName(target.prefab)
        end
    end

    -- Apply through the native path first. In the live game the native reskin
    -- wrapper can silently skip these items (engine binding / table divergence
    -- that the sandbox cannot reproduce), so when the state did not land, mirror
    -- the wrapper explicitly using only the public registry.
    local function ApplyDengxian(target, skin, userid)
        G.TheSim:ReskinEntity(target.GUID, target.skinname, skin, nil, userid or "")
        if target.skinname == skin then return end
        local skins = GetSkins()
        if skin ~= nil and (skins == nil or G.type(G.rawget(skins, skin)) ~= "table") then
            return
        end
        local old = skins ~= nil and G.type(target.skinname) == "string" and G.rawget(skins, target.skinname) or nil
        if G.type(old) == "table" and G.type(old.clear_fn) == "function" then
            G.pcall(old.clear_fn, target)
        end
        if skin == nil then
            DefaultVisuals(target, G.type(old) == "table" and old or {})
            target.skinname = nil
            target.skin_id = 0
            target:PushEvent("xd_skinchange")
            Log("Dengxian apply fallback used for default")
            return
        end
        local data = G.rawget(skins, skin)
        if G.type(data.init_fn) == "function" then G.pcall(data.init_fn, target) end
        if target.AnimState ~= nil then
            if data.bank ~= nil then target.AnimState:SetBank(data.bank) end
            if not data.nochangebuild then target.AnimState:SetBuild(data.build or skin) end
            if data.anim ~= nil then target.AnimState:PlayAnimation(data.anim) end
        end
        if target.components ~= nil and target.components.inventoryitem ~= nil then
            target.components.inventoryitem.atlasname = data.atlas or ("images/inventoryimages/" .. skin .. ".xml")
            target.components.inventoryitem:ChangeImageName(data.image or skin)
        end
        if G.type(data.skininit_fn) == "function" then G.pcall(data.skininit_fn, target, skin) end
        target.skinname = skin
        target.skin_id = 0
        target:PushEvent("xd_skinchange")
        Log("Dengxian apply fallback used for " .. G.tostring(skin))
    end

    adapter.GetSkin = ctx.common.GetSkin
    adapter.Apply = ApplyDengxian
    return adapter
end
