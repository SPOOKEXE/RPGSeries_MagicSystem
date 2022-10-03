
local InventoryDataModule = require(script.Parent.InventoryDataConfig)

-- // Module // --
local Module = {}

Module.MaxEquippedMagics = 5
Module.MaxElementsPerSpell = 3

Module.BaseRuneTypes = {
	Projectile = {},
	CloseAOE = {},
	TargetSingle = {},
	TargetMultiple = {},
	TargetSelf = {},
}

Module.Elements = {
	-- base elements
	Fire = {},
	-- Water = {},
	-- Earth = {},
	-- Air = {},
	-- compound elements
	--Lighting = {},
	-- Magma = {},
}

Module.OperationsData = {
	NonControlledProjectile = {}, -- projectiles that aren't controlled
	ControlledProjectile = {}, -- projectiles that are controlled (or have minor control over it)
	ExplosionNoCrater = { }, -- explode w/ no crater
	ExplosionCrater = { }, -- explode w/ crater
}

-- Get all the magic operation runes data given an array of UUIDs
function Module:GetMagicOperationRunesFromUUIDs(UUIDTable, OperationRuneArray)
	local RuneUUIDDictionary = InventoryDataModule:GetUUIDDictionaryFromData(OperationRuneArray)
	local runeDataArray = {}
	for _, UUID in ipairs( UUIDTable ) do
		if RuneUUIDDictionary[UUID] then -- check if the artifact exists with this key
			table.insert(runeDataArray, RuneUUIDDictionary[UUID])
		end
	end
	return runeDataArray
end

return Module
