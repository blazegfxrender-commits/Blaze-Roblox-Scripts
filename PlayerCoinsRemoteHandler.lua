local button1 = game.Workspace.Touchpart
local button2 = game.Workspace.SpendPart

local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent")
local remoteEvent2 = game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvent2")

remoteEvent.OnServerEvent:Connect(function(player, part)
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins")
	coins.Value = coins.Value + 5
end)

remoteEvent2.OnServerEvent:Connect(function(player, part)
	local leaderstats = player:WaitForChild("leaderstats")
	local coins = leaderstats:WaitForChild("Coins")
	coins.Value = coins.Value - 5
end)

