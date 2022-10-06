local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local ContextActionService = game:GetService('ContextActionService')

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local RemoteService = ReplicatedModules.Services.RemoteService
local AbilityHandlerFunction = RemoteService:GetRemote('AbilityHandlerFunction', 'RemoteFunction', false)
local AbilityHandlerEvent = RemoteService:GetRemote('AbilityHandlerEvent', 'RemoteEvent', false)

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:HandleClientEvent(Data)
	warn('Handle Client Event - ', Data)
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	AbilityHandlerEvent.OnClientEvent:Connect(function(...)
		Module:HandleClientEvent(...)
	end)
end

return Module
