----------------------------------------------------------------
--// LEADERSTATS: Creating, Saving, and Loading Coins + EXP
----------------------------------------------------------------
-- Roblox DataStore is used here to save player progress between sessions.
-- Creates "leaderstats" which shows up on the in-game leaderboard (TAB key).
-- Each player will have "Coins" and "EXP" stats that are saved/loaded.
local DataStoreService = game:GetService("DataStoreService")
local PlayerCoins = DataStoreService:GetDataStore("PlayerCoins")
local PlayerExp = DataStoreService:GetDataStore("PlayerExp")

-- Runs when a player joins the game
game.Players.PlayerAdded:Connect(function(player)
	-- Create leaderstats folder (required to display stats on Roblox leaderboard)
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	--create coins stats:
	local coins = Instance.new("IntValue", leaderstats)
	coins.Name = "Coins"
	coins.Value = 0 

    --create exp stats:
	local exp = Instance.new("IntValue", leaderstats)
	exp.Name = "EXP"
	exp.Value = 0

	-- Try to load saved Coins
	local success, currentCoins = pcall(function()
		return PlayerCoins:GetAsync(player.UserId)
	end)
	if success then
		coins.Value = currentCoins
	else
		warn("Failed to load data for player: " .. player.Name)
	end

	-- Try to load saved EXP
	local success, currentExp = pcall(function()
		return PlayerExp:GetAsync(player.UserId)
	end)
	if success then
		exp.Value = currentExp
	else
		warn("Failed to load data for player: " .. player.Name)
	end

end)

-- Runs when a player leaves the game
game.Players.PlayerRemoving:Connect(function(player)
	-- Make sure leaderstats exist before saving
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	-- Get stats
	local Coins = leaderstats:FindFirstChild("Coins")
	if not Coins then return end

	local exp = leaderstats:FindFirstChild("EXP")
	if not exp then return end

	-- Save Coins value
	local success, errorMessage = pcall(function()
		PlayerCoins:SetAsync(player.UserId, Coins.Value)
	end)
	if not success then
		warn("Failed to save data for player: " .. player.Name .. ". Error: " .. errorMessage)
	end

	--saves EXP Value:
	local success, errorMessage = pcall(function()
		PlayerExp:SetAsync(player.UserId, exp.Value)
	end)
	if not success then
		warn("Failed to save data for player: " .. player.Name .. ". Error: " .. errorMessage)
	end
end)

----------------------------------------------------------------
--// TOOL GIVING SYSTEM
----------------------------------------------------------------
-- Players can receive tools (Sword, Potion, Gun) through RemoteEvents.
-- When client sends event → server clones tool → places in Backpack (usable immediately)
-- Also places in StarterGear → so player respawns with it after dying.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SwordEvent = ReplicatedStorage.SwordEvent
local PotionEvent = ReplicatedStorage.PotionEvent
local GunEvent = ReplicatedStorage.GunEvent

-- Tool references from ReplicatedStorage
local Tools = ReplicatedStorage.Tools
local Sword = Tools:WaitForChild("Sword")
local potion = Tools:WaitForChild("Potion")
local Gun = Tools:WaitForChild("Gun")

-- Functions for giving tools
local function GiveSword(plr)
	local SwordClone = Sword:Clone()
	SwordClone.Parent = plr.Backpack -- for immediate use

	if not plr.StarterGear:FindFirstChild(Sword.Name) then
		local SwordClone = Sword:Clone()
		SwordClone.Parent = plr.StarterGear -- saves on respawn
	end
end

--The next two Functions are similar like GiveSword() function.

local function GivePotion(plr)
	local PotionClone = potion:Clone()
	PotionClone.Parent = plr.Backpack  

	if not plr.StarterGear:FindFirstChild(potion.Name) then
		local PotionClone = potion:Clone()
		PotionClone.Parent = plr.StarterGear
	end
end

local function GiveGun(plr)
	local GunClone = Gun:Clone()
	GunClone.Parent = plr.Backpack

	if not plr.StarterGear:FindFirstChild(Gun.Name) then
		local GunClone = Gun:Clone()
		GunClone.Parent = plr.StarterGear
	end
end

-- RemoteEvent connections:
-- To connect Client Side (local script) to Server Side (server script) 
SwordEvent.OnServerEvent:Connect(function(player)
	GiveSword(player)
end)

PotionEvent.OnServerEvent:Connect(function(player)
	GivePotion(player)
end)

GunEvent.OnServerEvent:Connect(function(player)
	GiveGun(player)
end)

----------------------------------------------------------------
--// GUN SHOOTING SYSTEM
----------------------------------------------------------------
-- This uses Raycasting to simulate bullets:
-- 1. Get gun barrel (Shot part) as ray origin
-- 2. Calculate direction from gun → mouse click position
-- 3. Ignore player’s own character so they don’t shoot themselves
-- 4. If ray hits a Humanoid, apply damage (80 for headshot, 10 otherwise)
local GunFireEvent = game:GetService("ReplicatedStorage"):WaitForChild("GunFire")

GunFireEvent.OnServerEvent:Connect(function(player, mousePos)
	local gun = player.Character and player.Character:FindFirstChild("Gun")
	if not gun then return end

	local Shot = gun.Shot
	if not Shot then return end

	-- Ray start position and direction
	local origin = Shot.Position 
	local direction = (mousePos - Shot.Position).Unit * 150

	-- Ignore shooting player
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {player.Character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Cast ray
	local rayCastResult = workspace:Raycast(origin, direction, params)

	-- Process hit
	if rayCastResult then
		local rayinstance = rayCastResult.Instance
		local model = rayinstance:FindFirstAncestorOfClass("Model")
		if model then
			if model:FindFirstChild("Humanoid") then
				if rayinstance.Name == "Head" then
					model:FindFirstChild("Humanoid"):TakeDamage(80)-- headshot damage
				else
					model:FindFirstChild("Humanoid"):TakeDamage(10)-- body damage
				end
			end
		end
	end
end)

----------------------------------------------------------------
--// INCREASE / DECREASE COINS
----------------------------------------------------------------
-- Two RemoteEvents allow client to request stat changes.
-- Increase adds 20 Coins, Decrease removes 20 Coins.
-- (Good for in-game buttons or shop system testing.)

--Remote Events used to connect client side to server side
--When button is pressed, it fires event to server
local remoteEventsFolder = ReplicatedStorage.StatHandler
local IncreaseEvent = remoteEventsFolder.IncreaseStat
local DecreaseEvent = remoteEventsFolder.DecreaseStat

local function IncreaseValue(plr)
	local stats = plr:FindFirstChild("leaderstats")
	if not stats then return end -- making sure that there is a leaderstats

	local coins = stats:FindFirstChild("Coins") 
	if not coins then return end -- making sure that there is a coins value

	coins.Value += 20 --Value of Coins increase by 20
end

local function DecreaseValue(plr)
	local stats = plr:FindFirstChild("leaderstats")
	if not stats then return end -- making sure that there is a leaderstats

	local coins = stats:FindFirstChild("Coins")
	if not coins then return end -- making sure that there is a coins value

	coins.Value -= 20 --Value of Coins decrease by 20
end

--Running Server Side when button is pressed with the help of remote events:
IncreaseEvent.OnServerEvent:Connect(function(player)
	IncreaseValue(player)
end)

DecreaseEvent.OnServerEvent:Connect(function(player)
	DecreaseValue(player)
end)

----------------------------------------------------------------
--// TEAM SWITCHING SYSTEM
----------------------------------------------------------------
-- Allows players to manually switch between Blue and Green teams
-- through RemoteEvents. Useful for lobby/team selection UI.

local BlueTeamEvent = ReplicatedStorage:WaitForChild("BlueTeam") -- RemoteEvent for switching to Blue Team
local GreenTeamEvent = ReplicatedStorage:WaitForChild("GreenTeam") -- RemoteEvent for switching to Green Team

local players = game:GetService("Players")
local Teams = game:GetService("Teams") --Server associated with handling Teams

local blueTeam = Teams.BlueTeam --Refers to Blue Team
local greenTeam = Teams.GreenTeam --Refers to Green Team

BlueTeamEvent.OnServerEvent:Connect(function(player)
	player.Team = blueTeam --Switching player to Blue Team 
end)

GreenTeamEvent.OnServerEvent:Connect(function(player)
	player.Team = greenTeam --Switching player to Green Team 
end)

----------------------------------------------------------------
--// TELEPORT PORTAL
----------------------------------------------------------------
-- When player touches a special part (Portal) in the game,
-- they are teleported to another place (different game universe/placeId).

local teleportService = game:GetService("TeleportService") --Service associated with teleporting players
local placeId = 93049670096369 -- destination place
local teleportPart = game.Workspace:WaitForChild("TeleportPart") --Part that player will touch to teleport(Portal)
local players = game:GetService("Players")

--When the Player touches the part (portal), the system identifies weather it is a humanoid or not.
--If it is a humanoid, then the player is teleported to the other place.
game.Players.PlayerAdded:Connect(function(player)
	teleportPart.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			teleportService:Teleport(placeId, player)
		end
	end)
end)

----------------------------------------------------------------
--// GAME PASS HANDLING + PURCHASE HISTORY
----------------------------------------------------------------
-- 1. On join → check if player owns GamePass, reward if true.
-- 2. When GamePass is purchased → reward player immediately.
-- 3. Save purchase history to DataStore so developer can track.

local GamePassId = 1503797578
local marketPlaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local DataStore = game:GetService("DataStoreService")
local PurchaseHistory = DataStore:GetDataStore("PurchaseHistory")

-- On join: check if they own GamePass
game.Players.PlayerAdded:Connect(function(player)
	local haspass = false

	local success, errorMsg = pcall(function()
		haspass = marketPlaceService:UserOwnsGamePassAsync(player.UserId, GamePassId)
	end)

	if not success then
		error(errorMsg)
		return
	end

	if haspass then
		local stats = player.leaderstats
		local coins = stats:FindFirstChild("Coins")
		local exp = stats:FindFirstChild("EXP")

		coins.Value += 100
		exp.Value += 500
	end

	-- Print purchase history for debug
	local data = PurchaseHistory:GetAsync(player.UserId)
	if data then
		for i,reciept in ipairs(data) do
			for key,value in pairs(reciept) do
				print(key, value)
			end
		end
	end

end)

-- When player buys GamePass in-game, features of GamePass is given immediately:
marketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, Id, success)
	if success and Id == GamePassId then
		local stats = player.leaderstats
		local coins = stats:FindFirstChild("Coins")
		local exp = stats:FindFirstChild("EXP")

		coins.Value += 100
		exp.Value += 500

		-- Record purchase
		local reciept = {
			Name = "VIP",
			ID = Id,
			Date = os.date("%x"),
			Price = 100
		}

		-- Save to PurchaseHistory
		local success, data = pcall(function()
			return PurchaseHistory:GetAsync(player.UserId)
		end)
		if not success then
			error("Failed to fetch history")
			return
		end
		-- if no data
		if data == nil then
			data = {}
		end
		-- add reciept to data
		table.insert(data, reciept)
		local success, errormsg = pcall(function()
			PurchaseHistory:SetAsync(player.UserId, data)
		end)

		if not success then
			error(errormsg)
		end

	end
end)

----------------------------------------------------------------
--// DEVELOPER PRODUCTS 
----------------------------------------------------------------
-- Unlike GamePasses, dev products can be bought multiple times.
-- This script handles:
--   1. SpeedProduct → temporary speed boost for 15s
--   2. CoinsProduct → adds 100 coins to player

local CoinsProduct = 3419943792 --product 1 that gives 100 coins
local SpeedProduct = 3419943791 --product 2 that gives 50 walkspeed

local product = {}

--Function that gives player speed boost for 15 seconds:
product[SpeedProduct] = function(player)
	if player then
		local Char = player.Character
		if Char then
			local humanoid = Char:FindFirstChild("Humanoid") --Confirming that the player has a humanoid
			if humanoid then
				humanoid.WalkSpeed = 50 -- increasing the walkspeed 

				task.delay(15, function() -- function to return walkspeed to normal after 15 seconds
					humanoid.WalkSpeed = 16
				end)
			end
		end
	end
	return true
end

--Function that gives player 100 coins:
product[CoinsProduct] = function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then -- confirming that the player has leaderstats
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then -- confirming that the player has coins
			coins.Value += 100 -- adding 100 coins to the player
		end
	end
	return true
end

-- Process dev product purchases:
marketPlaceService.ProcessReceipt = function(receiptInfo)
	local playerId = receiptInfo.PlayerId
	local ProductId = receiptInfo.ProductId

	local player = game.Players:GetPlayerByUserId(playerId)

	if product[ProductId] then
		local result = product[ProductId](player)

		if result then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end
