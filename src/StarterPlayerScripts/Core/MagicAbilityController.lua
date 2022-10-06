local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local ContextActionService = game:GetService('ContextActionService')

local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer
local LocalMouse = LocalPlayer:GetMouse()

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local MagicControllerConfig = ReplicatedModules.Data.MagicControllerConfig

local RemoteService = ReplicatedModules.Services.RemoteService
local AbilityHandlerFunction = RemoteService:GetRemote('AbilityHandlerFunction', 'RemoteFunction', false)
local AbilityHandlerEvent = RemoteService:GetRemote('AbilityHandlerEvent', 'RemoteEvent', false)
local MouseUpdateEvent = RemoteService:GetRemote('MouseUpdateEvent', 'RemoteEvent', false)

local SystemsContainer = {}

local AbilityKeybindMap = MagicControllerConfig.ABILITY_KEYBIND_MAP

local HoldingKeybinds = {}
local KeybindCleanupMaid = ReplicatedModules.Classes.Maid.New()

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

	-- handle keybinds
	ContextActionService:BindAction(MagicControllerConfig.ABILITY_TRIGGER_ACTION_NAME, function(actionName, inputState, inputObject)
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
				Index = keyIndex,
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
				Index = table.find(AbilityKeybindMap, inputObject.KeyCode)
			})
		end
	end, false, unpack(AbilityKeybindMap))

	-- cleanup keybinds
	KeybindCleanupMaid:Give(function()
		HoldingKeybinds = {}
	end)

	KeybindCleanupMaid:Give(RunService.Heartbeat:Connect(function()
		local HitCF = LocalMouse.Hit
		local Position, LookVector = HitCF.Position, HitCF.LookVector
		MouseUpdateEvent:FireServer(
			math.floor(Position.X * 10) / 10,
			math.floor(Position.Y * 10) / 10,
			math.floor(Position.Z * 10) / 10,
			math.floor(LookVector.X * 100) / 100,
			math.floor(LookVector.Y * 100) / 100,
			math.floor(LookVector.Z * 100) / 100
		)
	end))
end

function Module:ClearKeybinds()
	ContextActionService:UnbindAction(MagicControllerConfig.ABILITY_TRIGGER_ACTION_NAME)
	KeybindCleanupMaid:Cleanup() -- cleanup extras
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
