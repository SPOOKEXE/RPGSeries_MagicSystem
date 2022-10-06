
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

function BaseActiveMagic:Init()

end

function BaseActiveMagic:Start()
	self.Active = true
	self.OperationIndex += 1
end

function BaseActiveMagic:Stop()
	self.Active = false
end

function BaseActiveMagic:Destroy()

end

function BaseActiveMagic:CastExtendedMagic()
	-- sourceMagic = The magic which casted the extended magic
	-- nextOperationsIndex = The index of the next operations starting after this current sourceMagic operation
	-- newMagicCastData = The specified data of the new casted data (magic type, elements)
	-- returns; client data and server data for the newly casted magics (array form)
	local newMagicClass = BaseActiveMagic.New(self.SourceMagic, self.OperationIndex + 1)
	if self.Active then
		newMagicClass:Start()
	end
end

-- // BASE RUNE TYPE A // --

-- // BASE RUNE TYPE B // --

-- // BASE RUNE TYPE C // --

-- // BASE RUNE TYPE D // --

-- // RETURN TYPES // --
return { BaseActiveMagic = BaseActiveMagic }
