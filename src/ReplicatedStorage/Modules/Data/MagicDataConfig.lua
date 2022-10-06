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

		Cooldown = 1,
	}, override)
end

-- // Module // --
local Module = {}

Module.BaseRuneTypes = {
	Projectile = fromBaseRune({

	}),
	Self = fromBaseRune({

	}),
}

Module.Elements = {
	-- pure elements
	Fire = fromBaseElement({

	}),
	--[[Water = fromBaseElement({

	}),
	Earth = fromBaseElement({

	}),
	Air = fromBaseElement({

	}),]]

	-- compound elements
	--[[
	Lighting = fromBaseElement({

	}),
	Magma = fromBaseElement({

	}),]]
}

Module.OperationsData = {

	-- // ACTIONS // --

	-- projectiles that aren't controlled
	NonControlledProjectile = fromBaseOperation({

	}),
	-- projectiles that are directionally controlled by mouse (or have minor directional control using mouse)
	MouseControlledProjectile = fromBaseOperation({

	}),
	-- split projectile into multiple projectiles
	SplitIntoSmaller = fromBaseOperation({

	}),

	-- single targets
	HealingSingle = fromBaseOperation({

	}),

	DamageSingle = fromBaseOperation({

	}),

	-- aoe targets
	HealingAOE = fromBaseOperation({

	}),

	DamageAOE = fromBaseOperation({

	}),

	-- // VISUALS // --
	ExplosionNoCrater = fromBaseOperation({

	}),

	ExplosionCrater = fromBaseOperation({

	}),

	-- // CONDITIONS // --
	DelaySeconds = fromBaseOperation({

	}),

	OnSurfaceImpact = fromBaseOperation({

	}),

	OnCharacterImpact = fromBaseOperation({

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
