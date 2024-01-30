--[[GAMEMODE CONFIGURATION START]]--

LeadBot.RespawnAllowed = false
LeadBot.SetModel = false
LeadBot.Gamemode = "deathmatch_unlimited"
LeadBot.TeamPlay = true
LeadBot.LerpAim = true

--[[GAMEMODE CONFIGURATION END]]--

local quality_score = {
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 3,
    ["very_rare"] = 4,
    ["special"] = 5,
}

local health_pickups = {
    dmu_pickup_medkit = true,
    dmu_pickup_healthvial = true,
}

local armor_pickups = {
    dmu_pickup_battery = true,
}

local melee_weapons = {
    weapon_crowbar = true,
    weapon_stunstick = true,
    weapon_fists = true
}

local bot_skill = GetConVar("leadbot_skill")

timer.Simple(0, function()
    if not DMU.Mode.Teams then
        LeadBot.TeamPlay = false
    end
end)

function LeadBot.StartCommand(bot, cmd)
    local buttons = IN_SPEED
    local botWeapon = bot:GetActiveWeapon()
    local controller = bot.ControllerBot
    local target = controller.Target

    local skill = bot_skill:GetInt()
    local jump_delay = 0

    jump_delay = skill == 0 and 99999 or (7 - skill * 2)

    if !IsValid(controller) then return end

    if LeadBot.NoSprint then
        buttons = 0
    end

    if IsValid(target) and math.random(2) == 1 then
        buttons = buttons + IN_ATTACK
    end

    if bot:GetMoveType() == MOVETYPE_LADDER then
        local pos = controller.goalPos
        local ang = ((pos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

        if pos.z > controller:GetPos().z then
            controller.LookAt = Angle(-30, ang.y, 0)
        else
            controller.LookAt = Angle(30, ang.y, 0)
        end

        controller.LookAtTime = CurTime() + 0.1
        controller.NextJump = -1
        buttons = buttons + IN_FORWARD
    end

    if controller.NextDuck > CurTime() then
        buttons = buttons + IN_DUCK
    elseif controller.NextJump == 0 then
        controller.NextJump = CurTime() + 1 -- why is it like this??? i don't get it
        buttons = buttons + IN_JUMP
    end

    if !bot:IsOnGround() and controller.NextJump > CurTime() then
        buttons = buttons + IN_DUCK
    end

    controller.NextRandomJump = controller.NextRandomJump or 0

    if controller.NextRandomJump < CurTime() and !controller.NextJump != 0 then -- knowing how enumerations work it's probably an awful idea to add a button twice
        controller.NextRandomJump = CurTime() + jump_delay + math.Rand(0,1)
        buttons = buttons + IN_JUMP
    end

    local weapon_list = bot:GetWeapons()
    local weapon = weapon_list[1]

    if weapon then
        for k,v in ipairs(weapon_list) do
            local new_score = quality_score[DMU.weapon_to_rarity[v:GetClass()]] or -1
            local old_score = quality_score[DMU.weapon_to_rarity[weapon:GetClass()]] or -1
            if ( new_score > old_score and (bot:GetAmmoCount(v:GetPrimaryAmmoType()) != 0 or v:Clip1() != 0) ) or (bot:GetAmmoCount(weapon:GetPrimaryAmmoType()) == 0 and (weapon:Clip1() == 0 or weapon:Clip1() == -1)) then
                weapon = v
            end       
        end

        bot:SelectWeapon(weapon:GetClass())
    end

    local random = math.random(2)

    if IsValid(botWeapon) and ( ( botWeapon:Clip1() == 0 ) or (!IsValid(target) and botWeapon:Clip1() <= botWeapon:GetMaxClip1() / 2) ) then
        buttons = buttons + IN_RELOAD
    end

    cmd:ClearButtons()
    cmd:ClearMovement()
    cmd:SetButtons(buttons)
end

function LeadBot.PlayerMove(bot, cmd, mv)
    if bot:IsFrozen() then return end
    local skill = bot_skill:GetInt()
    local aim_speed
    local dementia_level
    local shoot_body

    aim_speed = math.random(6 + skill * 2, 8 + skill * 2)
    dementia_level = 5 + (skill == 0 and 0 or ( (skill - 1) * 2) )
    shoot_body = (skill <= 1) and 1 or 0 -- am i trying too hard to avoid elseif chains

    local controller = bot.ControllerBot

    if !IsValid(controller) then
        bot.ControllerBot = ents.Create("leadbot_navigator")
        bot.ControllerBot:Spawn()
        bot.ControllerBot:SetOwner(bot)
        controller = bot.ControllerBot
    end

    --[[local min, max = controller:GetModelBounds()
    debugoverlay.Box(controller:GetPos(), min, max, 0.1, Color(255, 0, 0, 0), true)]]

    -- force a recompute
    if controller.PosGen and controller.P and controller.TPos ~= controller.PosGen then
        controller.TPos = controller.PosGen
        controller.P:Compute(controller, controller.PosGen)
    end

    if controller:GetPos() ~= bot:GetPos() then
        controller:SetPos(bot:GetPos())
    end

    if controller:GetAngles() ~= bot:EyeAngles() then
        controller:SetAngles(bot:EyeAngles())
    end

    mv:SetForwardSpeed(1200)

    if (bot.NextSpawnTime and bot.NextSpawnTime + 1 > CurTime()) or !IsValid(controller.Target) or controller.ForgetTarget < CurTime() or controller.Target:Health() < 1 then
        controller.Target = nil
    end

    if !IsValid(controller.Target) then
        -- Find Players
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= bot and ((ply:IsPlayer() and (!LeadBot.TeamPlay or (LeadBot.TeamPlay and (ply:Team() ~= bot:Team())))) or ply:IsNPC()) and ply:GetPos():DistToSqr(bot:GetPos()) < 2250000 then
                if ply:Alive() and controller:CanSee(ply) then
                    controller.Target = ply
                    controller.ForgetTarget = CurTime() + dementia_level
                end
            end
        end
    elseif controller:CanSee(controller.Target) then
        controller.ForgetTarget = CurTime() + dementia_level
    end

    local dt = util.QuickTrace(bot:EyePos(), bot:GetForward() * 45, bot)

    if IsValid(dt.Entity) and dt.Entity:GetClass() == "prop_door_rotating" then
        dt.Entity:Fire("OpenAwayFrom", bot, 0)
    end

    if !IsValid(controller.Target) and (!controller.PosGen or controller.LastSegmented < CurTime()) then
        -- Find pickups. Bots prefer it over anything else if it's close enough
        for _, ent in ipairs(ents.FindInSphere(bot:GetPos(), 768)) do
            if not bot:IsLineOfSightClear(ent) then continue end

            if health_pickups[ent:GetClass()] and (bot:Health() < bot:GetMaxHealth() * 0.7) and !ent:GetEmpty() then
                controller.PosGen = ent:GetPos()
                controller.LastSegmented = CurTime() + 3
                goto cont
                break
            elseif armor_pickups[ent:GetClass()] and (bot:Armor() < bot:GetMaxArmor()) and !ent:GetEmpty() then
                controller.PosGen = ent:GetPos()
                controller.LastSegmented = CurTime() + 3
                goto cont
                break
            elseif ent:GetClass() == "dmu_weapon_spawner" and !ent:GetEmpty() then
                controller.PosGen = ent:GetPos()
                controller.LastSegmented = CurTime() + 3
                goto cont
                break
            end
        end
        -- Find Team Objectives
        if DMU.BotTeamObjectives[bot:Team()] and !table.IsEmpty(DMU.BotTeamObjectives[bot:Team()]) then
            local closest_objective = DMU.BotTeamObjectives[bot:Team()][1]
            local pos = bot:GetPos()
            local clobj_pos
            for _, objective in ipairs(DMU.BotTeamObjectives[bot:Team()]) do
                local obj_pos = objective:GetPos()
                --if objective.Type == "brush" then obj_pos = objective:OBBCenter() end -- FUCK YOU -- FUCK YOU X2 IT GOT CHANGED AND :GETPOS() NOW WORKS AS EXPECTED WITH BRUSHES
                -- GOD DAMMIT FUCK
                clobj_pos = closest_objective:GetPos()
                --if closest_objective.Type == "brush" then clobj_pos = closest_objective:OBBCenter() end 
                
                if pos:DistToSqr(obj_pos) < pos:DistToSqr(clobj_pos) then
                    closest_objective = objective
                end
            end
            controller.PosGen = clobj_pos
            controller.LastSegmented = CurTime() + 5
            goto cont
        end
        -- Find Objectives
        if !table.IsEmpty(DMU.BotObjectives) then
            local closest_objective = DMU.BotObjectives[1]
            local pos = bot:GetPos()
            local clobj_pos
            for _, objective in ipairs(DMU.BotObjectives) do
                local obj_pos = objective:GetPos()
                --if objective.Type == "brush" then obj_pos = objective:OBBCenter() end -- FUCK YOU -- FUCK YOU X2 IT GOT CHANGED AND :GETPOS() NOW WORKS AS EXPECTED WITH BRUSHES
                -- GOD DAMMIT FUCK
                clobj_pos = closest_objective:GetPos()
                --if closest_objective.Type == "brush" then clobj_pos = closest_objective:OBBCenter() end 
                
                if pos:DistToSqr(obj_pos) < pos:DistToSqr(clobj_pos) then
                    closest_objective = objective
                end
            end
            controller.PosGen = clobj_pos
            controller.LastSegmented = CurTime() + 5
            goto cont
        end
        -- find a random spot on the map, and in 10 seconds do it again! -- THIS IN FACT DOES NOT IN FACT RETURN A RANDOM SPOT
        -- IT RETURNS A RANDOM HIDING SPOT. SOME MAPS DON'T HAVE HIDING SPOTS, SO IT FAILS
        //controller.PosGen = controller:FindSpot("random", {pos = Vector(96.859039, 761.333862, 2496.031250), radius = 12500})
        //if controller.PosGen == nil then
        local areas = navmesh.Find( bot:GetPos(), 12500, 512, 512 )
        controller.PosGen = areas[math.random(#areas)]:GetRandomPoint()
        //end
        controller.LastSegmented = CurTime() + 10

        ::cont::

    elseif IsValid(controller.Target) then
        -- move to our target
        local distance = controller.Target:GetPos():DistToSqr(bot:GetPos())
        controller.PosGen = controller.Target:GetPos()

        -- back up if the target is really close
        -- TODO: find a random spot rather than trying to back up into what could just be a wall
        -- something like controller.PosGen = controller:FindSpot("random", {pos = bot:GetPos() - bot:GetForward() * 350, radius = 1000})?
        if distance <= 90000 and !(bot:GetActiveWeapon().Melee or melee_weapons[bot:GetActiveWeapon():GetClass()]) then
            mv:SetForwardSpeed(-1200)
        end
    end

    -- movement also has a similar issue, but it's more severe...
    if !controller.P then
        return
    end

    local segments = controller.P:GetAllSegments()

    if !segments then return end

    local cur_segment = controller.cur_segment
    local curgoal = segments[cur_segment]

    -- got nowhere to go, why keep moving?
    if !curgoal then
        mv:SetForwardSpeed(0)
        return
    end

    -- think every step of the way!
    if segments[cur_segment + 1] and Vector(bot:GetPos().x, bot:GetPos().y, 0):DistToSqr(Vector(curgoal.pos.x, curgoal.pos.y)) < 100 then
        controller.cur_segment = controller.cur_segment + 1
        curgoal = segments[controller.cur_segment]
    end

    local goalpos = curgoal.pos

    if bot:GetVelocity():Length2DSqr() <= 225 then
        if controller.NextCenter < CurTime() then
            controller.strafeAngle = ((controller.strafeAngle == 1 and 2) or 1)
            controller.NextCenter = CurTime() + math.Rand(0.3, 0.65)
        elseif controller.nextStuckJump < CurTime() then
            if !bot:Crouching() then
                controller.NextJump = 0
            end
            controller.nextStuckJump = CurTime() + math.Rand(1, 2)
        end
    end

    if controller.NextCenter > CurTime() then
        if controller.strafeAngle == 1 then
            mv:SetSideSpeed(1500)
        elseif controller.strafeAngle == 2 then
            mv:SetSideSpeed(-1500)
        else
            mv:SetForwardSpeed(-1500)
        end
    end

    -- if controller.PosGen:DistToSqr(bot:GetPos()) <= 100 then
    --     print("AAA")
    --     mv:SetForwardSpeed(0)
    -- end

    -- jump
    if controller.NextJump ~= 0 and curgoal.type > 1 and controller.NextJump < CurTime() then
        controller.NextJump = 0
    end

    -- duck
    if curgoal.area:GetAttributes() == NAV_MESH_CROUCH then
        controller.NextDuck = CurTime() + 0.1
    end

    controller.goalPos = goalpos

    if GetConVar("developer"):GetBool() then
        controller.P:Draw()
    end

    -- eyesight

    local lerp = FrameTime() * aim_speed
    local lerpc = FrameTime() * 8

    if !LeadBot.LerpAim then
        lerp = 1
        lerpc = 1
    end

    local mva = ((goalpos + bot:GetCurrentViewOffset()) - bot:GetShootPos()):Angle()

    mv:SetMoveAngles(mva)

    if IsValid(controller.Target) then
        bot:SetEyeAngles(LerpAngle(lerp, bot:EyeAngles(), (controller.Target:EyePos() - Vector(0, 0, 48 * shoot_body) - bot:GetShootPos()):Angle()))
        return
    else
        if controller.LookAtTime > CurTime() then
            local ang = LerpAngle(lerpc, bot:EyeAngles(), controller.LookAt)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        else
            local ang = LerpAngle(lerpc, bot:EyeAngles(), mva)
            bot:SetEyeAngles(Angle(ang.p, ang.y, 0))
        end
    end
end

function LeadBot.Think()
    for _, bot in pairs(player.GetBots()) do
        if bot:IsLBot() then
            if LeadBot.RespawnAllowed and bot.NextSpawnTime and !bot:Alive() and bot.NextSpawnTime < CurTime() then
                bot:Spawn()
                return
            end

            -- the bots are competent enough to know how much ammo they have now, so it's unnecessary
            --[[local wep = bot:GetActiveWeapon()
            if IsValid(wep) then
                local ammoty = wep:GetPrimaryAmmoType() or wep.Primary.Ammo
                bot:SetAmmo(999, ammoty)
            end--]]
        end
    end
end