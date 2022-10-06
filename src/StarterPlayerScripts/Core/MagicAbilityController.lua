local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local ContextActionService = game:GetService('ContextActionService')

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicControllerConfig = ReplicatedModules.Data.MagicControllerConfig

local RemoteService = ReplicatedModules.Services.RemoteService
local AbilityHandlerFunction = RemoteService:GetRemote('AbilityHandlerFunction', 'RemoteFunction', false)
local AbilityHandlerEvent = RemoteService:GetRemote('AbilityHandlerEvent', 'RemoteEvent', false)

local SystemsContainer = {}

local AbilityKeybindMap = MagicControllerConfig.AbilityKeybindMap

local HoldingKeybinds = {}

-- // Module // --
local Module = {}

function Module:AwaitKeybindRelease(KeybindEnum)
	while HoldingKeybinds[KeybindEnum] do
		task.wait(0.1)
	end
end

function Module:HandleClientEvent(Data)
	warn('Handle Client Event - ', Data)
end

function Module:HandleClientInvoked(Data)
	warn('Handle Client Event - ', Data)
end

function Module:SetupKeybinds()
	local function HandleKeybind(actionName, inputState, inputObject)
		-- not related to this action
		if actionName ~= MagicControllerConfig.ABILITY_TRIGGER_ACTION_NAME then
			return
		end

		-- on input began
		if inputState == Enum.UserInputState.Begin then
			print('Ability Start; ', inputObject.KeyCode)

			HoldingKeybinds[inputObject.KeyCode] = true
			local keyIndex = table.find(AbilityKeybindMap, inputObject.KeyCode)
			local doAbility, err = AbilityHandlerFunction:InvokeServer({
				Job = MagicControllerConfig.ABILITY_TRIGGER_START,
				Keybind = keyIndex,
			})

			print(doAbility and 'Ability has been triggered! ' or 'Could not activate ability!')
			if doAbility then
				print('Run ability ui trigger effect for ', keyIndex)
				print('Await ability cooldown ui effect for ', keyIndex)
			else
				warn(err)
			end
		elseif inputState == Enum.UserInputState.End then -- on input ended
			warn('Ability Keybind Released - ', inputObject.KeyCode)

			HoldingKeybinds[inputObject.KeyCode] = nil
			AbilityHandlerEvent:FireServer({
				Job = MagicControllerConfig.ABILITY_TRIGGER_END,
				Keybind = table.find(AbilityKeybindMap, inputObject.KeyCode)
			})
		end
	end

	ContextActionService:BindAction(
		MagicControllerConfig.ABILITY_TRIGGER_ACTION_NAME, HandleKeybind,
		false, unpack(AbilityKeybindMap)
	)
end

function Module:ClearKeybinds()
	ContextActionService:UnbindAction(MagicControllerConfig.ABILITY_TRIGGER_START)
	ContextActionService:UnbindAction(MagicControllerConfig.ABILITY_TRIGGER_END)
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	AbilityHandlerFunction.OnClientInvoke = function(...)
		return Module:HandleClientInvoked(...)
	end

	AbilityHandlerEvent.OnClientEvent:Connect(function(...)
		Module:HandleClientEvent(...)
	end)

	-- Only if there are abilities should this be setup,
	-- otherwise cleanup the keybinds
	Module:SetupKeybinds() -- default
end

return Module
