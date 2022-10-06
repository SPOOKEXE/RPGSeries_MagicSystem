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

-- This holds the data for any magic ability operation data
-- (operation runes control how the ability work)
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

-- This holds the data for any magic ability
-- note: players cannot create new magic abilities without a Magic Rune.
function Module:NewBaseMagicData()
	return {
		UUID = HttpService:GenerateGUID(false),

		MaxMagicDataCost = 5, -- maximum artifact cost this ability can hold (from Base Rune)
		CurrentMagicDataCost = 0, -- each artifact has a cost to it (compiled cost)

		BaseRune = false, -- uuid pointing to the magic rune data
		Elements = table.create(MagicDataConfigModule.MaxElementsPerAbility, false), -- element rune UUIDs
		Operations = {}, -- array of UUIDs pointing to ArtifactDatas (+ indicates order)
	}
end

-- ==================================================== --
-- ==================================================== --
-- ==================================================== --

-- Reconcile Magic Data
function Module:ReconcileMagicData(PlayerProfileData, MagicData)
	while #MagicData.Elements > MagicDataConfigModule.MaxElementsPerAbility do
		table.remove(MagicData.Elements, #MagicData.Elements)
	end
	Module:ClearAllEmptyBaseMagics(PlayerProfileData)
	Module:RecalculateMagicDataCost(PlayerProfileData, MagicData)
end

-- Recalculate magic cost
function Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local NewMagicCost = 0
	for _, elementUUID in ipairs(magicData.Elements) do
		if not elementUUID then
			continue
		end
		local elementData = MagicItemCache[elementUUID]
		local elementConfig = elementData and MagicDataConfigModule.Elements[elementData.Type]
		if elementConfig then
			NewMagicCost += (elementConfig.Cost or 1)
		end
	end
	for _, operationUUID in ipairs( magicData.Operations ) do
		local operationData = MagicItemCache[operationUUID]
		local operationConfig = operationData and MagicDataConfigModule.OperationsData[operationData.Type]
		if operationConfig then
			NewMagicCost += (operationConfig.Cost or 1)
		end
	end
	magicData.MaxMagicDataCost = NewMagicCost

	local baseRuneData = magicData.BaseRune and MagicItemCache[magicData.BaseRune]
	magicData.MaxMagicDataCost = baseRuneData and baseRuneData.MaxMagicDataCost or -1
end

-- Update the base magic so its under the rune cost
function Module:IsOverBaseRuneCost(PlayerProfileData, magicData)
	Module:RecalculateMagicDataCost(PlayerProfileData, magicData)
	return magicData.CurrentMagicDataCost <= magicData.MaxMagicDataCost
end

-- Can this operation be placed at this point in the operations array of a magic ability
function Module:CanOperationBePlacedAtIndex(PlayerProfileData, magicData, operationData, index)
	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local baseRuneData = magicData.BaseRune and MagicItemCache[magicData.BaseRune]
	-- if not baseRune then
	-- 	return false, 'Pick a Base Rune before trying to add operations to the ability.'
	-- end

	local currentOperationConfig = MagicDataConfigModule.OperationsData[operationData.Type]
	if currentOperationConfig.UseAllowedRuneTypeWhitelist then
		-- base rune whitelist check
		if baseRuneData and not table.find(currentOperationConfig.RuneTypeWhitelist, baseRuneData.Type) then
			return false, 'The BaseRune does not support this operation type.'
		end
	else
		-- base rune blacklist check
		if baseRuneData and table.find(currentOperationConfig.RuneTypeBlacklist, baseRuneData.Type) then
			return false, 'The BaseRune does not support this operation type.'
		end
	end

	-- Elements check
	local UsedElementsTypeArray = {} do
		for _, usedElementUUID in ipairs(magicData.Elements) do
			if not usedElementUUID then
				continue
			end
			local elementData = MagicItemCache[usedElementUUID]
			table.insert(UsedElementsTypeArray, elementData.Type)
		end
	end

	if currentOperationConfig.UseAllowedElementTypeWhitelist then
		-- whitelist check
		for _, usedElementUUID in ipairs( magicData.Elements ) do
			if not table.find(currentOperationConfig.ElementTypeWhitelist, usedElementUUID) then
				return false, 'Cannot use this operation whilst using the element '..(usedElementUUID)
			end
		end
	else
		-- blacklist check
		for _, disallowedElementType in ipairs(currentOperationConfig.ElementTypeBlacklist) do
			if table.find(UsedElementsTypeArray, disallowedElementType) then
				return false, 'Cannot use this operation whilst using the element '..(disallowedElementType)
			end
		end
	end

	-- Previous operation check
	-- (check if this can go there and check if the previous rune allows this to be after it)
	local previousOperationRuneUUID = magicData.Operations[index-1]
	local previousOperationRuneData = previousOperationRuneUUID and MagicItemCache[previousOperationRuneUUID]
	if previousOperationRuneData then
		local previousRuneDataConfig = MagicDataConfigModule.OperationsData[previousOperationRuneData.Type]

		-- does this rune allow the previous to be there?
		if currentOperationConfig.UsePreviousOperationTypeWhitelist then
			-- whitelist
			if not table.find(currentOperationConfig.PreviousOperationTypeWhitelist, previousOperationRuneData.Type) then
				return false, 'Cannot use this operation rune here as this rune does not allow '..previousOperationRuneData.Type..' type before it.'
			end
		else
			-- blacklist
			if table.find(currentOperationConfig.PreviousOperationTypeBlacklist, previousOperationRuneData.Type) then
				return false, 'Cannot use this operation rune here as this rune does not allow '..previousOperationRuneData.Type..' type before it.'
			end
		end

		-- does the previous rune allow this rune to be here?
		if previousRuneDataConfig.UseNextOperationTypeWhitelist then
			-- whitelist
			if not table.find(previousRuneDataConfig.NextOperationTypeWhitelist, currentOperationConfig.Type) then
				return false, 'Cannot use this operation rune here as the next rune does not allow '..currentOperationConfig.Type..' type before it.'
			end
		else
			-- blacklist
			if table.find(previousRuneDataConfig.NextOperationTypeBlacklist, currentOperationConfig.Type) then
				return false, 'Cannot use this operation rune here as the next rune does not allow '..currentOperationConfig.Type..' type before it.'
			end
		end
	end

	-- Next operation check
	-- (check if this can go there and check if the next rune allows this to be before it)
	local nextOperationRuneUUID = magicData.Operations[index+1]
	local nextOperationRuneData = nextOperationRuneUUID and MagicItemCache[nextOperationRuneUUID]
	if nextOperationRuneData then
		local nextRuneDataConfig = MagicDataConfigModule.OperationsData[nextOperationRuneData.Type]

		if currentOperationConfig.UseNextOperationTypeBlacklist then
			-- blacklist
			if table.find(currentOperationConfig.NextOperationTypeBlacklist, nextOperationRuneData.Type) then
				return false, 'Cannot use this operation rune here as this rune does not allow '..nextOperationRuneData.Type..' type before it.'
			end
		else
			-- whitelist
			if not table.find(currentOperationConfig.NextOperationTypeWhitelist, nextOperationRuneData.Type) then
				return false, 'Cannot use this operation rune here as this rune does not allow '..nextOperationRuneData.Type..' type before it.'
			end
		end

		-- does the next rune allow this rune to be here?
		if nextRuneDataConfig.UsePreviousOperationTypeBlacklist then
			-- blacklist
			if table.find(nextRuneDataConfig.PreviousOperationTypeBlacklist, currentOperationConfig.Type) then
				return false, 'Cannot use this operation rune here as the rune does not allow '..currentOperationConfig.Type..' type before it.'
			end
		else
			-- whitelist
			if not table.find(nextRuneDataConfig.PreviousOperationTypeWhitelist, currentOperationConfig.Type) then
				return false, 'Cannot use this operation rune here as the rune does not allow '..currentOperationConfig.Type..' type before it.'
			end
		end
	end

	return true
end

-- ==================================================== --
-- ==================================================== --
-- ==================================================== --

-- Set the base magic rune uuid
function Module:SetMagicBaseRuneUUID(PlayerProfileData, magicData, baseRuneUUID)
	local ElementRuneCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local runeData = ElementRuneCache[baseRuneUUID]
	if not runeData then
		return false, 'Base Rune with UUID could not be found: '..tostring(baseRuneUUID)
	end
	local OldBaseRuneData = magicData.BaseRune and ElementRuneCache[baseRuneUUID]
	if OldBaseRuneData then
		OldBaseRuneData.ParentMagic = false
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
	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local elementRuneData = MagicItemCache[elementRuneUUID]
	local elementRuneConfig = elementRuneData and MagicDataConfigModule.Elements[elementRuneData.Type]
	if not elementRuneData then
		return false, 'Element Rune with UUID could not be found: '..tostring(elementRuneUUID)
	end

	-- Elements check
	local UsedElementsTypeArray = {} do
		for _, usedElementRuneUUID in ipairs(magicData.Elements) do
			if not usedElementRuneUUID then
				continue
			end
			local targetElementData = MagicItemCache[usedElementRuneUUID]
			local targetElementConfig = MagicDataConfigModule.Elements[targetElementData.Type]
			if targetElementConfig.UseAllowedElementTypeWhitelist then
				if not table.find(targetElementConfig.ElementTypeWhitelist, elementRuneConfig.Type) then
					return false, 'You cannot mix these elements! '..targetElementConfig.Type..' and '..elementRuneConfig.Type
				end
			else
				if table.find(targetElementConfig.ElementTypeBlacklist, elementRuneConfig.Type) then
					return false, 'You cannot mix these elements! '..targetElementConfig.Type..' and '..elementRuneConfig.Type
				end
			end
			table.insert(UsedElementsTypeArray, targetElementConfig.Type)
		end
	end

	if elementRuneConfig.UseAllowedElementTypeWhitelist then
		for _, usedType in ipairs( UsedElementsTypeArray ) do
			if not table.find(elementRuneConfig.ElementTypeWhitelist, usedType) then
				return false, 'You cannot mix these elements! '..usedType..' and '..elementRuneConfig.Type
			end
		end
	else
		for _, usedType in ipairs( UsedElementsTypeArray ) do
			if table.find(elementRuneConfig.ElementTypeBlacklist, usedType) then
				return false, 'You cannot mix these elements! '..usedType..' and '..elementRuneConfig.Type
			end
		end
	end

	-- remove it from the data if it already exists
	local existent_index = table.find(magicData.Elements, elementRuneUUID)
	if existent_index then
		magicData.Elements[existent_index] = false
	end

	-- swap spots with this one if the selected rune was in a different spot
	-- otherwise reset the ParentMagic of the rune that was there
	if index and existent_index then
		-- swap spots
		magicData.Elements[existent_index] = magicData.Elements[index]
	elseif magicData.Elements[index] then
		magicData.Elements[index].ParentMagic = false
	end

	-- replace over the chosen spot
	magicData.Elements[index] = elementRuneUUID
	elementRuneData.ParentMagic = magicData.UUID

	return true
end

-- Swap the two operation order indexes if allowed, otherwise disallow
-- most of the notes from AddMagicDataOperation apply here
function Module:SwapMagicDataOperationOrder(PlayerProfileData, magicData, index1, index2)
	index1 = math.clamp(index1, 1, #magicData.Operations)
	index2 = math.clamp(index2, 1, #magicData.Operations)

	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local operation1UUID = magicData.Operations[index1]
	local operationData = MagicItemCache[operation1UUID]
	if not operationData then
		return false, 'No Operation Data found at index1!'
	end

	local canBePlaced, reason = Module:CanOperationBePlacedAtIndex(PlayerProfileData, magicData, operationData, index2)
	if not canBePlaced then
		return false, reason
	end

	local operation2UUID = magicData.Operations[index2]
	local otherOperationData = MagicItemCache[operation2UUID]
	if otherOperationData then
		canBePlaced, reason = Module:CanOperationBePlacedAtIndex(PlayerProfileData, magicData, otherOperationData, index1)
		if not canBePlaced then
			return false, reason
		end
	end

	-- swap them
	magicData.Operations[index2] = operation1UUID
	if operation2UUID then
		magicData.Operations[index1] = operation2UUID
	end

	return true
end

-- Remove a magic operation out of the magic ability
-- If the next operations are unsupported for the new earlier step,
-- unequip those automatically with a warning message
function Module:RemoveMagicDataOperation(PlayerProfileData, magicData, operationUUID)
	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local operationData =MagicItemCache[operationUUID]
	if not operationData then
		return false, 'No matching Operation Data found in inventory!'
	end

	local existing_index = table.find(magicData.Operations, operationUUID)
	if not existing_index then
		return true
	end

	operationData.ParentMagic = false
	table.remove(magicData.Operations, existing_index)

	local newDataPlacement = magicData.Operations[existing_index]
	if not newDataPlacement then
		return true
	end

	local canBe, _ = Module:CanOperationBePlacedAtIndex(PlayerProfileData, magicData, newDataPlacement, existing_index)
	if not canBe then
		-- if the operation that was shifted left cannot fit there
		-- remove everything after the index point.
		while #magicData.Operations > existing_index do
			local LastUUID = magicData.Operations[#magicData.Operations]
			local otherOperationData = MagicItemCache[LastUUID]
			otherOperationData.ParentMagic = false -- reset the ParentMagic
			table.remove(magicData.Operations, #magicData.Operations)
		end
	end

	return true
end

-- Add a magic operation to the magic ability at the index (otherwise at the end)
-- if it cannot be there, nothing happens.
-- if the operation is already being used, it will swap places with the selected index
-- if any operations after the selected index cannot be there, it will remove everything
-- from that point afterwards
function Module:AddMagicDataOperation(PlayerProfileData, magicData, operationUUID, index)
	local MagicItemCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicItemsInventory)

	local operationData =	MagicItemCache[operationUUID]
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
		local canBePlaced, reason = Module:CanOperationBePlacedAtIndex(PlayerProfileData, magicData, operationData, index)
		if not canBePlaced then
			return false, reason
		end

		operationData.ParentMagic = magicData.UUID
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

-- allow this ability to be created even if all slots aren't filled
-- but don't allow the player to actually use the magic unless it has the bare minimum
function Module:CreateBaseMagicAbility(PlayerProfileData, magicRuneUUID, elementRuneUUIDs, operationUUIDs)
	if #PlayerProfileData.MagicAbilityInventory + 1 > MagicDataConfigModule.MaximumAbilitiesInInventory then
		return false, 'You have reached the maximum capacity of magic abilities.'
	end

	local emptyAbilityData = Module:NewBaseMagicData()
	Module:SetMagicBaseRuneUUID(PlayerProfileData, emptyAbilityData, magicRuneUUID)
	for _, UUID in ipairs( elementRuneUUIDs or {} ) do
		Module:SetMagicElementRuneUUID(PlayerProfileData, emptyAbilityData, UUID)
	end
	for _, Operation in ipairs( operationUUIDs or {} ) do
		Module:SetMagicBaseRuneUUID(PlayerProfileData, emptyAbilityData, Operation)
	end
	table.insert(PlayerProfileData.MagicAbilityInventory, emptyAbilityData)
	return emptyAbilityData
end

-- Equip magic abilities
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

	-- update equipped magic in the actual ability system
	SystemsContainer.MagicAbilityService:UpdateEquipped(LocalPlayer)

	return true
end

-- clears all empty base magic abilities
function Module:ClearAllEmptyBaseMagics(PlayerProfileData)
	-- clear from magic inventory
	local _index = 1
	while _index <= #PlayerProfileData.MagicAbilityInventory do
		local magicData = PlayerProfileData.MagicAbilityInventory[_index]
		if magicData.BaseRune == false and #magicData.Elements == 0 and #magicData.Operations == 0 then
			table.remove( PlayerProfileData.MagicAbilityInventory, _index)
		else
			_index += 1
		end
	end

	-- clear equipped uuids that no longer have data in the magic inventory
	local UUIDCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicAbilityInventory)
	for index, equippedUUID in ipairs( PlayerProfileData.EquippedMagic ) do
		if not UUIDCache[equippedUUID] then
			PlayerProfileData.EquippedMagic[index] = false
		end
	end
end

-- Handle any remote invokations
function Module:HandleDataEditRemote(LocalPlayer, Data)
	warn('HANDLE REMOTE - ', LocalPlayer, Data)
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	MagicDataEditFunction.OnServerInvoke = function(LocalPlayer, Data)
		if typeof(Data) == 'table' then
			return Module:HandleDataEditRemote(LocalPlayer, Data)
		end
		return nil, 'Inalid argument provided.'
	end
end

return Module
