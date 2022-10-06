local Players = game:GetService('Players')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')

local ServerStorage = game:GetService('ServerStorage')
local ServerModules = require(ServerStorage:WaitForChild('Modules'))
local ServerMagicAbilityClassesModule = ServerModules.Classes.ServerMagicAbilities

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')
local ReplicatedCore = require(ReplicatedStorage:WaitForChild('Core'))
local ReplicatedModules = require(ReplicatedStorage:WaitForChild('Modules'))

local InventoryDataConfigModule = ReplicatedModules.Data.InventoryDataConfig
local MagicControllerConfig = ReplicatedModules.Data.MagicControllerConfig

local RemoteService = ReplicatedModules.Services.RemoteService
local AbilityHandlerFunction = RemoteService:GetRemote('AbilityHandlerFunction', 'RemoteFunction', false)
local AbilityHandlerEvent = RemoteService:GetRemote('AbilityHandlerEvent', 'RemoteEvent', false)
local MouseUpdateEvent = RemoteService:GetRemote('MouseUpdateEvent', 'RemoteEvent', false)

local PingTimesModule = ReplicatedCore.PingTimes -- local playerPing = PingTimesModule[LocalPlayer]

local SystemsContainer = {}

local PlayerCacheData = {}

-- // Module // --
local Module = {}

-- Tell all clients a data with ping taken into account
function Module:FireClients_AccountPing(Data)
	for _, LocalPlayer in ipairs( Players:GetPlayers() ) do
		Data.StartDelay = PingTimesModule[LocalPlayer]
		AbilityHandlerEvent:FireClient(LocalPlayer, Data)
	end
end

-- Handle invoking new magic
function Module:HandleInvokingMagic(LocalPlayer, magicIndex, magicData)
	local cacheData = PlayerCacheData[LocalPlayer]
	warn('Start Magic Handling; ', magicIndex, magicData, cacheData)
end

-- Check if magic at given index is on cooldown
function Module:CheckMagicCooldown(LocalPlayer, magicIndex, magicData, doResetAlso)
	local sharedCooldownTick = PlayerCacheData[LocalPlayer].DebounceTable.Shared

	local indexCooldownStr = 'Index_'..tostring(magicIndex)
	local indexCooldownTick =PlayerCacheData[LocalPlayer].DebounceTable[indexCooldownStr]

	local hasSharedFinished =
		(not sharedCooldownTick) or
		(tick() - sharedCooldownTick > MagicControllerConfig.COOLDOWN_INBETWEEN_ABILITIES)

	local hasIndexFinished =
		(not indexCooldownTick) or
		(tick() - indexCooldownTick > magicData.MagicCooldown)

	if hasSharedFinished and hasIndexFinished and doResetAlso then
		PlayerCacheData[LocalPlayer].DebounceTable.Shared = tick()
		PlayerCacheData[LocalPlayer].DebounceTable[indexCooldownStr] = tick()
	end

	return hasSharedFinished, hasIndexFinished
end

-- This handles the AbilityHandler RemoteFunction
function Module:HandleServerInvoke(LocalPlayer, Data)
	warn('Handle Server Invoke - ', LocalPlayer, Data)

	-- Module:FireClients_AccountPing(Data)

	local PlayerProfileData = SystemsContainer.FakeDataService:GetProfileFromPlayer(LocalPlayer).Data

	if Data.Job == MagicControllerConfig.ABILITY_TRIGGER_START and typeof(Data.Index) == 'number' then

		-- check if there is an equipped magic at the index
		local EquippedMagicUUID = PlayerProfileData.EquippedMagic[Data.Index]
		if not EquippedMagicUUID then
			return false, 'No magic is equipped in slot '..Data.Index
		end

		-- get the magic data from the equipped uuid
		local UUIDCache = InventoryDataConfigModule:GetUUIDDictionaryFromData(PlayerProfileData.MagicAbilityInventory)
		local magicData = UUIDCache[EquippedMagicUUID]
		if not magicData then
			return false, 'Could not find matching Magic Data from equipped UUID'
		end

		-- if the cooldown for all spells is still active, return
		local sharedCooldown, specificCooldown = Module:CheckMagicCooldown(LocalPlayer, Data.Index, magicData, true)
		if not sharedCooldown then
			return false, 'Casting any magic is on cooldown currently!'
		end
		-- if the cooldown for this specific spell is still active, return
		if not specificCooldown then
			return false, 'This magic is on cooldown currently!'
		end

		-- trigger magic (cooldown is auto reset using the fourth argument of CheckMagicCooldown)
		PlayerCacheData[LocalPlayer].KeybindHolding[Data.Index] = true
		task.defer(function()
			Module:HandleInvokingMagic(LocalPlayer, Data.Index, magicData)
		end)

		-- tell the client it triggered
		return true, 'Activating Magic'
	end

	-- tell the client nothing happened
	return false, 'Invalid JOB.'
end

-- This handles the AbilityHandler RemoteEvent
function Module:HandleServerEvent(LocalPlayer, Data)
	warn('Handle Server Event - ', LocalPlayer, Data)

	-- Module:FireClients_AccountPing(Data)

	if Data.Job == MagicControllerConfig.ABILITY_TRIGGER_END then
		PlayerCacheData[LocalPlayer].KeybindHolding[Data.Index] = nil
	end
end

-- update the player's equipped magic
function Module:UpdateEquipped(LocalPlayer)
	warn('Magic Ability Service - Update Equipped Magic - '..LocalPlayer.Name)
end

-- when a player joins the game
function Module:PlayerAdded(LocalPlayer)
	PlayerCacheData[LocalPlayer] = {
		KeybindHolding = {},
		DebounceTable = {},
		PlayerMouseCFrame = false,
	}
end

-- when a player leaves the game
function Module:PlayerRemoving(LocalPlayer)
	PlayerCacheData[LocalPlayer] = nil -- clear keybind holding data
end

function Module:Init(otherSystems)
	SystemsContainer = otherSystems

	-- when any player invokes the server
	AbilityHandlerFunction.OnServerInvoke = function(LocalPlayer, Data)
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

	-- when the client updates their mouse position
	MouseUpdateEvent.OnServerEvent:Connect(function(LocalPlayer, ...)
		-- if the total arguments is not 9 then return
		local args = {...}
		if #{...} ~= 6 then
			LocalPlayer:Kick('MouseUpdateEvent did not receive the correct arguments.')
			return
		end
		-- if any of the arguments are not a number then return
		for _, arg in ipairs( args ) do
			if typeof(arg) ~= 'number' then
				LocalPlayer:Kick('MouseUpdateEvent did not receive the correct arguments.')
				return
			end
		end
		-- reconstruct the cframe
		local pX, pY, pZ, dX, dY, dZ = unpack(args)
		local Position = Vector3.new(pX, pY, pZ)
		local ReformedCF = CFrame.lookAt(Position, Position + Vector3.new(dX, dY, dZ).Unit)
		PlayerCacheData[LocalPlayer].PlayerMouseCFrame = ReformedCF
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
