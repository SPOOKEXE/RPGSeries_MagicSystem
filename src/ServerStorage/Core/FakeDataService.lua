local Players = game:GetService('Players')

local SystemsContainer = {}

local FakeProfileCache = {}

-- // Module // --
local Module = {}

-- this is the template data of the player's profile (so add these to the actual game)
function Module:CreateFakeData()
	return {
		-- equipped magic UUIDs
		EquippedMagic = { },
		-- all attribute runes are stored here
		MagicAttributeRunes = { },
		-- artifacts that can be applied to magic to change how they work are stored here
		MagicArtifactInventory = { },
		-- all custom created magic with the artifact data are stored here
		MagicDataInventory = { },
	}
end

function Module:GetProfileFromPlayer(LocalPlayer, Yield)
	local startTime = time()
	while Yield and (time() - startTime < 30) and (not FakeProfileCache[LocalPlayer]) do
		task.wait(0.1)
	end
	return FakeProfileCache[LocalPlayer]
end

function Module:PlayerAdded(LocalPlayer)
	FakeProfileCache[LocalPlayer] = {Data = Module:CreateFakeData()}
end

function Module:PlayerRemoving(LocalPlayer)
	FakeProfileCache[LocalPlayer] = nil
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		task.defer(function()
			Module:PlayerAdded(LocalPlayer)
		end)
	end

	Players.PlayerAdded:Connect(function(LocalPlayer)
		Module:PlayerAdded(LocalPlayer)
	end)

	Players.PlayerRemoving:Connect(function(LocalPlayer)
		Module:PlayerRemoving(LocalPlayer)
	end)
end

return Module
