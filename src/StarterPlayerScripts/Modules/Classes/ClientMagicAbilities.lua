
-- // Base Active Magic Class // --
local BaseActiveMagic = {}
BaseActiveMagic.__index = BaseActiveMagic

function BaseActiveMagic.New(LocalPlayer, SourceMagic, startOperationIndex)
	local self = {
		super = nil,

		Active = false,
		LocalPlayer = LocalPlayer,
		SourceMagic = SourceMagic,
		OperationIndex = startOperationIndex or 0,
	}

	setmetatable(self, BaseActiveMagic)

	return self
end

function BaseActiveMagic:Start()

end

-- // BASE RUNE TYPE A // --

-- // BASE RUNE TYPE B // --

-- // BASE RUNE TYPE C // --

-- // BASE RUNE TYPE D // --

-- // RETURN TYPES // --
return { BaseActiveMagic = BaseActiveMagic }
