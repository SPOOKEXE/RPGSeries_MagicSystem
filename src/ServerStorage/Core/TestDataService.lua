-- The point of this module is to give the player magic data
-- and to test the system by accessing the module methods directly.
-- (as if they were doing it through the remote)

local Players = game:GetService('Players')

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:StartTest(LocalPlayer)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfile = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true)

	warn('Starting Data Edit Tests for ', LocalPlayer)
	warn('DATA_1 | ', PlayerProfile)

	-- MagicDataService:SomeMethod()

end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		task.defer(function()
			Module:StartTest(LocalPlayer)
		end)
	end

	Players.PlayerAdded:Connect(function(LocalPlayer)
		Module:StartTest(LocalPlayer)
	end)

	Players.PlayerRemoving:Connect(function(LocalPlayer)
		Module:StartTest(LocalPlayer)
	end)
end

return Module

