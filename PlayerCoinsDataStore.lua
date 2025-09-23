local DataStoreServive = game:GetService("DataStoreService")
local playerCoins = DataStoreServive:GetDataStore("playercoins")

game.Players.PlayerAdded:Connect(function(player)
	
	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	
	local Coins = Instance.new("IntValue", leaderstats)
	Coins.Name = "Coins"
	Coins.Value = 100
	
	local success, currentCoins = pcall(function()
		return playerCoins:GetAsync(player.UserId)
	end)
	if success then
		Coins.Value = currentCoins
	else
		Coins.Value = 100
	end
	
	
end)

game.Players.PlayerRemoving:Connect(function(player)
	local success, errormsg = pcall(function()
		playerCoins:SetAsync(player.UserId, player.leaderstats.Coins.Value)
	end)
end)

