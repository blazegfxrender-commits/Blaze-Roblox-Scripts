local MarketPlaceService = game:GetService("MarketplaceService")
local ProductID = 3365103720
local players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local function ProductPurchase(RecieptInfo)
	local player = players:GetPlayerByUserId(RecieptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	
	if player then
		local char = game.Workspace:FindFirstChild(player.Name)
		local sword = ReplicatedStorage:WaitForChild("sword")
		local clonnedsword = sword:Clone()
		clonnedsword.Name = "Sword"
		clonnedsword.Parent = char
	end
end

MarketPlaceService.ProcessReceipt = ProductPurchase
