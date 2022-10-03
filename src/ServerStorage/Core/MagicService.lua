local Players = game:GetService('Players')
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ReplicatedAssets = ReplicatedStorage:WaitForChild('Assets')

local SystemsContainer = {}

-- // Module // --
local Module = {}

function Module:Init(otherSystems)
	SystemsContainer = otherSystems
end

return Module
