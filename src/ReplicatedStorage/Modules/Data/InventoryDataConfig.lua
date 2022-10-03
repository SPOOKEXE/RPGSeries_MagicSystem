
-- // Module // --
local Module = {}

function Module:GetCountedIndexArrayFromData(IndexName, TargetIndexValue, DataArray, totalCount)
	totalCount = math.max(1, totalCount or 1)
	local FoundArray = {}
	for _, Data in pairs( DataArray ) do
		if Data[IndexName] == TargetIndexValue then
			table.insert(FoundArray, Data)
			if #FoundArray >= totalCount then
				break
			end
		end
	end
	return FoundArray
end

-- Get a number of a particular 'ID' given an array
function Module:GetCountedIDArrayFromData(ID, DataArray, totalCount)
	return Module:GetCountedIndexArrayFromData('ID', ID, DataArray, totalCount)
end

-- Get a number of a particular 'Type' given an array
function Module:GetCountedTypeArrayFromData(Type, DataArray, totalCount)
	return Module:GetCountedIndexArrayFromData('Type', Type, DataArray, totalCount)
end

-- Get a dictionary of [UUID] = Data given a base data table
function Module:GetUUIDDictionaryFromData(DataArray)
	local Dict = {}
	for _, Data in pairs( DataArray ) do
		if Data.UUID then
			Dict[Data.UUID] = Data
		end
	end
	return Dict
end

return Module
