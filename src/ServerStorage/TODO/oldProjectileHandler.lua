local RunService = game:GetService('RunService')
local Debris = game:GetService('Debris')
local Players = game:GetService('Players')

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local EventClass = require(script.Parent.Parent.Classes.Event)
local Visualizers = require(script.Parent.Parent.Utility.Visualizers)

if RunService:IsServer() and (not workspace:FindFirstChild('Projectiles')) then
	local Folder = Instance.new('Folder')
	Folder.Name = 'Projectiles'
	Folder.Parent = workspace
end

-- // Variables // --
local ActiveProjectiles = { }

local defaultRaycastParams = RaycastParams.new()
defaultRaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
defaultRaycastParams.IgnoreWater = true

local GLOBAL_TIME_SCALE = 0.5
local GLOBAL_ACCELERATION = -Vector3.new( 0, workspace.Gravity, 0 )

-- // Functions // --
local function defaultOnRayHit( projectileData )
	return true -- Stop
end

local function GetPositionAtTime(time, origin, initialVelocity, acceleration)
	local force = Vector3.new((acceleration.X * time^2) / 2,(acceleration.Y * time^2) / 2, (acceleration.Z * time^2) / 2)
	return origin + (initialVelocity * time) + force
end

-- A variant of the function above that returns the velocity at a given point in time.
local function GetVelocityAtTime(time, initialVelocity, acceleration)
	return initialVelocity + acceleration * time
end

-- // Projectile Class // --
local BaseProjectile = { }
BaseProjectile.__index = BaseProjectile

function BaseProjectile.New( Origin, Velocity )

	local self = {
		--ID = os.clock(),
		Active = false,
		LastRayParams = false,

		TimeElapsed = 0,
		Position = Vector3.new(),
		Velocity = Vector3.new(),
		Acceleration = Vector3.new(),

		Lifetime = 3,

		_iPosition = Origin.Position,
		_iDirection = Origin.LookVector,
		_iVelocity = Velocity,

		RayHitEvent = EventClass.New(),
		RayTerminatedEvent = EventClass.New(),

		OnRayHit = defaultOnRayHit,
		OnRayUpdated = false,
		OnProjectileTerminated = false,

		DebugData = false,
		DebugSteps = { },
		DebugVisuals = false, --RunService:IsClient(),

		UserData = { },
		RaycastParams = defaultRaycastParams,
	}

	setmetatable(self, BaseProjectile)

	self:Update( 0 )

	return self

end

function BaseProjectile:SetRayOnHitFunction( func )
	if typeof(func) == 'function' then
		self.OnRayHit = func
	end
end

function BaseProjectile:SetTerminatedFunction( func )
	if typeof(func) == 'function' then
		self.OnProjectileTerminated = func
	end
end

function BaseProjectile:SetUpdatedFunction( func )
	if typeof(func) == 'function' then
		self.OnRayUpdated = func
	end
end

function BaseProjectile:AddAccelerate( acceleration )
	self.Acceleration += acceleration
end

function BaseProjectile:SetAcceleration( acceleration )
	self.Acceleration = acceleration
end

function BaseProjectile:SetActive( isActive )
	self.Active = isActive
end

function BaseProjectile:Update( dt )

	dt *= GLOBAL_TIME_SCALE

	self.TimeElapsed += dt

	if self.TimeElapsed > self.Lifetime then
		-- warn('Terminate Projectile, Time Elapsed over duration of ' .. tostring( self.Lifetime ))
		self:Destroy()
		return
	end

	local nextPosition = GetPositionAtTime( self.TimeElapsed , self._iPosition, self._iVelocity, self.Acceleration)
	local nextVelocity = GetVelocityAtTime( self.TimeElapsed, self._iVelocity, self.Acceleration)

	local Dir = ((nextPosition - self.Position).Unit * nextVelocity.Magnitude) * dt
	local raycastResult = workspace:Raycast( self.Position, Dir, self.RaycastParams or defaultRaycastParams )

	if self.DebugVisuals then
		local Point = Instance.new('Attachment')
		Point.Visible = true
		Point.WorldPosition = self.Position
		Point.Parent = workspace.Terrain
		Visualizers:Beam( self.Position, self.Position + Dir, 2, { Color = ColorSequence.new(Color3.new(1, 1, 1)) } )
		Debris:AddItem(Point, 3)
	end

	self.LastRayParams = raycastResult

	local doKillRay = raycastResult and self.OnRayHit and self.OnRayHit( self, raycastResult )

	self.Velocity = nextVelocity
	self.Position = doKillRay and raycastResult.Position or nextPosition

	if self.DebugData then
		table.insert( self.DebugSteps, { time = self.TimeElapsed, Position = self.Position, Velocity = self.Velocity, })
	end
	if self.OnRayUpdated then
		task.spawn(self.OnRayUpdated, self, dt)
	end

	-- print( string.format('(%s) (%s) (%s)', tostring(self.Position), tostring(self.Velocity.Magnitude), tostring(raycastResult) ) )
	if doKillRay then
		-- warn('Kill Projectile @ ', raycastResult.Position)
		self:Destroy()
	end

end

function BaseProjectile:Destroy()
	self.Disposed = true
	if self.OnProjectileTerminated then
		task.spawn(self.OnProjectileTerminated, self)
	end
end

-- // Module // --
local Module = { ActiveProjectiles = ActiveProjectiles }

function Module:CreateBulletProjectile( LocalPlayer, Origin, Velocity )

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
	raycastParams.IgnoreWater = true
	raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }

	if RunService:IsClient() then
		table.insert(raycastParams.FilterDescendantsInstances, workspace:WaitForChild('Projectiles'))
	end

	local projectileData = BaseProjectile.New( Origin, Velocity )
	projectileData.RaycastParams = raycastParams
	projectileData:SetAcceleration( GLOBAL_ACCELERATION )

	projectileData.OnRayHit = function( self, raycastResult )

		local debugMessage = string.format(
			'Default OnRayHit: Projectile has RayHit at Vector3 (%s) with Instance (%s)',
			tostring( raycastResult.Position ),
			tostring( raycastResult.Instance:GetFullName() )
		)

		print(debugMessage)

		return true -- Keep going

	end

	projectileData.OnRayUpdated = false
	projectileData.OnProjectileTerminated = false

	table.insert(ActiveProjectiles, projectileData)

	return projectileData

end

function Module:KillProjectile( projectileUUID )
	for i, projectileData in ipairs( ActiveProjectiles ) do
		if not projectileData.UserData then
			continue
		end
		if projectileData.UserData.UUID == projectileUUID then
			projectileData:Destroy()
			break
		end
	end
end

RunService.Heartbeat:Connect(function( dt )
	local index = 1
	while index <= #ActiveProjectiles do
		local projectileClass = ActiveProjectiles[index]
		if projectileClass.Disposed then
			table.remove(ActiveProjectiles, index)
		else
			if projectileClass.Active then
				task.spawn(function()
					projectileClass:Update( dt )
				end)
			end
			index += 1
		end
	end
end)

return Module
