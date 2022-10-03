local InventoryDataModule = require(script.Parent.InventoryDataConfig)
local TableUtility = require(script.Parent.Parent.Utility.Table)

local function includeTypeKey(tbl)
	for typee, data in pairs(tbl) do
		data.Type = typee
	end
end

-- what all base runes have
local function fromBaseRune(override)
	return TableUtility:SetProperties({

	}, override)
end

-- what all element runes have
local function fromBaseElement(override)
	return TableUtility:SetProperties({
		-- only allow certain elements to mix
		UseAllowedElementTypeWhitelist = false,
		ElementTypeWhitelist = {},
		ElementTypeBlacklist = {},
	}, override)
end

-- what all operation runes have
local function fromBaseOperation(override)
	return TableUtility:SetProperties({
		-- only allow this operation for certain rune types
		UseAllowedRuneTypeWhitelist = false,
		RuneTypeWhitelist = {},
		RuneTypeBlacklist = {},

		-- only allow this operation for certain element types
		UseAllowedElementTypeWhitelist = false,
		ElementTypeWhitelist = {},
		ElementTypeBlacklist = {},

		-- only these specific types of operations can be *DIRECTLY* BEFORE this one
		UsePreviousOperationTypeWhitelist = false,
		PreviousOperationTypeWhitelist = {},
		PreviousOperationTypeBlacklist = {},

		-- only these specific types of operations can be *DIRECTLY* AFTER this one
		UseNextOperationTypeWhitelist = false,
		NextOperationTypeWhitelist = {},
		NextOperationTypeBlacklist = {},
	}, override)
end

-- // Module // --
local Module = {}

Module.MaxEquippedMagics = 4
Module.MaxElementsPerAbility = 3
Module.MaximumAbilitiesInInventory = 20 -- maximum abilities the player can hold

Module.BaseRuneTypes = {
	Projectile = fromBaseRune({

	}),
	CloseAOE = fromBaseRune({

	}),
	TargetSingle = fromBaseRune({

	}),
	TargetMultiple = fromBaseRune({

	}),
	TargetSelf = fromBaseRune({

	}),
}

Module.Elements = {
	-- pure elements
	Fire = fromBaseElement({

	}),
	Water = fromBaseElement({

	}),
	Earth = fromBaseElement({

	}),
	Air = fromBaseElement({

	}),

	-- compound elements
	Lighting = fromBaseElement({

	}),
	Magma = fromBaseElement({

	}),
}

Module.OperationsData = {
	-- projectiles that aren't controlled
	NonControlledProjectile = fromBaseOperation({

	}),
	-- projectiles that are controlled (or have minor control over it)
	ControlledProjectile = fromBaseOperation({

	}),
	-- explode w/ no crater
	ExplosionNoCrater = fromBaseOperation({

	}),
	-- explode w/ crater
	ExplosionCrater = fromBaseOperation({

	}),
}

includeTypeKey(Module.BaseRuneTypes)
includeTypeKey(Module.Elements)
includeTypeKey(Module.OperationsData)

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
