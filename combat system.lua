-- Combat System - Server Script (by blaze)

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- accessing modules 
local modules = ReplicatedStorage.Modules
local CombatManager = require(modules.CombatManager)  -- Manages individual player combat state
local Util = require(modules.Util)                    -- Utility functions (distance checks, visual effects)
local CONFIG = require(modules.CONFIG)                -- Combat configuration constants

-- REMOTE EVENTS
-- (Communication channels between client and server)
local eventsFolder = ReplicatedStorage:FindFirstChild("CombatEvents")

local Remotes = {
	Attack = eventsFolder.Attack,              -- Client requests attack execution
	Block = eventsFolder.Block,                -- Client toggles blocking state
	Dodge = eventsFolder.Dodge,                -- Client requests dodge action
	UpdateStamina = eventsFolder.UpdateStamina,    -- Server updates client stamina
	UpdateCombo = eventsFolder.UpdateCombo,        -- Server updates client combo count
	ApplyEffect = eventsFolder.ApplyEffect         -- Server notifies client of status effects
}


-- PLAYER MANAGER STORAGE
-- Stores CombatManager instances for each player, keyed by UserId
local PlayerManagers = {}
--[[
	Retrieves or creates a CombatManager for a player.
	Each player gets their own manager to track combat state independently.
	
]]
local function getOrCreateManager(player)
	if not PlayerManagers[player.UserId] then
		PlayerManagers[player.UserId] = CombatManager.new(player)
	end
	return PlayerManagers[player.UserId]
end

-- COMBAT FUNCTIONS
--[[
	Executes an attack from the attacking player.
	Handles validation, damage calculation, hit detection (players and NPCs),
	blocking/parrying, knockback, status effects, and statistics.
]]
local function performAttack(attacker, attackType)
	local manager = getOrCreateManager(attacker)

	print("[Combat] " .. attacker.Name .. " attempting " .. attackType)

	-- Validation: Check if attack is allowed (not stunned, has stamina, etc.)
	if not manager:ValidateAttack() then 
		warn("[Combat] Attack validation failed")
		return 
	end

	-- Check action requirements (stamina cost, cooldown)
	local canPerform, reason = manager:CanPerformAction(attackType)
	if not canPerform then
		warn("[Combat] Cannot perform action: " .. tostring(reason))
		return
	end

	-- Verify character exists and has required components
	local character = attacker.Character
	if not character then 
		warn("[Combat] No character found")
		return 
	end

	local parts = Util.GetCharacterParts(character)
	if not parts.Root or not parts.Humanoid then 
		warn("[Combat] Missing essential character parts")
		return 
	end

	print("[Combat] All checks passed, executing attack")

	-- Deduct stamina and start cooldown
	manager:ConsumeStamina(CONFIG.Stamina.Costs[attackType])
	manager:SetCooldown(attackType)

	-- Calculate base damage from config (module script)
	local baseDamage = attackType == "LightAttack" 
		and CONFIG.Combat.LightAttackDamage 
		or CONFIG.Combat.HeavyAttackDamage

	-- Roll for critical hit
	local isCritical = math.random() < CONFIG.Combat.CriticalChance

	-- Hit detection state
	local hitSomething = false  -- Track if we hit anything for combo purposes
	local hitTargets = {}       -- Prevent hitting same target multiple times

	--[[
		Processes a potential hit target (player or NPC).
		Checks distance, angle, blocking state, and applies damage/effects.
		
		-- targetCharacter = The character model to check
		-- targetPlayer  = The player object if target is a player, nil for NPCs
	]]
	local function processTarget(targetCharacter, targetPlayer)
		-- Skip if already hit this target or if it's the attacker
		if hitTargets[targetCharacter] then return end
		if targetCharacter == character then return end

		local targetParts = Util.GetCharacterParts(targetCharacter)

		-- Verify target is alive and has required parts
		if targetParts.Root and targetParts.Humanoid and targetParts.Humanoid.Health > 0 then
			-- Distance check: Is target within attack range?
			local distance = (parts.Root.Position - targetParts.Root.Position).Magnitude

			if distance <= CONFIG.Combat.AttackRange then
				-- Angle check: Is target in front of attacker?
				if Util.IsInFront(parts.Root, targetParts.Root, CONFIG.Combat.AttackAngle) then
					hitSomething = true
					hitTargets[targetCharacter] = true

					-- Calculate final damage with modifiers
					local finalDamage = manager:CalculateDamage(baseDamage, isCritical)

					print("[Combat] Hit detected on " .. targetCharacter.Name .. " - Base damage: " .. finalDamage)

					-- Check if target is blocking (only for players (not for npcs))
					local targetManager = targetPlayer and getOrCreateManager(targetPlayer)
					if targetManager and targetManager.IsBlocking then
						local blockTime = tick() - targetManager.BlockStartTime

						-- Perfect parry: Block within parry window
						if blockTime <= CONFIG.Block.ParryWindow then
							finalDamage = 0  -- Negate all damage
							-- Punish attacker with stun
							manager:ApplyStatusEffect("Stun", CONFIG.Block.ParryStunDuration)
							targetManager.Statistics.PerfectParries += 1
							print("[Combat] Perfect parry!")

							-- Show "PARRY!" indicator
							Util.CreateDamageIndicator(targetParts.Root.Position, 0, false)
						else
							-- Normal block: Reduce damage and drain target's stamina
							finalDamage = finalDamage * (1 - CONFIG.Block.DamageReduction)
							local staminaDrain = finalDamage * CONFIG.Block.StaminaDrainOnBlock
							targetManager:ConsumeStamina(staminaDrain)
							print("[Combat] Blocked! Reduced damage: " .. finalDamage)
						end
					end

					-- Apply damage if any remains after blocking
					if finalDamage > 0 then
						print("[Combat] Applying " .. finalDamage .. " damage to " .. targetCharacter.Name)
						targetParts.Humanoid:TakeDamage(finalDamage)

						-- Apply knockback force
						local knockbackForce = attackType == "LightAttack" 
							and CONFIG.Knockback.LightAttack 
							or CONFIG.Knockback.HeavyAttack

						-- Calculate knockback direction (away from attacker)
						local direction = (targetParts.Root.Position - parts.Root.Position).Unit

						-- Create temporary force to push target
						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.Velocity = direction * knockbackForce + Vector3.new(0, 10, 0)  -- Slight upward force
						bodyVelocity.MaxForce = Vector3.new(50000, 50000, 50000)
						bodyVelocity.Parent = targetParts.Root
						Debris:AddItem(bodyVelocity, CONFIG.Knockback.Duration)  -- Auto-cleanup
						print("[Combat] Knockback applied")

						-- Apply status effects (chance-based for heavy attacks)
						if attackType == "HeavyAttack" and math.random() < 0.3 then
							if targetManager then
								targetManager:ApplyStatusEffect("Bleed", CONFIG.StatusEffects.Bleed.Duration)
							end
							print("[Combat] Bleed effect applied")
						end

						-- Update combat statistics (only for players)
						if targetManager then
							manager.Statistics.TotalDamageDealt += finalDamage
							manager.Statistics.AttacksLanded += 1
							targetManager.Statistics.TotalDamageTaken += finalDamage
						end

						-- Create floating damage number
						Util.CreateDamageIndicator(targetParts.Root.Position, finalDamage, isCritical)
					end
				else
					print("[Combat] Target not in front")
				end
			else
				print("[Combat] Target out of range: " .. distance)
			end
		end
	end

	-- Hit detection phase 1: Check all players
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		if targetPlayer ~= attacker and targetPlayer.Character then
			processTarget(targetPlayer.Character, targetPlayer)
		end
	end

	-- Hit detection phase 2: Check all NPCs/Dummies in workspace
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model ~= character then
			-- Verify it's a valid character model
			local humanoid = model:FindFirstChild("Humanoid")
			local rootPart = model:FindFirstChild("HumanoidRootPart")

			if humanoid and rootPart then
				-- Ensure we don't double-process player characters
				local isPlayerCharacter = false
				for _, player in ipairs(Players:GetPlayers()) do
					if player.Character == model then
						isPlayerCharacter = true
						break
					end
				end

				-- Process as NPC if not a player character
				if not isPlayerCharacter then
					processTarget(model, nil)  -- nil = no player manager for NPCs
				end
			end
		end
	end

	-- Combo system: Increment on hit, reset on miss
	if hitSomething then
		manager:IncrementCombo()
	elseif CONFIG.Combo.ComboResetOnMiss then
		manager:ResetCombo()
		manager.Statistics.AttacksMissed += 1
	end
end

--[[
	Handles blocking state changes.
	Blocking reduces incoming damage but drains stamina.
	Perfect parries occur when blocking right before being hit.
	
	player: Player = The player toggling block
	isBlocking boolean - True when starting block, false when ending
]]
local function performBlock(player, isBlocking)
	local manager = getOrCreateManager(player)

	if isBlocking then
		-- Validate block can be performed (has stamina, not stunned)
		local canPerform = manager:CanPerformAction("Block")
		if canPerform then
			manager.IsBlocking = true
			manager.BlockStartTime = tick()  -- Record time for parry window calculation
			manager:ConsumeStamina(CONFIG.Stamina.Costs.Block)
		end
	else
		-- Stop blocking
		manager.IsBlocking = false
	end
end

--[[
	Executes a dodge maneuver.
	Dodges propel the player forward and grant brief invulnerability.
	Costs stamina and has a cooldown.
]]
local function performDodge(player)
	local manager = getOrCreateManager(player)

	-- Validate dodge can be performed
	local canPerform = manager:CanPerformAction("Dodge")
	if not canPerform then return end

	local character = player.Character
	if not character then return end

	local parts = Util.GetCharacterParts(character)
	if not parts.Root then return end

	-- Consume resources
	manager:ConsumeStamina(CONFIG.Stamina.Costs.Dodge)
	manager:SetCooldown("Dodge")

	-- Apply forward momentum in look direction
	local dodgeDirection = parts.Root.CFrame.LookVector
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = dodgeDirection * 50
	bodyVelocity.MaxForce = Vector3.new(50000, 0, 50000)  -- Only horizontal movement
	bodyVelocity.Parent = parts.Root
	Debris:AddItem(bodyVelocity, 0.2)  -- Brief force application

	-- Grant temporary invulnerability (checked in damage calculation)
	manager:ApplyStatusEffect("Dodging", 0.3)
end

-- EVENT CONNECTIONS
-- Wire up client requests to server handlers 
-- Handle attack requests from client (using remote events)
Remotes.Attack.OnServerEvent:Connect(function(player, attackType)
	-- Validate attack type to prevent exploits
	if attackType == "LightAttack" or attackType == "HeavyAttack" then
		performAttack(player, attackType)
	end
end)

-- Handle blocking state changes from client
Remotes.Block.OnServerEvent:Connect(function(player, isBlocking)
	performBlock(player, isBlocking)
end)

-- Handle dodge requests from client
Remotes.Dodge.OnServerEvent:Connect(function(player)
	performDodge(player)
end)

-- PLAYER LIFECYCLE MANAGEMENT
-- Initialize combat manager when player joins
Players.PlayerAdded:Connect(function(player)
	getOrCreateManager(player)
end)

-- Cleanup combat manager when player leaves
Players.PlayerRemoving:Connect(function(player)
	PlayerManagers[player.UserId] = nil
end)

-- UPDATE LOOP
-- Main game loop that updates all active combat managers

-- Update all player managers every frame
-- Handles stamina regeneration, status effect ticks, cooldown timers, etc.
RunService.Heartbeat:Connect(function(deltaTime)
	for _, manager in pairs(PlayerManagers) do
		manager:Update(deltaTime)
	end
end)
