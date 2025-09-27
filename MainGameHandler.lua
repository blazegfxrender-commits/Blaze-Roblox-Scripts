local marketPlaceService = game:GetService("MarketplaceService")
local gamePassID = 1492153600 --ID of the gamepass
local productID1 = 3415867818 --ID of the product
local player = game:GetService("Players")

local dataStoreService = game:GetService("DataStoreService")
local playerCoins = dataStoreService:GetDataStore("PlayerCoins")
local playerEXP = dataStoreService:GetDataStore("PlayerEXP")
--to track the gamepass purchase history
local PurchaseHistory = dataStoreService:GetDataStore("PurchaseHistory")
--to track the product purchase history
local productPurchaseHistory = dataStoreService:GetDataStore("ProductHistory")

local increasePart = game.Workspace.IncreasePart
local decreasePart = game.Workspace.DecreasePart
--to connect server and client
local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent") 

--when a player joins to game, a leaderstats folder will be created
game.Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local coins = Instance.new("IntValue", leaderstats)
	coins.Name = "Coins"
	coins.Value = 0
	
	local exp = Instance.new("IntValue", leaderstats)
	exp.Name = "EXP"
	exp.Value = 0
	
	increasePart.ClickDetector.MouseClick:Connect(function(player) --player's coins will be increased by 50 when clicked on part
		coins.Value += 50
	end)
	
	decreasePart.ClickDetector.MouseClick:Connect(function(player) -- player's coins will be decreased by 50 when clicked on part
		coins.Value -= 50
	end)
	
	local success, currentCoins = pcall(function() --save player's coins to datastore 
		return playerCoins:GetAsync(player.UserId)
	end)
	if success then
		coins.Value = currentCoins
	else
		coins.Value = coins.Value
	end
	
	
	local haspass = false
	local success, errorMsg = pcall(function()
		haspass = marketPlaceService:UserOwnsGamePassAsync(player.UserId, gamePassID) --check if player has gamepass
	end)

	if not success then
		error(errorMsg)
		return
	end

	if haspass then
		--Give the player gamepass and its features--
		local Gun = game:GetService("ReplicatedStorage"):WaitForChild("Gun")
		if Gun then
			local GunClone = Gun:Clone()
			GunClone.Parent = player.Backpack
			
			if not player.StarterGear:FindFirstChild(Gun.Name) then
				local GunClone = Gun:Clone()
				GunClone.Parent = player.StarterGear --gives player the gun when they join the game
			end
		end
		
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
		coins.Value += 100
		
		local playerexp = player:WaitForChild("leaderstats"):WaitForChild("EXP")
		playerexp.Value += 500
	end

	--this is a code to print gamepass purchase history
	local data = PurchaseHistory:GetAsync(player.UserId)
	if data then
		for i,reciept in ipairs(data) do
			for key,value in pairs(reciept) do
				print(reciept)
			end
		end
	end
	
end)

marketPlaceService.PromptGamePassPurchaseFinished:Connect(function(player, Id, success)
	if success and Id == gamePassID then
		local Gun = game:GetService("ReplicatedStorage"):WaitForChild("Gun")
		if Gun then
			local GunClone = Gun:Clone()
			GunClone.Parent = player.Backpack

			if not player.StarterGear:FindFirstChild(Gun.Name) then
				local GunClone = Gun:Clone()
				GunClone.Parent = player.StarterGear --gives player the gun when they buy the pass
			end
		end
		
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
		coins.Value += 100 --increase player's coins by 100 when they buy the gamepass
		
		local playerexp = player:WaitForChild("leaderstats"):WaitForChild("EXP")
		playerexp.Value += 500 --increase player's exp by 500 when they buy the gamepass
		

		--reciept
		local reciept = {
			Name = "VIP PASS", --name of pass
			ID = Id, --id of pass
			Date = os.date("%x"), --date of purchase
			Price = "100 ROBUX" -- price of pass
		}

		--purchase history
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

local players = game:GetService("Players")
--to track the purchase history
local productPurchaseHistory = dataStoreService:GetDataStore("ProductHistory")

local productFunctions = {}
--function that gives player 200 coins when player buys product
productFunctions[productID1] = function(reciept, player)
	local player = players:GetPlayerByUserId(reciept.PlayerId)
	if player then
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
		coins.Value += 200
	end
end
--handling purchase
local function processReciept(recieptInfo)
	local userId = recieptInfo.PlayerId
	local productId = recieptInfo.ProductId

	local purchased = false
	local playerProductKey = userId .. "_" .. recieptInfo.PurchaseId

	local success, errormsg = pcall(function()
		purchased = productPurchaseHistory:GetAsync(playerProductKey) --check if player already bought the product
	end)
	if success and purchased then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- player already bought the product
	elseif not success then
		error("Data store error:" .. errormsg)	
	end

	local success, isPurchaseRecorded = pcall(function()
		return productPurchaseHistory:UpdateAsync(playerProductKey, function(alreadyPurchased)
			if alreadyPurchased then
				return true
			end

			local player = players:GetPlayerByUserId(userId)
			if player then
				local handler1 = productFunctions[productID1]

				local success, result = pcall(handler1, recieptInfo, player)
				if not success or not result then
					print("purchase failed" .. "_" .. recieptInfo.ProductId) --if purchase failed 
				end
			end

			return true
		end)
	end)

	if not success then
		error("Data store error:" .. isPurchaseRecorded)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif isPurchaseRecorded == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	else
		return Enum.ProductPurchaseDecision.PurchaseGranted -- tracking purchase history

	end
end

marketPlaceService.ProcessReceipt = processReciept

remoteEvent.OnServerEvent:Connect(function(player, mousePosition) --when player fires the gun
	local tool = player.Character and player.Character:FindFirstChild("Gun")
	if not tool then return end

	local barrel = tool:FindFirstChild("Shot") --to get the starting point of the raycast
	if not barrel then return end

	local barrelPos = barrel.Position 

	local raycastparams = RaycastParams.new() 
	raycastparams.FilterDescendantsInstances = {player.Character}
	raycastparams.FilterType = Enum.RaycastFilterType.Exclude --to exclude certain parts to avoid the effect of the raycast

	local direction = (mousePosition - barrelPos).Unit * 100 --to get the direction of the raycast (direction of bullet)

	local rayCastResult = workspace:Raycast(barrelPos, direction, raycastparams) --creating the raycast

	if rayCastResult then
		local rayCastInstance = rayCastResult.Instance
		local model = rayCastInstance:FindFirstAncestorOfClass("Model")

		if model then
			if model:FindFirstChild("Humanoid") then --if the raycast hits a player
				if rayCastInstance.Name == "Head" then
					model:FindFirstChild("Humanoid"):TakeDamage(80) --if the player hits the head, they take 80 damage, otherwise 20 damage
				else
					model:FindFirstChild("Humanoid"):TakeDamage(20)
				end
			end
		end
	end
end)

--when player leaves the game:
game.Players.PlayerRemoving:Connect(function(player)
	local success, errormsg = pcall(function()
		local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
		local exp = player:WaitForChild("leaderstats"):WaitForChild("EXP")
		
		playerCoins:SetAsync(player.UserId, coins.Value) --save player's coins
		playerEXP:SetAsync(player.UserId, exp.Value) --save player's exp

	end)
end)
