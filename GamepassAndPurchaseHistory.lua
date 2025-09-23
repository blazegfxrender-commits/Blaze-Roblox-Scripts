local marketplace = game:GetService("MarketplaceService")
local gamepassID = 1390127265 --CHANGE THE ID

local DataStore = game:GetService("DataStoreService")
local PurchaseHistory = DataStore:GetDataStore("PurchaseHistory")


game.Players.PlayerAdded:Connect(function(player)
	local haspass = false
	local success, errorMsg = pcall(function()
		haspass = marketplace:UserOwnsGamePassAsync(player.UserId, gamepassID)
	end)
	
	if not success then
		error(errorMsg)
		return
	end
	
	if haspass then
		print(player.Name .." has a gamepass")
	    --Give the player gamepass and its features--
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

marketplace.PromptGamePassPurchaseFinished:Connect(function(player, Id, success)
	if success and Id == gamepassID then
		print(player.Name .. " has bought a gamepass")
		--give the player gamepass and its features--
	end
	
	--reciept
	local reciept = {
		Name = " --name of the gamepass-- ", 
		ID = Id,
		Date = os.date("%x"),
		Price = "--price of the gamepass--"
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
end)
