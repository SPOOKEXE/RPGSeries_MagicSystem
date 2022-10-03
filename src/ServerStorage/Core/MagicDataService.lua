local HttpService = game:GetService('HttpService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local RemoteService = ReplicatedModules.Services.RemoteService
local MagicDataEditFunction = RemoteService:GetRemote('MagicDataEdit', 'RemoteFunction', false)

local SystemsContainer = {}

-- // Module // --
local Module = {}

-- This rune allows the player to create magic
function Module:GenerateBaseMagicRuneData()
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'MagicRune',
	}
end

-- Attribute runes will change what attributes the magic uses
-- If more than 1 attribute is used, the damage is divided evenly to each attribute
-- 1 attrib = 100%, 2 attrib = 50%/attrib, 3 attrib = 33%/attrib of total damage.
function Module:GenerateBaseAttributeRuneData()
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'AttributeRune',
		Attribute = false, -- unknown attribute
	}
end

-- This holds the data for any magic spell artifact data
-- (artifacts control how the spell work)
function Module:GenerateBaseArtifactData()
	return {
		UUID = HttpService:GenerateGUID(false),
		ID = 'NULL',

		ParentMagic = false, -- UUID pointing to the MagicData using this artifact

		Operation = {
			ID = 'NULL',
			Parameters = {
				KEY = 'NULL',
			},
		},
	}
end

-- This holds the data for any magic spell
-- note: players cannot create new magic spells without a Magic Rune.
function Module:GenerateBaseMagicData()
	return {
		UUID = HttpService:GenerateGUID(false),

		MaxArtifactsCost = 0, -- maximum artifact cost this spell can hold
		CurrentArtifactsCost = 0, -- each artifact has a cost to it

		Type = 'NULL', -- projectile, close-aoe, single-attack, self
		Attributes = {}, -- attribute UUIDs
		Operations = {}, -- array of UUIDs pointing to ArtifactDatas (+ indicates order)
	}
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
