
-- // Module // --
local Module = {}

-- Get a dictionary of [UUID] = Data given a base data table
function Module:GetUUIDDictionaryFromData(DataArray)
	local Dict = {}
	for _, Data in ipairs( DataArray ) do
		Dict[Data.UUID] = Data
	end
	return Dict
end

return Module
