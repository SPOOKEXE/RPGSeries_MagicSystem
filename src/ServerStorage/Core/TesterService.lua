-- The point of this module is to give the player magic data
-- and to test the system by accessing the module methods directly.
-- (as if they were doing it through the remote)

local Players = game:GetService('Players')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicDataConfigModule = ReplicatedModules.Data.MagicDataConfig
local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig
local MagicControllerConfigModule = ReplicatedModules.Data.MagicControllerConfig

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:GivePlayerHeapsOfVariety(LocalPlayer, amountToGive)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data
	amountToGive = amountToGive or 10

	for baseRuneType, _ in pairs(MagicDataConfigModule.BaseRuneTypes) do
		for _ = 1, amountToGive do
			MagicDataService:GivePlayerMagicBaseRune(PlayerProfileData, baseRuneType)
		end
	end

	for elementID, _ in pairs(MagicDataConfigModule.Elements) do
		for _ = 1, amountToGive do
			MagicDataService:GivePlayerElementRune(PlayerProfileData, elementID)
		end
	end

	for operationID, _ in pairs(MagicDataConfigModule.OperationsData) do
		for _ = 1, amountToGive do
			MagicDataService:GivePlayerMagicOperationRune(PlayerProfileData, operationID)
		end
	end
end

function Module:GivePlayerRandomMagic(LocalPlayer)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	warn('Giving', LocalPlayer.Name, 'a randomized magic ability.')
	local baseMagicRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('MagicRune', PlayerProfileData.MagicItemsInventory, false)
	local elementRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('ElementRune', PlayerProfileData.MagicItemsInventory, false)
	local operationRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('OperationRune', PlayerProfileData.MagicItemsInventory, false)

	local RNG = Random.new()
	local BaseMagicAbility = MagicDataService:CreateBaseMagicAbility(
		PlayerProfileData,
		baseMagicRunes[RNG:NextInteger(1, #baseMagicRunes)].UUID,
		elementRunes[RNG:NextInteger(1, #elementRunes)].UUID,
		operationRunes[RNG:NextInteger(1, #operationRunes)].UUID
	)

	warn('FINAL_RANDOM_MAGIC_DATA | ', BaseMagicAbility)
	return BaseMagicAbility
end

function Module:StartTest(LocalPlayer)
	local MagicDataService = SystemsContainer.MagicDataService
	-- local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	warn('Starting Data Edit Tests for ', LocalPlayer)

	Module:GivePlayerHeapsOfVariety(LocalPlayer, 10) -- give 'n' number of each type of every type of rune
	local RandomMagicsArray = {} do
		for _ = 1, MagicControllerConfigModule.MAX_EQUIPPED_MAGICS do
			table.insert(RandomMagicsArray, Module:GivePlayerRandomMagic(LocalPlayer))
		end
	end

	for index, magicData in ipairs(RandomMagicsArray) do
		if index > MagicControllerConfigModule.MAX_EQUIPPED_MAGICS then
			break
		end
		MagicDataService:EquipPlayerMagicAbility(LocalPlayer, magicData.UUID, index)
	end
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	-- lmao
	--[[
	SystemsContainer.FakeDataService:PlayerAdded(workspace)
	Module:StartTest(workspace)
	]]

	--[[]]
	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		task.defer(function()
			Module:StartTest(LocalPlayer)
		end)
	end

	Players.PlayerAdded:Connect(function(LocalPlayer)
		Module:StartTest(LocalPlayer)
	end)
end

return Module
