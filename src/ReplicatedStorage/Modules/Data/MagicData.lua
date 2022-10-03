
local InventoryDataModule = require(script.Parent.InventoryData)

-- // Module // --
local Module = {}

Module.MaxEquippedMagics = 5

Module.ElementData = {

}

Module.MagicCommandData = {

}

Module.ArtifactData = {

}

-- Get all the magic artifact data given an array of UUIDs
function Module:GetMagicArtifactsFromUUIDs(UUIDTable, ArtifactTable)
	local ArtifactUUIDDictionary = InventoryDataModule:GetUUIDDictionaryFromData(ArtifactTable)
	local artifactDataArray = {}
	for _, UUID in ipairs( UUIDTable ) do
		if ArtifactUUIDDictionary[UUID] then -- check if the artifact exists with this key
			table.insert(artifactDataArray, ArtifactUUIDDictionary[UUID])
		end
	end
	return artifactDataArray
end

return Module
