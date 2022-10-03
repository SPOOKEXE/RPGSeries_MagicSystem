local HttpService = game:GetService('HttpService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local RemoteService = ReplicatedModules.Services.RemoteService
local MagicDataEditFunction = RemoteService:GetRemote('MagicDataEdit', 'RemoteFunction', false)

local MagicDataConfigModule = ReplicatedModules.Data.MagicDataConfig
local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig

local TableUtility = ReplicatedModules.Utility.Table

local SystemsContainer = {}

-- // Module // --
local Module = {}

-- This rune allows the player to create magic (its an item)
function Module:NewMagicBaseRuneItem(magicRuneType)
	assert( magicRuneType and MagicDataConfigModule.BaseRuneTypes[magicRuneType], 'Passed MagicRuneType is not a valid magic rune type!' )
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'MagicRune',
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
		Attribute = element,
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
	local baseParams = operationID and MagicDataConfigModule.OperationsData[operationID]
	assert(baseParams, 'Passed OperationID is not a valid magic operation!')
	local doesMatch, err = Module:DoesOperationParamsMatch(operationParams, baseParams)
	assert(doesMatch, err)
	baseParams = TableUtility:DeepCopy(baseParams)
	TableUtility:SetProperties(baseParams, operationParams)
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'OperationRune',

		ParentMagic = false, -- UUID pointing to the MagicData using this rune

		Operation = {
			ID = operationID, -- points to an ID under MagicDataConfig.OperationsData
			Parameters = baseParams,
		},
	}
end

-- This holds the data for any magic spell
-- note: players cannot create new magic spells without a Magic Rune.
function Module:NewBaseMagicData(baseMagicProperties)
	return {
		UUID = HttpService:GenerateGUID(false),

		MaxArtifactsCost = 0, -- maximum artifact cost this spell can hold
		CurrentArtifactsCost = 0, -- each artifact has a cost to it

		BaseRune = false, -- uuid pointing to the magic rune data
		Elements = {}, -- element rune UUIDs
		Operations = {}, -- array of UUIDs pointing to ArtifactDatas (+ indicates order)
	}
end

-- Set the element rune uuid
-- if index is not nil, set the rune uuid to that spot
-- also check if the rune uuid is already in the uuid array are remove it if so
function Module:SetElementRuneUUID(LocalPlayer, MagicUUID, elementRuneUUID, index)

end

-- Swap the two operation order indexes if allowed, otherwise disallow
function Module:SwapMagicDataOperationOrder(LocalPlayer, MagicUUID, index1, index2)

end

-- Remove a magic operation out of the magic spell
-- If the next operations are unsupported for the new earlier step,
-- unequip those automatically with a warning message
function Module:RemoveMagicDataOperation(LocalPlayer, MagicID, artifactUUID)
	
end

-- Add a magic operation to the magic spell at the index (otherwise at the end)
function Module:AddMagicDataOperation(LocalPlayer, MagicID, index)
	--[[
		if index then
			-- add after a specific spot in the operations if valid
		else
			-- add to the end of the operations if valid
		end
	]]
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
