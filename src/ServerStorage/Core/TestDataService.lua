-- The point of this module is to give the player magic data
-- and to test the system by accessing the module methods directly.
-- (as if they were doing it through the remote)

local Players = game:GetService('Players')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicDataConfigModule = ReplicatedModules.Data.MagicDataConfig
local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig

local TableUtility = ReplicatedModules.Utility.Table

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:GivePlayerMagicBaseRune(LocalPlayer, runeTypeID, magicRuneProperties)
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	local magicRuneItem = SystemsContainer.MagicDataService:NewMagicBaseRuneItem(runeTypeID)
	TableUtility:SetProperties(magicRuneItem, magicRuneProperties)
	table.insert(PlayerProfileData.MagicItemsInventory, magicRuneItem)
end

function Module:GivePlayerElementRune(LocalPlayer, elementID, elementRuneProperties)
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	local emptyArtifactData = SystemsContainer.MagicDataService:NewBaseElementRuneData(elementID)
	TableUtility:SetProperties(emptyArtifactData, elementRuneProperties)
	table.insert(PlayerProfileData.MagicItemsInventory, emptyArtifactData)
end

function Module:GivePlayerMagicOperationRune(LocalPlayer, operationRuneData)
	
end

function Module:StartTest(LocalPlayer)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	warn('Starting Data Edit Tests for ', LocalPlayer)
	-- warn('DATA_1 | ', PlayerProfileData)

	-- give one of each type of magic rune types
	local totalCustomMagicTypes = 0
	for baseRuneType, _ in pairs(MagicDataConfigModule.BaseRuneTypes) do
		Module:GivePlayerMagicBaseRune(LocalPlayer, baseRuneType)
		totalCustomMagicTypes += 1
	end

	-- warn('DATA_2 | ', PlayerProfileData)

	-- give 'totalCustomMagicTypes' runes of each element to the player
	for elementID, _ in pairs(MagicDataConfigModule.Elements) do
		for _ = 1, totalCustomMagicTypes do
			Module:GivePlayerElementRune(LocalPlayer, elementID, false)
		end
	end

	warn('DATA_3 | ', PlayerProfileData)

	--[[ MagicDataService:HandleDataEditRemote(LocalPlayer, { Job = '', }) ]]
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

