local Players = game:GetService('Players')

local SystemsContainer = {}

local FakeProfileCache = {}

-- // Module // --
local Module = {}

-- this is the template data of the player's profile (so add these to the actual game)
function Module:CreateFakeData()
	return {
		-- equipped magic UUIDs
		EquippedMagic = {},
		-- attribute runes are stored here.
		-- artifacts are stored here.
		-- attributes are applied to magic to change how they work
		MagicItemsInventory = {},
		-- all custom created magic with the artifact data are stored here
		MagicAbilityInventory = {},
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
	local BlankData = {Data = Module:CreateFakeData()}
	for _, MagicAbilityData in ipairs( BlankData.Data.MagicAbilityInventory ) do
		Module:ReconcileMagicData(BlankData, MagicAbilityData)
	end
	FakeProfileCache[LocalPlayer] = BlankData
end

function Module:PlayerRemoving(LocalPlayer)
	SystemsContainer.MagicDataService:ClearAllEmptyBaseMagics(LocalPlayer)
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
