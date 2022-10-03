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
function Module:RecalculateMagicDataCost(PlayerProfileData, MagicData)
	local NewMagicCost = 0
	for _, elementUUID in ipairs(MagicData.Elements) do
		local elementData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, elementUUID)
		local elementConfig = elementData and MagicDataConfigModule.Elements[elementData.Type]
		if elementConfig then
			NewMagicCost += (elementConfig.Cost or 1)
		end
	end
	for _, operationUUID in ipairs( MagicData.Operations ) do
		local operationData = GetDataFromArrayByUUID(PlayerProfileData.MagicItemsInventory, operationUUID)
		local operationConfig = operationData and MagicDataConfigModule.OperationsData[operationData.Type]
		if operationConfig then
			NewMagicCost += (operationConfig.Cost or 1)
		end
	end
	MagicData.MaxMagicDataCost = NewMagicCost
end

-- Update the base magic so its under the rune cost
function Module:IsOverBaseRuneCost(PlayerProfileData, magicData)
	Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	local baseRuneData = magicData.BaseRune and GetDataFromArrayByUUID(PlayerProfileData.MagicSpellsInventory, magicData.BaseRune)
	magicData.MaxMagicDataCost = baseRuneData and baseRuneData.MaxMagicDataCost or -1
	return magicData.CurrentMagicDataCost <= magicData.MaxMagicDataCost
end

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
function Module:SwapMagicDataOperationOrder(PlayerProfileData, magicData, index1, index2)

end

-- Remove a magic operation out of the magic spell
-- If the next operations are unsupported for the new earlier step,
-- unequip those automatically with a warning message
function Module:RemoveMagicDataOperation(PlayerProfileData, magicData, operationUUID)
	
end

-- Add a magic operation to the magic spell at the index (otherwise at the end)
function Module:AddMagicDataOperation(PlayerProfileData, magicData, operationUUID, index)
	--[[
		if index then
			-- add after a specific spot in the operations if valid
		else
			-- add to the end of the operations if valid
		end
	]]
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

-- clears all empty base magic spells
function Module:ClearAllEmptyBaseMagics(PlayerProfileData)
	local index = 1
	while index < #PlayerProfileData.MagicSpellsInventory do
		local magicData = PlayerProfileData.MagicSpellsInventory[index]
		if magicData.BaseRune == false and #magicData.Elements == 0 and #magicData.Operations == 0 then
			table.remove( PlayerProfileData.MagicSpellsInventory, index)
		else
			index += 1
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
