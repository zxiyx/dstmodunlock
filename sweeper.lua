return function(ctx, adapters)
    local G = ctx.G
    local MODE, ANNOUNCE = ctx.config.selection_mode, ctx.config.announce
    local IsValid, Log = ctx.common.IsValid, ctx.common.Log

    local function ResolveTarget(target)
        local seen = {}
        for _ = 1, 8 do
            if not IsValid(target) or seen[target] then
                return nil
            end
            seen[target] = true
            local redirect = target.reskin_tool_target_redirect
            if not IsValid(redirect) then
                return target
            end
            target = redirect
        end
    end

    local function IsCharacter(target)
        if target:HasTag("player") then
            return true
        end
        for _, name in G.ipairs(G.DST_CHARACTERLIST or {}) do
            if target.prefab == name then
                return true
            end
        end
        return target.components ~= nil and target.components.beard ~= nil
            and target.components.beard.is_skinnable == true
    end

    local function ContainsAny(name, fragments)
        if fragments == nil then
            return false
        end
        for _, fragment in G.ipairs(fragments) do
            if G.string.find(name, fragment, 1, true) ~= nil then
                return true
            end
        end
        return false
    end

    -- Returns false for other mods. A handled target with no plan is denied.
    local function Plan(tool, original_target, doer)
        local target = ResolveTarget(original_target)
        if target == nil or IsCharacter(target) then return false end
        local adapter, base, managed
        for _, candidate in G.ipairs(adapters) do
            local candidate_base = candidate.GetBase(target)
            if candidate_base ~= nil then
                local choices, seen = {}, {}
                for _, name in G.ipairs((G.PREFAB_SKINS or {})[candidate_base] or {}) do
                    if not seen[name] and candidate.IsSkin(name, candidate_base, target) then
                        seen[name] = true
                        choices[#choices + 1] = name
                    end
                end
                if #choices > 0 then
                    adapter, base, managed = candidate, candidate_base, choices
                    break
                end
            end
        end
        if adapter == nil then return false end
        if not IsValid(tool) or not IsValid(doer) or tool.parent ~= doer
            or target.reskin_tool_cannot_target_this
            or (target._playerlink ~= nil and target._playerlink ~= doer)
            or target:HasTag("nomagic")
            or (target.IsInLimbo ~= nil and target:IsInLimbo()) then
            return true
        end

        local must_have, must_not_have
        if target.ReskinToolFilterFn ~= nil then
            must_have, must_not_have = target:ReskinToolFilterFn()
        end
        local exclusions = G.PREFAB_SKINS_SHOULD_NOT_SELECT or {}
        local event_locks = G.SKINS_EVENTLOCK or {}
        local choices, allowed = {}, {}
        for _, name in G.ipairs(managed) do
            local event = event_locks[name]
            if not exclusions[name]
                and (event == nil or (G.IsSpecialEventActive ~= nil and G.IsSpecialEventActive(event)))
                and (must_have == nil or ContainsAny(name, must_have))
                and (must_not_have == nil or not ContainsAny(name, must_not_have)) then
                choices[#choices + 1] = name
                allowed[name] = true
            end
        end

        local current = adapter.GetSkin(target)
        local skip_base = exclusions[base] == true
        local next_skin
        local use_cache = false
        if MODE == "batch" then
            local cache = tool._hmr_sweeper_cache
            local cached = cache ~= nil and cache[base] or nil
            -- false denotes an explicitly selected default appearance.
            if cache ~= nil and cache[base] == false then
                cached = false
            end
            if cached == false and not skip_base and current ~= nil then
                use_cache = true
            elseif cached ~= nil and cached ~= false and allowed[cached] and cached ~= current then
                next_skin, use_cache = cached, true
            end
        end
        if not use_cache then
            local current_index
            for index, name in G.ipairs(choices) do
                if name == current then
                    current_index = index
                    break
                end
            end
            if current_index ~= nil then
                next_skin = choices[current_index + 1]
                if next_skin == nil and skip_base then
                    next_skin = choices[1]
                end
            else
                next_skin = choices[1]
            end
        end
        if (next_skin == nil and skip_base) or next_skin == current then
            return true
        end
        return true, {
            target = target,
            base = base,
            adapter = adapter,
            previous = current,
            skin = next_skin,
        }
    end

    local function Say(doer, message)
        if IsValid(doer) and doer.components ~= nil and doer.components.talker ~= nil then
            doer.components.talker:Say(message)
        end
    end

    local function SpawnFX(tool, target)
        local name = "explode_reskin"
        local tool_skin = tool:GetSkinName()
        local skin_fx = G.SKIN_FX_PREFAB ~= nil and G.SKIN_FX_PREFAB[tool_skin] or nil
        if skin_fx ~= nil and skin_fx[1] ~= nil then
            name = skin_fx[1]
        end
        local fx = G.SpawnPrefab(name)
        if fx ~= nil and fx.Transform ~= nil then
            local x, y, z = target.Transform:GetWorldPosition()
            fx.Transform:SetPosition(x, y, z)
        end
    end

    local function Install(tool)
        if G.TheWorld == nil or not G.TheWorld.ismastersim or tool._hmr_sweeper_installed then
            return
        end
        local spellcaster = tool.components ~= nil and tool.components.spellcaster or nil
        if spellcaster == nil or spellcaster.spell == nil or spellcaster.can_cast_fn == nil then
            return
        end
        tool._hmr_sweeper_installed = true
        local old_can_cast = spellcaster.can_cast_fn
        local old_spell = spellcaster.spell

        spellcaster:SetCanCastFn(function(doer, target, pos, supplied_tool)
            local handled, plan = Plan(tool, target, doer)
            if handled then
                return plan ~= nil and not tool._hmr_sweeper_pending
            end
            return old_can_cast(doer, target, pos, supplied_tool or tool)
        end)

        spellcaster:SetSpellFn(function(inst, target, pos, caster)
            local handled, plan = Plan(inst, target, caster)
            if not handled then
                return old_spell(inst, target, pos, caster)
            end
            if plan == nil or inst._hmr_sweeper_pending then
                return
            end
            inst._hmr_sweeper_pending = true
            inst:DoTaskInTime(0, function()
                inst._hmr_sweeper_pending = nil
                -- Revalidate ownership, filters, redirect and current appearance at execution.
                local still_handled, fresh = Plan(inst, target, caster)
                if not still_handled or fresh == nil or fresh.target ~= plan.target
                    or fresh.adapter ~= plan.adapter
                    or fresh.previous ~= plan.previous or fresh.skin ~= plan.skin then
                    return
                end
                local ok, err = G.pcall(function()
                    plan.adapter.Apply(plan.target, plan.skin, caster.userid)
                    local applied = plan.adapter.GetSkin(plan.target)
                    if applied ~= plan.skin then
                        G.error("skin state did not change to the requested value")
                    end
                    if plan.adapter.AfterApply ~= nil then
                        plan.adapter.AfterApply(plan.target, plan.skin)
                    end
                end)
                if not ok then
                    Log("Failed on " .. G.tostring(plan.base) .. ": " .. G.tostring(err))
                    Say(caster, "换肤失败，请查看服务器日志。")
                    return
                end
                inst._hmr_sweeper_cache = inst._hmr_sweeper_cache or {}
                inst._hmr_sweeper_cache[plan.base] = plan.skin or false
                local fx_ok, fx_error = G.pcall(SpawnFX, inst, plan.target)
                if not fx_ok then
                    Log("Skin applied; effect failed: " .. G.tostring(fx_error))
                end
                if ANNOUNCE then
                    local names = G.STRINGS ~= nil and G.STRINGS.SKIN_NAMES or {}
                    Say(caster, plan.skin ~= nil and (names[plan.skin] or plan.skin) or "默认外观")
                end
            end)
        end)
    end

    return {
        Install = function(inst)
            if G.TheWorld ~= nil and G.TheWorld.ismastersim then
                inst:DoTaskInTime(0, Install)
            end
        end,
    }
end
