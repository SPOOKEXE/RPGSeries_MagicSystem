-- The point of this module is to give the player magic data
-- and to test the system by accessing the module methods directly.
-- (as if they were doing it through the remote)

local Players = game:GetService('Players')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicDataConfigModule = ReplicatedModules.Data.MagicDataConfig
local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:GivePlayerHeapsOfVariety(LocalPlayer, amountToGive)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	amountToGive = amountToGive or 10
	warn('Giving ', LocalPlayer.Name, ' heaps of runes.')

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


function Module:StartTest(LocalPlayer)
	local MagicDataService = SystemsContainer.MagicDataService
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true).Data

	warn('Starting Data Edit Tests for ', LocalPlayer)
	-- warn('DATA_1 | ', PlayerProfileData)

	-- GIVE THE PLAYER A HEAP OF RUNES
	Module:GivePlayerHeapsOfVariety(LocalPlayer, 5) -- give 'n' number of each type of every type of rune
	warn('DATA_2 | ', PlayerProfileData)

	-- CREATE NEW MAGIC SPELL
	local BaseMagicSpell = MagicDataService:CreateBaseMagicSpell(PlayerProfileData, false, false, false)
	-- warn('DATA_3 | ', PlayerProfileData)

	-- SET THE MAGIC BASE RUNE
	local baseMagicRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('MagicRune', PlayerProfileData.MagicItemsInventory, 3)
	warn('MAGIC RUNES; ', #baseMagicRunes, baseMagicRunes)
	warn('MAGIC_DATA_0 | ', BaseMagicSpell)
	MagicDataService:SetMagicBaseRuneUUID(PlayerProfileData, BaseMagicSpell, baseMagicRunes[1].UUID)
	warn('MAGIC_DATA_1 | ', BaseMagicSpell)

	-- SET THE MAGIC ELEMENTS
	local elementRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('ElementRune', PlayerProfileData.MagicItemsInventory, 3)
	warn('ELEMENT RUNES; ', #elementRunes, elementRunes)
	for index, elementRune in ipairs( elementRunes ) do
		if index > MagicDataConfigModule.MaxElementsPerSpell then
			break
		end
		MagicDataService:SetMagicElementRuneUUID(PlayerProfileData, BaseMagicSpell, elementRune.UUID, index)
	end
	warn('MAGIC_DATA_2 | ', BaseMagicSpell)

	-- SET THE MAGIC OPERATION ORDER
	local operationRunes = InventoryDataConfigModule:GetCountedIDArrayFromData('OperationRune', PlayerProfileData.MagicItemsInventory, 8)
	warn('OPERATION RUNES; ', #operationRunes, operationRunes)
	for _, operationRune in ipairs( operationRunes ) do
		MagicDataService:AddMagicDataOperation(PlayerProfileData, BaseMagicSpell, operationRune.UUID, false)
	end
	warn('MAGIC_DATA_3 | ', PlayerProfileData)

	MagicDataService:RecalculateMagicDataCost(PlayerProfileData, BaseMagicSpell)

	warn('FINAL_MAGIC_DATA | ', BaseMagicSpell)
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	-- lmao
	SystemsContainer.FakeDataService:PlayerAdded(workspace)
	Module:StartTest(workspace)

	--[[for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		task.defer(function()
			Module:StartTest(LocalPlayer)
		end)
	end

	Players.PlayerAdded:Connect(function(LocalPlayer)
		Module:StartTest(LocalPlayer)
	end)]]
end

return Module

