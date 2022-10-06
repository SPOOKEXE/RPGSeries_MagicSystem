local Players = game:GetService('Players')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicControllerConfig = ReplicatedModules.Data.MagicControllerConfig

local RemoteService = ReplicatedModules.Services.RemoteService
local AbilityHandlerFunction = RemoteService:GetRemote('AbilityHandlerFunction', 'RemoteFunction', false)
local AbilityHandlerEvent = RemoteService:GetRemote('AbilityHandlerEvent', 'RemoteEvent', false)

local PingTimesModule = ReplicatedCore.PingTimes -- local playerPing = PingTimesModule[LocalPlayer]

local SystemsContainer = {}

local KeybindHolding = {}

-- // Base Active Magic Class // --
local BaseActiveMagic = {}
BaseActiveMagic.__index = BaseActiveMagic

function BaseActiveMagic.New(LocalPlayer, SourceMagic, startOperationIndex)

	local self = {
		Active = false,
		LocalPlayer = LocalPlayer,
		SourceMagic = SourceMagic,
		OperationIndex = startOperationIndex or 0,
	}

	setmetatable(self, BaseActiveMagic)

	return self
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

-- sourceMagic = The magic which casted the extended magic
-- nextOperationsIndex = The index of the next operations starting after this current sourceMagic operation
-- newMagicCastData = The specified data of the new casted data (magic type, elements)
-- returns; client data and server data for the newly casted magics (array form)
function BaseActiveMagic:CastExtendedMagic()
	local newMagicClass = BaseActiveMagic.New(self.SourceMagic, self.OperationIndex + 1)
	if self.Active then
		newMagicClass:Start()
	end
end

-- // Module // --
local Module = {}

-- Tell all clients a data with ping taken into account
function Module:FireClients_AccountPing(Data)
	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		Data.StartDelay = PingTimesModule[LocalPlayer]
		AbilityHandlerEvent:FireClient(LocalPlayer, Data)
	end
end

-- This handles the AbilityHandler RemoteFunction
function Module:HandleServerInvoke(LocalPlayer, Data)
	warn('Handle Server Invoke - ', LocalPlayer, Data)

	-- Module:FireClients_AccountPing(Data)

	if Data.Job == MagicControllerConfig.ABILITY_TRIGGER_START then
		KeybindHolding[LocalPlayer][Data.Index] = true
	end

	return false, 'Invalid JOB.'
end

-- This handles the AbilityHandler RemoteEvent
function Module:HandleServerEvent(LocalPlayer, Data)
	warn('Handle Server Event - ', LocalPlayer, Data)

	-- Module:FireClients_AccountPing(Data)

	if Data.Job == MagicControllerConfig.ABILITY_TRIGGER_END then
		KeybindHolding[LocalPlayer][Data.Index] = nil
	end
end

-- update the player's equipped magic
function Module:UpdateEquipped(LocalPlayer)
	warn('Magic Ability Service - Update Equipped Magic - '..LocalPlayer.Name)
end

-- when a player joins the game
function Module:PlayerAdded(LocalPlayer)
	KeybindHolding[LocalPlayer] = {} -- setup keybind holding data
end

-- when a player leaves the game
function Module:PlayerRemoving(LocalPlayer)
	KeybindHolding[LocalPlayer] = nil -- clear keybind holding data
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	-- when any player invokes the server
	AbilityHandlerFunction.OnServerInvoke = function(LocalPlayer, Data)
		print(LocalPlayer, Data)
		if typeof(Data) == 'table' then
			return Module:HandleServerInvoke(LocalPlayer, Data)
		end
		return false, "Invalid 'Data' passed."
	end

	-- when any client fires to the server
	AbilityHandlerEvent.OnServerEvent:Connect(function(LocalPlayer, Data)
		if typeof(Data) == 'table' then
			Module:HandleServerEvent(LocalPlayer, Data)
		end
	end)

	-- player added
	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		Module:PlayerAdded(LocalPlayer)
	end
	Players.PlayerAdded:Connect(function(LocalPlayer)
		Module:PlayerAdded(LocalPlayer)
	end)

	-- player removed
	Players.PlayerRemoving:Connect(function(LocalPlayer)
		Module:PlayerRemoving(LocalPlayer)
	end)
end

return Module
