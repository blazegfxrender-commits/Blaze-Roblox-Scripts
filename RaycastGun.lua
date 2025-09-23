local remoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("FireGun")

remoteEvent.OnServerEvent:Connect(function(player, mousePosition)
	local tool = player.Character and player.Character:FindFirstChild("Gun")
	if not tool then return end

	local barrel = tool:FindFirstChild("Barrel")
	if not barrel then return end

	local barrelPos = barrel.Position

	local raycastparams = RaycastParams.new()
	raycastparams.FilterDescendantsInstances = {player.Character}
	raycastparams.FilterType = Enum.RaycastFilterType.Exclude

	local direction = (mousePosition - barrelPos).Unit * 100

	local rayCastResult = workspace:Raycast(barrelPos, direction, raycastparams)

	if rayCastResult then
		local rayCastInstance = rayCastResult.Instance
		local model = rayCastInstance:FindFirstAncestorOfClass("Model")

		if model then
			if model:FindFirstChild("Humanoid") then
				if rayCastInstance.Name == "Head" then
					model:FindFirstChild("Humanoid"):TakeDamage(80)
				else
					model:FindFirstChild("Humanoid"):TakeDamage(20)
				end
			end
		end
	end
end)
