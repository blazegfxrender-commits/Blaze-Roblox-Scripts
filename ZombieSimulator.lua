-- Get core Roblox services
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Storage for shared objects like Tools, Events
local Players = game:GetService("Players") -- Service to manage all players in the game
local RunService = game:GetService("RunService") -- Provides Heartbeat and Stepped events for frame-based updates
local CollectionService = game:GetService("CollectionService") -- Allows tagging of instances for easy retrieval
local DataStoreService = game:GetService("DataStoreService") -- Access to persistent cloud storage
local PlayerDataStore = DataStoreService:GetDataStore("PlayerStatsData") -- DataStore for saving player stats

-- References to remote events for client-server communication
local eventFolder = ReplicatedStorage:WaitForChild("Events")
local toolFolder = ReplicatedStorage:WaitForChild("ToolFolder")
local gun = toolFolder:WaitForChild("Gun") -- Reference to the Gun tool
local gunEvent = eventFolder:WaitForChild("GiveGun") -- RemoteEvent for purchasing gun
local fireEvent = eventFolder:WaitForChild("FireGun") -- RemoteEvent for firing gun

-- References to NPC template, NPC folder, and spawn area
local npcTemplate = ReplicatedStorage:WaitForChild("NPC") -- Template NPC used for cloning
local NpcFolder = workspace:WaitForChild("NpcFolder") -- Folder to store all spawned NPCs
local spawnArea = workspace:WaitForChild("SpawnArea") -- Region where NPCs spawn

-- Game constants for NPC behavior
local MAX_NPC = 10 -- Maximum number of NPCs at a time
local DETECTION_RANGE = 80 -- Distance within which NPC detects players
local ATTACK_RANGE = 5 -- Distance NPC must be within to attack player
local BASE_SPEED = 6 -- Base walk speed
local SPEED = BASE_SPEED + 3 -- Increased speed for NPCs
local DAMAGE = 15 -- Damage dealt by NPCs per attack
local ATTACK_COOLDOWN = 1.5 -- Cooldown between attacks in seconds

-- Function to create player leaderstats and load saved data
local function CreateStats(player)
	-- Create a folder named "leaderstats" under player
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Create IntValue for kills
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = leaderstats

	-- Create IntValue for coins
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats

	-- Create IntValue for level
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats

	-- Attempt to load saved data from DataStore
	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(player.UserId)
	end)

	local hasGun = false -- Track if player had gun previously

	if success and data then
		-- Load stats if they exist, fallback to defaults
		kills.Value = data.Kills or 0
		coins.Value = data.Coins or 100
		level.Value = data.Level or 1
		hasGun = data.HasGun or false
	else
		-- Defaults for new player or failed load
		kills.Value = 0
		coins.Value = 100
		level.Value = 1
	end

	-- If player had a gun, give it back
	if hasGun then
		local gunClone = gun:Clone()
		gunClone.Parent = player.Backpack -- Place in Backpack for immediate use
		if not player.StarterGear:FindFirstChild(gunClone.Name) then
			gunClone:Clone().Parent = player.StarterGear -- StarterGear ensures gun persists on respawn
		end
	end

	-- Connect level-up logic to changes in kills
	kills.Changed:Connect(function(newValue)
		-- Calculate expected level based on kills (1 level per 15 kills)
		local expectedLevel = math.floor(newValue / 15) + 1
		if expectedLevel > level.Value then
			level.Value = expectedLevel
			coins.Value += 100 -- Reward coins for leveling up
			print(player.Name .. " leveled up to Level " .. level.Value)
		end
	end)
end

-- Function to give gun to player
local function GiveGun(player)
	local gunClone = gun:Clone()
	gunClone.Parent = player.Backpack
	-- Add to StarterGear if not already present
	if not player.StarterGear:FindFirstChild(gun.Name) then
		gunClone:Clone().Parent = player.StarterGear
	end
end

-- Function to get random position inside spawn area
local function getRandomPosition()
	local size = spawnArea.Size -- Size vector of spawn region
	local pos = spawnArea.Position -- Center position of spawn area
	local randomX = math.random(-size.X/2, size.X/2)
	local randomZ = math.random(-size.Z/2, size.Z/2)
	-- Y position slightly above ground to avoid falling inside terrain
	return Vector3.new(pos.X + randomX, pos.Y + 2, pos.Z + randomZ)
end

-- Function to spawn NPC and add AI behavior
local function SpawnNpc()
	local clone = npcTemplate:Clone()
	clone.Parent = NpcFolder
	clone:MoveTo(getRandomPosition()) -- Teleport NPC to random position
	CollectionService:AddTag(clone, "FollowPlayer") -- Tag NPC for easy tracking in Heartbeat loop

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = SPEED -- Set NPC speed

		-- Connect to Died event for cleanup and rewards
		humanoid.Died:Connect(function()
			-- Reward the last player who damaged NPC
			local tag = humanoid:FindFirstChild("creator")
			if tag and tag.Value and tag.Value:FindFirstChild("leaderstats") then
				local stats = tag.Value.leaderstats
				local kills = stats:FindFirstChild("Kills")
				local coins = stats:FindFirstChild("Coins")

				if kills then kills.Value += 1 end -- Increment kills
				if coins then coins.Value += 50 end -- Reward coins
			end

			-- Remove NPC tag and destroy NPC after death
			task.wait(2) -- Wait for death animation
			if clone then
				CollectionService:RemoveTag(clone, "FollowPlayer")
				clone:Destroy()
			end
		end)
	end

	-- BoolValue to control NPC attack cooldown
	local attackTag = Instance.new("BoolValue")
	attackTag.Name = "CanAttack"
	attackTag.Value = true
	attackTag.Parent = clone
end

-- Function to get the closest player within NPC detection range
local function GetClosestPlayer(npcHRP)
	local nearestPlayer, shortestDistance = nil, DETECTION_RANGE
	for _, player in pairs(Players:GetPlayers()) do -- Loop through all players and check distance
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local distance = (npcHRP.Position - player.Character.HumanoidRootPart.Position).Magnitude -- distance will be between npc and player.
			if distance < shortestDistance then -- If player is closer than current closest player, update closest player.
				shortestDistance = distance
				nearestPlayer = player
			end
		end
	end
	return nearestPlayer -- returns nearest player to npc.
end

-- Function for NPC attacking player
local function AttackPlayer(npc, target)
	if not npc:FindFirstChild("CanAttack") or not npc.CanAttack.Value then return end

	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	npc.CanAttack.Value = false -- Disable attack until cooldown ends
	humanoid:TakeDamage(DAMAGE) -- Reduce target health

	-- Reset attack ability after cooldown using task.delay
	task.delay(ATTACK_COOLDOWN, function()
		if npc then
			npc.CanAttack.Value = true
		end
	end)
end

-- Spawn NPC loop to maintain max NPC count
task.spawn(function()
	while true do
		task.wait(1) -- Wait 1 second between checks
		if #NpcFolder:GetChildren() < MAX_NPC then
			SpawnNpc()
		end
	end
end)

-- Heartbeat loop for NPC movement and attack
RunService.Heartbeat:Connect(function(dt)
	for _, npc in pairs(CollectionService:GetTagged("FollowPlayer")) do -- Loop through NPCs that should follow player
		local hrp = npc:FindFirstChild("HumanoidRootPart")
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if hrp and humanoid and humanoid.Health > 0 then -- Check NPC is alive
			local target = GetClosestPlayer(hrp) -- Get closest player
			if target and target.Character then
				local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
				local targetHumanoid = target.Character:FindFirstChildOfClass("Humanoid")
				if targetHRP and targetHumanoid and targetHumanoid.Health > 0 then
					local direction = (targetHRP.Position - hrp.Position).Unit -- Normalized vector to target
					local distance = (targetHRP.Position - hrp.Position).Magnitude
					hrp.CFrame = CFrame.lookAt(hrp.Position, targetHRP.Position) -- Rotate NPC to face player
					if distance > ATTACK_RANGE then
						hrp.CFrame = hrp.CFrame + direction * SPEED * dt -- Move NPC toward player smoothly
					else
						AttackPlayer(npc, target) -- Attack if in range
					end
				end
			end
		end
	end
end)

-- Function to save player data to DataStore
local function SavePlayerData(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end
	local kills = stats:FindFirstChild("Kills")
	local coins = stats:FindFirstChild("Coins")
	local level = stats:FindFirstChild("Level")
	if not (kills and coins and level) then return end

	-- Check if player currently has a gun equipped or in backpack
	local hasGun = player.Backpack:FindFirstChild("Gun") or (player.Character and player.Character:FindFirstChild("Gun"))

	-- Use UpdateAsync to safely update player data
	local success, err = pcall(function()
		PlayerDataStore:UpdateAsync(player.UserId, function(oldData)
			oldData = oldData or {}
			oldData.Kills = kills.Value
			oldData.Coins = coins.Value
			oldData.Level = level.Value
			oldData.HasGun = hasGun and true or false
			return oldData -- Return updated data to DataStore
		end) 
	end)

	if not success then
		warn("Failed to save data for " .. player.Name .. ": " .. err)
	end
end

-- Connect events for purchasing and firing guns
gunEvent.OnServerEvent:Connect(function(player)
	local stats = player:WaitForChild("leaderstats")
	local coins = stats:WaitForChild("Coins")
	if coins.Value >= 100 then
		coins.Value -= 100 -- Deduct coins for gun purchase
		GiveGun(player)
	else
		print("Not enough coins!")
	end
end)

-- Gun firing event
fireEvent.OnServerEvent:Connect(function(player, mousePosition)
	local Gun = player.Character and player.Character:FindFirstChild("Gun")
	if not Gun then return end -- Ensure player has the gun

	local flare = Gun:FindFirstChild("Flare")
	if not flare then return end -- Ensure flare exists

	local flarePos = flare.Position -- part where bullet starts
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {player.Character} -- to avoid player killing himselft
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local direction = (mousePosition - flarePos).Unit * 100 -- direction of bullet  
	local rayResult = workspace:Raycast(flarePos, direction, raycastParams) -- creating the ray

	if rayResult then
		local hitPart = rayResult.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model") 
		if model and model:FindFirstChild("Humanoid") then -- if the bullet hit a humanoid:
			local humanoid = model:FindFirstChild("Humanoid") -- gets the humanoid. Important because humanoid contains human properties such as health, speed etc.
			-- Tag NPC with player who last damaged it
			local tag = Instance.new("ObjectValue")
			tag.Name = "creator"
			tag.Value = player
			tag.Parent = humanoid
			game.Debris:AddItem(tag, 2) -- Clean tag automatically

			if hitPart.Name == "Head" then -- If the head was hit, deal 80 damage
				humanoid:TakeDamage(80) -- Headshot damage
			else
				humanoid:TakeDamage(20) -- Normal damage
			end
		end
	end
end)

-- Connect player join to stats creation
Players.PlayerAdded:Connect(CreateStats)
-- Connect player leaving to saving stats
Players.PlayerRemoving:Connect(SavePlayerData)
-- Save all data on server close
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		SavePlayerData(player)
	end
end)
