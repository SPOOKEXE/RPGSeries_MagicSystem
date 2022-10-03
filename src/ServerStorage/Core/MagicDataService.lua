local HttpService = game:GetService('HttpService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local RemoteService = ReplicatedModules.Services.RemoteService
local MagicDataEditFunction = RemoteService:GetRemote('MagicDataEdit', 'RemoteFunction', false)

local MagicDataConfigModule = ReplicatedModules.Data.MagicDataConfig
local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig

local TableUtility = ReplicatedModules.Utility.Table

local SystemsContainer = {}

local function GetDataFromArrayByUUID(ParentArray, UUIDValue)
	local UUID_MAP = InventoryDataConfigModule:GetUUIDDictionaryFromData(ParentArray)
	return UUID_MAP[UUIDValue]
end

-- // Module // --
local Module = {}

-- This rune allows the player to create magic (its an item)
function Module:NewMagicBaseRuneItem(magicRuneType)
	assert( magicRuneType and MagicDataConfigModule.BaseRuneTypes[magicRuneType], 'Passed MagicRuneType is not a valid magic rune type!' )
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'MagicRune',
		ParentMagic = false, -- points to parent magic uuid
		Type = magicRuneType -- projectile, close-aoe, single-attack, self
	}
end

-- Element runes will change what elements the magic uses
-- If more than 1 element is used, the damage is divided evenly to each element
-- 1 attrib = 100%, 2 attrib = 50%/attrib, 3 attrib = 33%/attrib of total damage.
function Module:NewBaseElementRuneData(element)
	assert(element and MagicDataConfigModule.Elements[element], 'Passed element is not a valid element!')
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'ElementRune',
		ParentMagic = false, -- points to parent magic uuid
		Type = element,
	}
end

-- Check if the operation dictionary matches the given
local UNKNOWN_INDEX_ERR_STR = "Data index does not match - got index %s of ValueType %s"
local DATA_MISMATCH_ERR_STR = "DataType mismatch - %s - (%s) expected (%s)"
function Module:DoesOperationParamsMatch(inputParams, baseParams)
	for propName, propValue in pairs(inputParams) do
		if not baseParams[propName] then
			return false, string.format(UNKNOWN_INDEX_ERR_STR, propName, typeof(propValue))
		end
		if typeof( baseParams[propName] ) ~= typeof(propValue) then
			return false, string.format(DATA_MISMATCH_ERR_STR, propName, typeof(propValue), typeof( baseParams[propName] ))
		end
	end
	return true
end

-- This holds the data for any magic spell operation data
-- (operation runes control how the spell work)
function Module:NewBaseOperationRuneData(operationID, operationParams)
	operationParams = operationParams or {} -- in the event that nothing is passed
	local baseParams = operationID and MagicDataConfigModule.OperationsData[operationID]
	assert(baseParams, 'Passed OperationID is not a valid magic operation!')
	local doesMatch, err = Module:DoesOperationParamsMatch(operationParams, baseParams)
	assert(doesMatch, err)
	baseParams = TableUtility:DeepCopy(baseParams)
	TableUtility:SetProperties(baseParams, operationParams)
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'OperationRune',
		Type = operationID, -- points to an ID under MagicDataConfig.OperationsData
		ParentMagic = false, -- points to parent magic uuid
		Parameters = baseParams,
	}
end

-- This holds the data for any magic spell
-- note: players cannot create new magic spells without a Magic Rune.
function Module:NewBaseMagicData()
	return {
		UUID = HttpService:GenerateGUID(false),

		MaxMagicDataCost = 5, -- maximum artifact cost this spell can hold (from Base Rune)
		CurrentMagicDataCost = 0, -- each artifact has a cost to it (compiled cost)

		BaseRune = false, -- uuid pointing to the magic rune data
		Elements = table.create(MagicDataConfigModule.MaxElementsPerSpell, false), -- element rune UUIDs
		Operations = {}, -- array of UUIDs pointing to ArtifactDatas (+ indicates order)
	}
end

-- ==================================================== --
-- ==================================================== --
-- ==================================================== --

-- Reconcile Magic Data
function Module:ReconcileMagicData(PlayerProfileData, MagicData)
	while #MagicData.Elements > MagicDataConfigModule.MaxElementsPerSpell do
		table.remove(MagicData.Elements, #MagicData.Elements)
	end
	Module:ClearAllEmptyBaseMagics(PlayerProfileData)
	Module:RecalculateMagicDataCost(PlayerProfileData, MagicData)
end

-- Recalculate magic cost
function Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	local NewMagicCost = 0
	for _, elementUUID in ipairs(magicData.Elements) do
		local elementData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, elementUUID)
		local elementConfig = elementData and MagicDataConfigModule.Elements[elementData.Type]
		if elementConfig then
			NewMagicCost += (elementConfig.Cost or 1)
		end
	end
	for _, operationUUID in ipairs( magicData.Operations ) do
		local operationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operationUUID)
		local operationConfig = operationData and MagicDataConfigModule.OperationsData[operationData.Type]
		if operationConfig then
			NewMagicCost += (operationConfig.Cost or 1)
		end
	end
	magicData.MaxMagicDataCost = NewMagicCost

	local baseRuneData = magicData.BaseRune and GetDataFromArrayByUUID(PlayerProfileData.MagicSpellsInventory, magicData.BaseRune)
	magicData.MaxMagicDataCost = baseRuneData and baseRuneData.MaxMagicDataCost or -1
end

-- Update the base magic so its under the rune cost
function Module:IsOverBaseRuneCost(PlayerProfileData, magicData)
	Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	return magicData.CurrentMagicDataCost <= magicData.MaxMagicDataCost
end

-- Can this operation be placed at this point in the operations array of a magic ability
function Module:CanOperationBePlacedAtIndex(magicData, operationData, index)
	warn('CanOperationBePlacedAtIndex not 100% implemented')
	-- return false, 'For this reason!'
	return true
end

-- ==================================================== --
-- ==================================================== --
-- ==================================================== --

-- Set the base magic rune uuid
function Module:SetMagicBaseRuneUUID(PlayerProfileData, magicData, baseRuneUUID)
	local runeData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, baseRuneUUID)
	if not runeData then
		return false, 'Base Rune with UUID could not be found: '..tostring(baseRuneUUID)
	end
	magicData.BaseRune = baseRuneUUID
	runeData.ParentMagic = magicData.UUID
	Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	return true
end

-- Set the element rune uuid
-- if index is not nil, set the rune uuid to that spot
-- also check if the rune uuid is already in the uuid array are remove it if so
function Module:SetMagicElementRuneUUID(PlayerProfileData, magicData, elementRuneUUID, index)
	local elementData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, elementRuneUUID)
	if not elementData then
		return false, 'Element Rune with UUID could not be found: '..tostring(elementRuneUUID)
	end

	-- remove it from the data if it already exists
	local existent_index = table.find(magicData.Elements, elementRuneUUID)
	if existent_index then
		magicData.Elements[existent_index] = false
	end

	-- swap spots with this one if the selected rune was in a different spot
	if index and existent_index then
		magicData.Elements[existent_index] = magicData.Elements[index]
	end

	-- replace over the chosen spot
	magicData.Elements[index] = elementRuneUUID

	return true
end

-- Swap the two operation order indexes if allowed, otherwise disallow
-- most of the notes from AddMagicDataOperation apply here
function Module:SwapMagicDataOperationOrder(PlayerProfileData, magicData, index1, index2)
	index1 = math.clamp(index1, 1, #magicData.Operations)
	index2 = math.clamp(index2, 1, #magicData.Operations)

	local operation1UUID = magicData.Operations[index1]
	local operationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operation1UUID)
	if not operationData then
		return false, 'No Operation Data found at index1!'
	end

	local canBePlaced, reason = Module:CanOperationBePlacedAtIndex(magicData, operationData, index2)
	if not canBePlaced then
		return false, reason
	end

	local operation2UUID = magicData.Operations[index2]
	local otherOperationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operation2UUID)
	if otherOperationData then
		canBePlaced, reason = Module:CanOperationBePlacedAtIndex(magicData, otherOperationData, index1)
		if not canBePlaced then
			return false, reason
		end
	end

	magicData.Operations[index2] = operation1UUID
	if operation2UUID then
		magicData.Operations[index1] = operation2UUID
	end

	return true
end

-- Remove a magic operation out of the magic spell
-- If the next operations are unsupported for the new earlier step,
-- unequip those automatically with a warning message
function Module:RemoveMagicDataOperation(PlayerProfileData, magicData, operationUUID)
	local operationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operationUUID)
	if not operationData then
		return false, 'No matching Operation Data found in inventory!'
	end

	local existing_index = table.find(magicData.Operations, operationUUID)
	if not existing_index then
		return true
	end

	table.remove(magicData.Operations, existing_index)

	local newDataPlacement = magicData.Operations[existing_index]
	if not newDataPlacement then
		return true
	end

	local canBe, _ = Module:CanOperationBePlacedAtIndex(magicData, newDataPlacement, existing_index)
	if not canBe then
		-- if the operation that was shifted left cannot fit there
		-- remove everything after the index point.
		while #magicData.Operations > existing_index do
			table.remove(magicData.Operations, #magicData.Operations)
		end
	end

	return true
end

-- Add a magic operation to the magic spell at the index (otherwise at the end)
-- if it cannot be there, nothing happens.
-- if the operation is already being used, it will swap places with the selected index
-- if any operations after the selected index cannot be there, it will remove everything
-- from that point afterwards
function Module:AddMagicDataOperation(PlayerProfileData, magicData, operationUUID, index)
	local operationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operationUUID)
	if not operationData then
		return false, 'No matching Operation Data found in inventory!'
	end

	index = index or (#magicData.Operations + 1)

	local existingIndex = table.find(magicData.Operations, operationUUID)
	if existingIndex then
		-- try swap them
		Module:SwapMagicDataOperationOrder(PlayerProfileData, magicData, existingIndex, index)
	else
		-- add it at the index / end
		local canBePlaced, reason = Module:CanOperationBePlacedAtIndex(magicData, operationData, index)
		if not canBePlaced then
			return false, reason
		end

		table.insert(magicData.Operations, index, operationUUID)
	end
end

function Module:GivePlayerMagicBaseRune(PlayerProfileData, runeTypeID, overrideProperties)
	local magicRuneItem = Module:NewMagicBaseRuneItem(runeTypeID)
	TableUtility:SetProperties(magicRuneItem, overrideProperties)
	table.insert(PlayerProfileData.MagicItemsInventory, magicRuneItem)
	return magicRuneItem
end

function Module:GivePlayerElementRune(PlayerProfileData, elementID, overrideProperties)
	local emptyArtifactData = Module:NewBaseElementRuneData(elementID)
	TableUtility:SetProperties(emptyArtifactData, overrideProperties)
	table.insert(PlayerProfileData.MagicItemsInventory, emptyArtifactData)
	return emptyArtifactData
end

function Module:GivePlayerMagicOperationRune(PlayerProfileData, operationID, operationData, overrideProperties)
	local emptyOperationRune = Module:NewBaseOperationRuneData(operationID, operationData)
	TableUtility:SetProperties(emptyOperationRune, overrideProperties)
	table.insert(PlayerProfileData.MagicItemsInventory, emptyOperationRune)
	return emptyOperationRune
end

-- allow this spell to be created even if all slots aren't filled
-- but don't allow the player to actually use the magic unless it has the bare minimum
function Module:CreateBaseMagicSpell(PlayerProfileData, magicRuneUUID, elementRuneUUIDs, operationUUIDs)
	if #PlayerProfileData.MagicSpellsInventory + 1 > MagicDataConfigModule.MaximumSpellsInInventory then
		return false, 'You have reached the maximum capacity of magic spells.'
	end

	local emptySpellData = Module:NewBaseMagicData()
	Module:SetMagicBaseRuneUUID(PlayerProfileData, emptySpellData, magicRuneUUID)
	for _, UUID in ipairs( elementRuneUUIDs or {} ) do
		Module:SetMagicElementRuneUUID(PlayerProfileData, emptySpellData, UUID)
	end
	for _, Operation in ipairs( operationUUIDs or {} ) do
		Module:SetMagicBaseRuneUUID(PlayerProfileData, emptySpellData, Operation)
	end
	table.insert(PlayerProfileData.MagicSpellsInventory, emptySpellData)
	return emptySpellData
end

-- Equip magic spells
function Module:EquipPlayerMagicAbility(LocalPlayer, magicData, index)
	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer, true)

	if index < 1 or index > MagicDataConfigModule.MaxEquippedMagics then
		local errStr = 'Invalid Equip Slot Range. "1 > %s > %s" holds untrue.'
		return false, string.format(errStr, index, MagicDataConfigModule.MaxEquippedMagics)
	end

	-- if it is equipped already, unequip it
	local currentSlot = table.find(PlayerProfileData.EquippedMagic, magicData.UUID)
	if currentSlot then
		-- already in the slot, end early
		if currentSlot == index then
			return true
		end
		PlayerProfileData.EquippedMagic[currentSlot] = false
	end

	-- equip it in the new slot
	PlayerProfileData.EquippedMagic[index] = magicData.UUID

	SystemsContainer.MagicAbilityService:UpdateEquipped(LocalPlayer)

	return true
end

-- clears all empty base magic spells
function Module:ClearAllEmptyBaseMagics(PlayerProfileData)
	-- clear from magic inventory
	local _index = 1
	while _index <= #PlayerProfileData.MagicSpellsInventory do
		local magicData = PlayerProfileData.MagicSpellsInventory[_index]
		if magicData.BaseRune == false and #magicData.Elements == 0 and #magicData.Operations == 0 then
			table.remove( PlayerProfileData.MagicSpellsInventory, _index)
		else
			_index += 1
		end
	end

	-- clear equipped uuids that no longer have data in the magic inventory
	local UUIDCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicSpellsInventory)
	for index, equippedUUID in ipairs( PlayerProfileData.EquippedMagic ) do
		if not UUIDCache[equippedUUID] then
			PlayerProfileData.EquippedMagic[index] = false
		end
	end
end

-- Handle any remote invokations
function Module:HandleDataEditRemote(LocalPlayer, Data)
	warn(LocalPlayer, Data)
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	MagicDataEditFunction.OnServerInvoke = function(LocalPlayer, Data)
		if typeof(Data) == 'table' then
			return Module:HandleDataEditRemote(LocalPlayer, Data)
		end
		return nil, 'Invalid argument provided.'
	end
end

return Module
