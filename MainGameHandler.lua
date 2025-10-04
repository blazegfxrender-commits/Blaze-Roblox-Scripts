--[[
    Player Coins and EXP System with Data Persistence:
    Description: This script creates a leaderboard for Coins and EXP, loads data when the player joins, 
                 and saves data when the player leaves. Data is stored using DataStoreService.
]]
-- Get the DataStoreService, which allows us to save and load persistent player data
local DataStoreService = game:GetService("DataStoreService")

-- Create a DataStore specifically for storing player Coins
local PlayerCoins = DataStoreService:GetDataStore("PlayerCoins")

-- Create a DataStore specifically for storing player Exp
local PlayerExp = DataStoreService:GetDataStore("PlayerExp")

-- Event: Triggered when a player joins the game
game.Players.PlayerAdded:Connect(function(player)
	
	-- Create a folder called "leaderstats" inside the player object
	-- Roblox automatically displays IntValues inside this folder on the in-game leaderboard GUI
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	-- Create an IntValue to store Coins for this player
	local coins = Instance.new("IntValue", leaderstats)
	coins.Name = "Coins"
	coins.Value = 0 -- Default value in case the player has no saved data yet

	-- Create an IntValue to store EXP for this player
	local exp = Instance.new("IntValue", leaderstats)
	exp.Name = "EXP"
	exp.Value = 0 -- Default value

	-- Attempt to load the player's saved Coins from the DataStore
	-- pcall (protected call) is used to safely handle errors like network issues
	local success, currentCoins = pcall(function()
		return PlayerCoins:GetAsync(player.UserId) -- Fetch coins by unique UserId
	end)
	
	-- If loading succeeds and data exists, assign it to the coins IntValue
	if success then
		coins.Value = currentCoins
	else
		-- If loading fails, display a warning in the output
		warn("Failed to load data for player: " .. player.Name)
	end

	-- Attempt to load the player's saved EXP from the DataStore
	local success, currentExp = pcall(function()
		return PlayerExp:GetAsync(player.UserId) -- Fetch EXP by unique UserId
	end)
	
	if success then
		-- If loading succeeds and data exists, assign it to the exp IntValue
		exp.Value = currentExp
	else
		-- If loading fails, display a warning in the output
		warn("Failed to load data for player: " .. player.Name)
	end

end)

-- Event: Triggered when a player leaves the game
game.Players.PlayerRemoving:Connect(function(player)
	
	-- Locate the leaderstats folder inside the player object
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end -- Exit if leaderstats doesn't exist
	
	-- Locate the Coins IntValue inside leaderstats
	local Coins = leaderstats:FindFirstChild("Coins")
	if not Coins then return end -- Exit if Coins doesn't exist

	-- Locate the EXP IntValue inside leaderstats
	local exp = leaderstats:FindFirstChild("EXP")
	if not exp then return end -- Exit if EXP doesn't exist

	-- Attempt to save the player's Coins to the DataStore
	local success, errorMessage = pcall(function()
		PlayerCoins:SetAsync(player.UserId, Coins.Value)  -- Save Coins value using player's userId
	end)
	if not success then
		-- Display a warning if saving fails
		warn("Failed to save data for player: " .. player.Name .. ". Error: " .. errorMessage)
	end

	-- Attempt to save the player's EXP to the DataStore
	local success, errorMessage = pcall(function()
		PlayerExp:SetAsync(player.UserId, exp.Value) -- Save EXP value using player's UserId
	end)
	if not success then
		-- Display a warning if saving fails
		warn("Failed to save data for player: " .. player.Name .. ". Error: " .. errorMessage)
	end
end)

--[[
	Giving Tools (Sword, Potion, Gun) to Players:
    Description: This script listens for remote events from the client to give players specific tools.
                 Tools are cloned from ReplicatedStorage and added to both the player's Backpack 
                 (for immediate use) and StarterGear (so they keep the tool on respawn).
]]

-- Get the ReplicatedStorage service, which stores RemoteEvents and reusable assets
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get references to RemoteEvents for giving specific tools
-- RemoteEvents allow communication from client to server
local SwordEvent = ReplicatedStorage.SwordEvent
local PotionEvent = ReplicatedStorage.PotionEvent
local GunEvent = ReplicatedStorage.GunEvent

-- Get the Tools folder in ReplicatedStorage where the original tool instances are stored
local Tools = ReplicatedStorage.Tools

-- Get individual tools (Sword, Potion, Gun) from the Tools folder
-- WaitForChild ensures the script waits until the tool exists in ReplicatedStorage
local Sword = Tools:WaitForChild("Sword")
local potion = Tools:WaitForChild("Potion")
local Gun = Tools:WaitForChild("Gun")

-- Function to give a Sword to a player
local function GiveSword(plr)
	
	-- Clone the original Sword from ReplicatedStorage
	local SwordClone = Sword:Clone()
	
	-- Place the cloned Sword in the player's Backpack so they can use it immediately
	SwordClone.Parent = plr.Backpack 

	-- Check if the player already has the Sword in StarterGear
	-- StarterGear ensures the tool persists across respawns
	if not plr.StarterGear:FindFirstChild(Sword.Name) then
		local SwordClone = Sword:Clone()
		SwordClone.Parent = plr.StarterGear --clone again for starter gear
	end
end

-- Function to give a Potion to a player
local function GivePotion(plr)
	local PotionClone = potion:Clone() -- Clone the Potion
	PotionClone.Parent = plr.Backpack  -- Give it to the player's backpack

	-- Add to StarterGear if player doesn't already have it
	if not plr.StarterGear:FindFirstChild(potion.Name) then
		local PotionClone = potion:Clone()
		PotionClone.Parent = plr.StarterGear
	end
end

-- Function to give a Gun to a player
local function GiveGun(plr)
	local GunClone = Gun:Clone() -- Clone the Gun
	GunClone.Parent = plr.Backpack -- Give it to the player's backpack

	-- Add to StarterGear if player doesn't already have it
	if not plr.StarterGear:FindFirstChild(Gun.Name) then
		local GunClone = Gun:Clone()
		GunClone.Parent = plr.StarterGear
	end
end

-- Connect SwordEvent to the GiveSword function
-- When a player triggers SwordEvent from the client, the server gives them a Sword
SwordEvent.OnServerEvent:Connect(function(player)
	GiveSword(player)
end)

-- Connect PotionEvent to the GivePotion function
PotionEvent.OnServerEvent:Connect(function(player)
	GivePotion(player)
end)

-- Connect GunEvent to the GiveGun function
GunEvent.OnServerEvent:Connect(function(player)
	GiveGun(player)
end)

--[[
    Gun Firing Server Script:
    Description: Handles gun shooting logic using RemoteEvents. 
                 When a player fires their gun, the server performs a raycast
                 to detect hits and applies damage to humanoids.
]]

-- Get the RemoteEvent from ReplicatedStorage that the client fires when shooting
local GunFireEvent = game:GetService("ReplicatedStorage"):WaitForChild("GunFire")

-- Connect a function to handle gun firing whenever a player triggers the event
-- 'player' is the player who fired, 'mousePos' is the position where they aimed
GunFireEvent.OnServerEvent:Connect(function(player, mousePos)
	
	-- Ensure the player has a character and a gun in their character
	local gun = player.Character and player.Character:FindFirstChild("Gun")
	if not gun then return end -- Exit if gun doesn't exist

	-- Ensure the gun has a "Shot" part which represents the gun's muzzle or origin point
	local Shot = gun.Shot
	if not Shot then return end -- Exit if no Shot part

	-- Set the origin of the ray at the Shot's position
	local origin = Shot.Position 
	
	-- Calculate direction vector towards the target (mouse position)
	-- Multiply by 150 to define the maximum shooting range
	local direction = (mousePos - Shot.Position).Unit * 150

	-- Create RaycastParams to control what the ray can hit
	local params = RaycastParams.new()
	-- Exclude the player's own character from raycasting to avoid self-hit
	params.FilterDescendantsInstances = {player.Character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Perform the raycast in the workspace
	local rayCastResult = workspace:Raycast(origin, direction, params)

	-- If the ray hits something
	if rayCastResult then
		
		-- Get the exact part that was hit
		local rayinstance = rayCastResult.Instance
		
		-- Try to find the model that this part belongs to (usually a character model)
		local model = rayinstance:FindFirstAncestorOfClass("Model")
		
		if model then
			-- Check if the model has a Humanoid (so it can take damage)
			if model:FindFirstChild("Humanoid") then
				-- If the part hit is a Head, deal high damage (headshot)
				if rayinstance.Name == "Head" then
					model:FindFirstChild("Humanoid"):TakeDamage(80)
				else
					-- Otherwise, deal normal damage for body shots
					model:FindFirstChild("Humanoid"):TakeDamage(10)
				end
			end
		end
	end
end)

--[[
    Coins Increase/Decrease Handler
    Description: This script listens to RemoteEvents from the client to increase or decrease
                 the player's Coins in leaderstats. Useful for rewards, purchases, or penalties.
]]

-- Get the folder in ReplicatedStorage containing the RemoteEvents
local remoteEventsFolder = ReplicatedStorage.StatHandler

-- Get references to the RemoteEvents for increasing and decreasing stats
local IncreaseEvent = remoteEventsFolder.IncreaseStat
local DecreaseEvent = remoteEventsFolder.DecreaseStat

-- Function to increase a player's Coins by 20
local function IncreaseValue(plr)
	-- Get the player's leaderstats folder
	local stats = plr:FindFirstChild("leaderstats")
	if not stats then return end -- Exit if leaderstats doesn't exist

	-- Get the Coins IntValue inside leaderstats
	local coins = stats:FindFirstChild("Coins") 
	if not coins then return end -- Exit if Coins doesn't exist

	-- Increment the Coins value by 20
	coins.Value += 20 
end

-- Function to decrease a player's Coins by 20
local function DecreaseValue(plr)
	-- Get the player's leaderstats folder
	local stats = plr:FindFirstChild("leaderstats")
	if not stats then return end -- Exit if	leaderstats doesn't exist

	-- Get the Coins IntValue inside leaderstats
	local coins = stats:FindFirstChild("Coins")
	if not coins then return end -- Exit if Coins doesn't exist

	-- Decrement the Coins value by 20
	coins.Value -= 20 
end

-- Connect the IncreaseEvent to the IncreaseValue function
-- When a player triggers IncreaseStat from the client, their Coins increase
IncreaseEvent.OnServerEvent:Connect(function(player)
	IncreaseValue(player)
end)

-- Connect the DecreaseEvent to the DecreaseValue function
-- When a player triggers DecreaseStat from the client, their Coins decrease
DecreaseEvent.OnServerEvent:Connect(function(player)
	DecreaseValue(player)
end)

--[[
    Team Selection Handler:
    Description: This script allows players to join a team (Blue or Green) using RemoteEvents.
                 The player's Team property is set to the selected Team object.
]]

-- Get RemoteEvents from ReplicatedStorage for choosing teams
local BlueTeamEvent = ReplicatedStorage:WaitForChild("BlueTeam") 
local GreenTeamEvent = ReplicatedStorage:WaitForChild("GreenTeam") 

-- Get Services
local players = game:GetService("Players") -- Service that manages all players
local Teams = game:GetService("Teams") -- Service that manages all team objects

-- Get references to the Team objects in the Teams service
local blueTeam = Teams.BlueTeam -- Team object for BlueTeam
local greenTeam = Teams.GreenTeam -- Team object for GreenTeam

-- When a player triggers the BlueTeam RemoteEvent
-- Set their Team property to the BlueTeam object
BlueTeamEvent.OnServerEvent:Connect(function(player)
	player.Team = blueTeam 
end)

-- When a player triggers the GreenTeam RemoteEvent
-- Set their Team property to the GreenTeam object
GreenTeamEvent.OnServerEvent:Connect(function(player)
	player.Team = greenTeam 
end)

--[[
    Teleport Player on Touch:
    Description: This script teleports a player to another place when they touch a specific part.
                 It uses the TeleportService to send the player to a new PlaceId.
]]

-- Get Roblox services
local teleportService = game:GetService("TeleportService")  -- Allows teleporting players to other places
local placeId = 93049670096369 -- Set the destination PlaceId for teleportation
local teleportPart = game.Workspace:WaitForChild("TeleportPart") -- Get the part that triggers the teleport when touched
local players = game:GetService("Players") -- Manages all the players in the game

-- Event triggered when a new player joins the game
game.Players.PlayerAdded:Connect(function(player)
	
	-- Event triggered when something touches the teleportPart
	teleportPart.Touched:Connect(function(hit)
		
		-- Check if the object touching the part has a Humanoid (i.e., is a character)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			-- Teleport the player who joined (from PlayerAdded) to the specified PlaceId
			teleportService:Teleport(placeId, player)
		end
	end)
end)

--[[
    Game Pass Purchase Handler:
    Description: This script checks if a player owns a specific Game Pass when they join,
                 rewards them if they do, and tracks purchase history using DataStore.
]]

-- Set the GamePass ID you want to check
local GamePassId = 1503797578
local marketPlaceService = game:GetService("MarketplaceService") -- Handles game pass checks and purchases
local Players = game:GetService("Players") -- Manages all the players
local DataStore = game:GetService("DataStoreService") -- Used to store persistent data

-- Create a DataStore to track purchase history
local PurchaseHistory = DataStore:GetDataStore("PurchaseHistory")

-- Event triggered when a player joins the game
game.Players.PlayerAdded:Connect(function(player)
	
	local haspass = false -- Will store whether the player owns the game pass

	-- Check if the player owns the Game Pass
	-- pcall is used to safely handle potential errors from the web request
	local success, errorMsg = pcall(function()
		haspass = marketPlaceService:UserOwnsGamePassAsync(player.UserId, GamePassId)
	end)

	-- If there was an error checking ownership, stop execution and show error
	if not success then
		error(errorMsg)
		return
	end

	-- If the player owns the game pass, reward them
	if haspass then
		local stats = player.leaderstats -- Get player's leaderboard stats
		local coins = stats:FindFirstChild("Coins") -- Get the "Coins" stat
		local exp = stats:FindFirstChild("EXP") -- Get the "EXP" stat

		coins.Value += 100 -- Reward 100 coins
		exp.Value += 500 -- Reward 500 EXP
	end

	-- Fetch the player's purchase history from DataStore
	local data = PurchaseHistory:GetAsync(player.UserId)
	if data then
		-- Print out all previous receipts for debugging/logging
		for i,reciept in ipairs(data) do
			for key,value in pairs(reciept) do
				print(key, value)
			end
		end
	end

end)

-- Event triggered when a player completes a game pass purchase
marketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, Id, success)
	if success and Id == GamePassId then -- If the purchase was successful and matches our Game Pass ID
		local stats = player.leaderstats -- Get player's leaderboard stats
		local coins = stats:FindFirstChild("Coins") -- Get the "Coins" stat
		local exp = stats:FindFirstChild("EXP") -- Get the "EXP" stat

		coins.Value += 100 -- Reward 100 coins
		exp.Value += 500 -- Reward 500 EXP

		-- Create a receipt table to log this purchase
		local reciept = {
			Name = "VIP", -- Name of the game pass
			ID = Id, -- ID of the game pass
			Date = os.date("%x"), -- Date of the purchase
			Price = 100 -- Price of the game pass
		}

		-- Safely fetch existing purchase history
		local success, data = pcall(function()
			return PurchaseHistory:GetAsync(player.UserId)
		end)
		if not success then
			error("Failed to fetch history")
			return
		end
		
		-- Initialize data table if player has no previous purchases
		if data == nil then
			data = {}
		end
		
		-- Add the new receipt to the history
		table.insert(data, reciept)
		
		-- Save the updated history back to the DataStore
		local success, errormsg = pcall(function()
			PurchaseHistory:SetAsync(player.UserId, data)
		end)
		
		-- warn if saving fails
		if not success then
			error(errormsg)
		end

	end
end)

--[[
    Developer Products Handler:
    Description: This script handles in-game purchases (Developer Products) such as Coins and Speed boosts.
                 It uses MarketplaceService's ProcessReceipt callback to grant rewards reliably and securely.
]]

-- Set the Developer Product IDs for your game
local CoinsProduct = 3419943792 -- Product that gives 100 coins
local SpeedProduct = 3419943791 -- Product that gives a temporary speed boost

-- Table mapping ProductIds to functions that execute when purchased
local product = {}

-- Function for SpeedProduct
product[SpeedProduct] = function(player)
	-- Get the player's character object to get humanoid to increase speed
	if player then 
		local Char = player.Character
		if Char then
			-- Find the Humanoid in the character
			local humanoid = Char:FindFirstChild("Humanoid")
			-- If Humanoid exists, set WalkSpeed to 50 for 15 seconds
			if humanoid then
				-- Temporarily increase WalkSpeed to 50
				humanoid.WalkSpeed = 50 

				-- After 15 seconds, reset the WalkSpeed back to default (16)
				task.delay(15, function() 
					humanoid.WalkSpeed = 16
				end)
			end
		end
	end
	return true -- Return true to indicate the product was successfully granted
end

-- Function for CoinsProduct
product[CoinsProduct] = function(player)
	-- Get the player's leaderstats to find the Coins IntValue
	local leaderstats = player:FindFirstChild("leaderstats")
	-- If leaderstats exists, find the Coins IntValue
	if leaderstats then 
		local coins = leaderstats:FindFirstChild("Coins")
		-- Checking if Coins exists
		if coins then 
			-- Add 100 coins to the player's Coins IntValue
			coins.Value += 100 
		end
	end
	return true -- Return true to indicate the product was successfully granted
end

-- Callback function that Roblox calls whenever a Developer Product purchase occurs
marketPlaceService.ProcessReceipt = function(receiptInfo)
	
	local playerId = receiptInfo.PlayerId  -- Get the UserId of the player who purchased
	local ProductId = receiptInfo.ProductId -- Get the ProductId of the purchased product

	-- Get the player object from the UserId
	local player = game.Players:GetPlayerByUserId(playerId)

	-- Check if we have a function for this product
	if product[ProductId] then
		-- Call the product function to grant the reward
		local result = product[ProductId](player)

		if result then
			-- If reward granted successfully, tell Roblox the purchase was granted
			return Enum.ProductPurchaseDecision.PurchaseGranted
		else
			-- If something went wrong, tell Roblox to try processing again later
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	-- If the product ID is not recognized, do not process it yet
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
