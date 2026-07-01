local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local DebrisVFXService = {}
DebrisVFXService.__index = DebrisVFXService

local DEFAULT_GROUND_COLOR = Color3.fromRGB(115, 115, 115)
local DEFAULT_WALL_COLOR = Color3.fromRGB(230, 230, 235)

local function randomBetween(minValue, maxValue)
	return minValue + (math.random() * (maxValue - minValue))
end

local function randomVector3(minSize, maxSize)
	return Vector3.new(
		randomBetween(minSize.X, maxSize.X),
		randomBetween(minSize.Y, maxSize.Y),
		randomBetween(minSize.Z, maxSize.Z)
	)
end

local function getPosition(value)
	if typeof(value) == "CFrame" then
		return value.Position
	end

	if typeof(value) == "Vector3" then
		return value
	end

	return nil
end

local function getPlaneCFrame(position, normal, angle)
	local back = Vector3.zAxis

	if typeof(normal) == "Vector3" and normal.Magnitude > 0.05 then
		back = normal.Unit
	end

	local up = Vector3.yAxis
	if math.abs(back:Dot(up)) > 0.92 then
		up = Vector3.xAxis
	end

	local right = up:Cross(back)
	if right.Magnitude < 0.05 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	up = back:Cross(right)
	if up.Magnitude < 0.05 then
		up = Vector3.yAxis
	else
		up = up.Unit
	end

	return CFrame.fromMatrix(position, right, up, back) * CFrame.Angles(0, 0, angle or 0)
end

function DebrisVFXService.new(config)
	local self = setmetatable({}, DebrisVFXService)

	self.Config = config or {}
	self.RuntimeFolderName = self.Config.DebrisVFXFolderName or "VFX"

	return self
end

function DebrisVFXService:GetRuntimeFolder()
	local folder = workspace:FindFirstChild(self.RuntimeFolderName)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = self.RuntimeFolderName
		folder.Parent = workspace
	end

	return folder
end

function DebrisVFXService:GetRaycastParams(exclude)
	local excludeList = {}
	local runtimeFolder = self:GetRuntimeFolder()

	if runtimeFolder then
		table.insert(excludeList, runtimeFolder)
	end

	if typeof(exclude) == "table" then
		for _, instance in ipairs(exclude) do
			if instance then
				table.insert(excludeList, instance)
			end
		end
	elseif exclude then
		table.insert(excludeList, exclude)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList

	return params
end

function DebrisVFXService:RaycastGround(position, distance, exclude)
	if typeof(position) ~= "Vector3" then
		return nil
	end

	return workspace:Raycast(
		position + Vector3.new(0, 1.5, 0),
		Vector3.new(0, -(distance or 14), 0),
		self:GetRaycastParams(exclude)
	)
end

function DebrisVFXService:ScheduleRemovalTween(part, lifetime, removeTweenTime, options)
	if not part then
		return
	end

	lifetime = lifetime or 1
	removeTweenTime = removeTweenTime or 0
	options = options or {}

	if removeTweenTime <= 0 then
		Debris:AddItem(part, lifetime)
		return
	end

	task.delay(math.max(lifetime, 0), function()
		if not part or not part.Parent then
			return
		end

		local goal = {
			Transparency = 1,
			Size = Vector3.new(
				math.max(part.Size.X * 0.18, 0.05),
				math.max(part.Size.Y * 0.18, 0.05),
				math.max(part.Size.Z * 0.18, 0.05)
			),
		}

		if options.SinkDistance and options.SinkDistance > 0 then
			goal.CFrame = part.CFrame * CFrame.new(0, -options.SinkDistance, 0)
		end

		TweenService:Create(
			part,
			TweenInfo.new(removeTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			goal
		):Play()
	end)

	Debris:AddItem(part, lifetime + removeTweenTime + 0.08)
end

function DebrisVFXService:CreateDebrisPart(name, size, cframe, color, material, lifetime, removeTweenTime, removeOptions)
	local part = Instance.new("Part")
	part.Name = name or "BlockyDebris"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Material = material or Enum.Material.Concrete
	part.Color = color or DEFAULT_GROUND_COLOR
	part.Size = size
	part.CFrame = cframe
	part.Parent = self:GetRuntimeFolder()

	self:ScheduleRemovalTween(part, lifetime or 1, removeTweenTime, removeOptions)

	return part
end

function DebrisVFXService:SpawnCrater(positionOrCFrame, options)
	options = options or {}

	local origin = getPosition(positionOrCFrame)
	if not origin then
		return
	end

	local exclude = options.Exclude
	local rayResult = self:RaycastGround(origin, options.RaycastDistance or 18, exclude)
	local surfacePosition = rayResult and rayResult.Position or origin
	local surfaceColor = options.Color or (rayResult and rayResult.Instance and rayResult.Instance.Color) or DEFAULT_GROUND_COLOR
	local surfaceMaterial = options.Material or (rayResult and rayResult.Instance and rayResult.Instance.Material) or Enum.Material.Concrete

	local radius = options.Radius or 8
	local innerRadius = math.min(options.InnerRadius or 2.2, radius * 0.75)
	local count = math.clamp(options.Count or 18, 1, 42)
	local outerScatterCount = math.clamp(options.OuterScatterCount or 8, 0, 24)
	local minSize = options.MinSize or Vector3.new(1.4, 0.25, 0.8)
	local maxSize = options.MaxSize or Vector3.new(3.8, 0.55, 1.4)
	local outerMinSize = options.OuterMinSize or Vector3.new(0.9, 0.18, 0.7)
	local outerMaxSize = options.OuterMaxSize or Vector3.new(2.2, 0.35, 1.1)
	local lifetime = options.Lifetime or 2.3
	local removeTweenTime = options.RemoveTweenTime or 0.45
	local upTiltDegrees = options.UpTiltDegrees or 12
	local randomTiltDegrees = options.RandomTiltDegrees or 8
	local sinkDistance = options.SinkDistance or 0.35

	local function spawnSlab(name, angle, slabRadius, size, tiltMultiplier, lifetimeMultiplier)
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = surfacePosition + (radial * slabRadius) + Vector3.new(0, 0.09, 0)
		local tangentYaw = angle + (math.pi / 2)
		local yaw = tangentYaw + math.rad(randomBetween(-18, 18))
		local outwardTilt = math.rad(randomBetween(4, upTiltDegrees) * (tiltMultiplier or 1))
		local sideTilt = math.rad(randomBetween(-randomTiltDegrees, randomTiltDegrees))

		local cframe = CFrame.new(position)
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(outwardTilt, 0, sideTilt)

		self:CreateDebrisPart(
			name,
			size,
			cframe,
			surfaceColor,
			surfaceMaterial,
			lifetime * (lifetimeMultiplier or 1) * randomBetween(0.85, 1.15),
			removeTweenTime,
			{
				SinkDistance = sinkDistance,
			}
		)
	end

	for index = 1, count do
		local angle = ((index - 1) / count) * math.pi * 2
		angle += math.rad(randomBetween(-16, 16))

		local layerAlpha = (index % 3) / 2
		local slabRadius = randomBetween(innerRadius, radius)

		if layerAlpha == 0 then
			slabRadius = randomBetween(innerRadius, innerRadius + ((radius - innerRadius) * 0.38))
		elseif layerAlpha == 0.5 then
			slabRadius = randomBetween(innerRadius + ((radius - innerRadius) * 0.25), radius * 0.88)
		else
			slabRadius = randomBetween(radius * 0.68, radius)
		end

		local size = randomVector3(minSize, maxSize)
		if math.random() < 0.55 then
			size = Vector3.new(size.X * randomBetween(1.15, 1.45), size.Y, size.Z * randomBetween(0.75, 0.95))
		end

		spawnSlab("CraterSlabDebris", angle, slabRadius, size, randomBetween(0.75, 1.25), 1)
	end

	for _ = 1, outerScatterCount do
		local angle = math.rad(randomBetween(0, 360))
		local slabRadius = randomBetween(radius * 0.9, radius * 1.35)
		local size = randomVector3(outerMinSize, outerMaxSize)

		spawnSlab("OuterCraterSlabDebris", angle, slabRadius, size, randomBetween(0.45, 0.9), randomBetween(0.85, 1))
	end
end

function DebrisVFXService:SpawnGroundRing(positionOrCFrame, options)
	return self:SpawnCrater(positionOrCFrame, options)
end

function DebrisVFXService:SpawnFlyRocks(positionOrCFrame, options)
	options = options or {}

	local origin = getPosition(positionOrCFrame)
	if not origin then
		return
	end

	local exclude = options.Exclude
	local rayResult = self:RaycastGround(origin, options.RaycastDistance or 18, exclude)
	if not rayResult then
		return
	end

	local surfacePosition = rayResult.Position
	local color = options.Color or (options.UseGroundColor ~= false and rayResult.Instance and rayResult.Instance.Color) or DEFAULT_GROUND_COLOR
	local material = options.Material or (options.UseGroundColor ~= false and rayResult.Instance and rayResult.Instance.Material) or Enum.Material.Concrete
	local count = math.clamp(options.Count or 12, 1, 18)
	local minSize = options.MinSize or Vector3.new(0.35, 0.35, 0.35)
	local maxSize = options.MaxSize or Vector3.new(1.0, 1.0, 1.0)
	local minUpVelocity = options.MinUpVelocity or 38
	local maxUpVelocity = options.MaxUpVelocity or 62
	local outwardVelocity = options.OutwardVelocity or 20
	local angularVelocity = options.AngularVelocity or 8
	local lifetime = options.Lifetime or 1.35
	local trailLifetime = options.TrailLifetime or 0.22

	for index = 1, count do
		local angle = ((index - 1) / count) * math.pi * 2 + math.rad(randomBetween(-25, 25))
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = randomVector3(minSize, maxSize)
		local spawnPosition = surfacePosition + (direction * randomBetween(0.35, 1.6)) + Vector3.new(0, 0.35, 0)

		local rock = Instance.new("Part")
		rock.Name = "FlyRockDebris"
		rock.Anchored = false
		rock.CanCollide = false
		rock.CanTouch = false
		rock.CanQuery = false
		rock.Massless = true
		rock.CastShadow = false
		rock.Material = material
		rock.Color = color
		rock.Size = size
		rock.CFrame = CFrame.new(spawnPosition)
			* CFrame.Angles(
				math.rad(randomBetween(-30, 30)),
				math.rad(randomBetween(0, 360)),
				math.rad(randomBetween(-30, 30))
			)
		rock.Parent = self:GetRuntimeFolder()

		local topAttachment = Instance.new("Attachment")
		topAttachment.Position = Vector3.new(0, size.Y * 0.3, 0)
		topAttachment.Parent = rock

		local bottomAttachment = Instance.new("Attachment")
		bottomAttachment.Position = Vector3.new(0, -size.Y * 0.3, 0)
		bottomAttachment.Parent = rock

		local trail = Instance.new("Trail")
		trail.Name = "FlyRockTrail"
		trail.Attachment0 = topAttachment
		trail.Attachment1 = bottomAttachment
		trail.Lifetime = trailLifetime
		trail.LightEmission = 0.15
		trail.LightInfluence = 0.7
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Enabled = true
		trail.Parent = rock

		rock.AssemblyLinearVelocity = (direction * outwardVelocity * randomBetween(0.7, 1.25))
			+ Vector3.new(0, randomBetween(minUpVelocity, maxUpVelocity), 0)
		rock.AssemblyAngularVelocity = Vector3.new(
			randomBetween(-angularVelocity, angularVelocity),
			randomBetween(-angularVelocity * 1.25, angularVelocity * 1.25),
			randomBetween(-angularVelocity, angularVelocity)
		)

		task.delay(math.max(lifetime - 0.22, 0.05), function()
			if rock and rock.Parent then
				TweenService:Create(rock, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
					Size = rock.Size * 0.25,
				}):Play()
			end
		end)

		Debris:AddItem(rock, lifetime + 0.08)
	end
end

function DebrisVFXService:SpawnWallShatter(positionOrCFrame, normal, options)
	options = options or {}

	local origin = getPosition(positionOrCFrame)
	if not origin then
		return
	end

	local wallNormal = typeof(normal) == "Vector3" and normal.Magnitude > 0.05 and normal.Unit or Vector3.zAxis
	local scale = options.Scale or 3
	local crackColor = options.CrackColor or options.Color or Color3.fromRGB(220, 220, 230)
	local chunkColor = options.ChunkColor or options.Color or Color3.fromRGB(185, 185, 195)
	local material = options.Material or Enum.Material.Neon
	local lifetime = options.Lifetime or 1.8
	local removeTweenTime = options.RemoveTweenTime or 0.35
	local position = origin + wallNormal * (options.WallOffset or 0.18)

	local function createCrackSegment(startPoint, endPoint, thickness)
		local delta = endPoint - startPoint
		local length = delta.Magnitude
		if length <= 0.05 then
			return
		end

		local midpoint = (startPoint + endPoint) * 0.5
		local angle = math.atan2(delta.Y, delta.X)
		local cframe = getPlaneCFrame(position, wallNormal, angle) * CFrame.new(midpoint.X, midpoint.Y, 0)

		self:CreateDebrisPart(
			"WallShatterCrackDebris",
			Vector3.new(length, thickness, 0.035),
			cframe,
			crackColor,
			material,
			lifetime,
			removeTweenTime
		)
	end

	local branchCount = math.clamp(options.BranchCount or options.CrackCount or 7, 5, 8)
	for branchIndex = 1, branchCount do
		local angle = ((branchIndex - 1) / branchCount) * math.pi * 2 + math.rad(randomBetween(-20, 20))
		local totalLength = randomBetween(1.35, 3.15) * scale
		local segmentCount = math.random(1, 3)
		local cursor = Vector2.zero
		local thickness = randomBetween(0.035, 0.07) * math.max(scale * 0.45, 1)

		for segmentIndex = 1, segmentCount do
			local remainingSegments = segmentCount - segmentIndex + 1
			local remainingLength = totalLength - cursor.Magnitude
			local segmentLength = (remainingLength / remainingSegments) * randomBetween(0.78, 1.18)
			local direction = Vector2.new(math.cos(angle), math.sin(angle))
			local nextPoint = cursor + (direction * segmentLength)

			createCrackSegment(cursor, nextPoint, thickness * randomBetween(0.82, 1.08))

			cursor = nextPoint
			angle += math.rad(randomBetween(-18, 18))
		end

		if math.random() < 0.45 then
			local sideAngle = angle + math.rad((math.random() < 0.5 and -1 or 1) * randomBetween(32, 62))
			local sideLength = randomBetween(0.45, 0.95) * scale
			local sideEnd = cursor + Vector2.new(math.cos(sideAngle), math.sin(sideAngle)) * sideLength

			createCrackSegment(cursor, sideEnd, thickness * randomBetween(0.62, 0.82))
		end
	end

	local chunkCount = math.clamp(options.ChunkCount or 6, 0, 16)
	for _ = 1, chunkCount do
		local tangentAngle = math.rad(randomBetween(0, 360))
		local cframe = getPlaneCFrame(position + wallNormal * randomBetween(0.08, 0.22), wallNormal, tangentAngle)
			* CFrame.new(randomBetween(-2.2, 2.2) * scale, randomBetween(-1.8, 1.8) * scale, 0)
			* CFrame.Angles(math.rad(randomBetween(-25, 25)), math.rad(randomBetween(-25, 25)), math.rad(randomBetween(-25, 25)))

		self:CreateDebrisPart(
			"WallShatterChunkDebris",
			randomVector3(
				options.MinChunkSize or Vector3.new(0.25, 0.18, 0.08) * scale,
				options.MaxChunkSize or Vector3.new(0.75, 0.45, 0.2) * scale
			),
			cframe,
			chunkColor,
			Enum.Material.Concrete,
			lifetime * randomBetween(0.8, 1.15),
			removeTweenTime
		)
	end
end

function DebrisVFXService:SpawnWallImpact(positionOrCFrame, normal, options)
	return self:SpawnWallShatter(positionOrCFrame, normal, options)
end

function DebrisVFXService:GetTrailWorldPositions(character, attachmentsOrOffsets)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return {}
	end

	local points = {}
	local sources = attachmentsOrOffsets or {
		Vector3.new(-2.2, -2.6, 1.5),
		Vector3.new(2.2, -2.6, 1.5),
	}

	for _, source in ipairs(sources) do
		if typeof(source) == "Instance" and source:IsA("Attachment") then
			table.insert(points, source.WorldPosition)
		elseif typeof(source) == "Vector3" then
			table.insert(points, root.CFrame:PointToWorldSpace(source))
		end
	end

	return points
end

function DebrisVFXService:SpawnDivotChunk(position, options, exclude)
	local rayResult = self:RaycastGround(position, options.RaycastDistance or 8, exclude)
	if not rayResult then
		return
	end

	local basePosition = rayResult.Position + Vector3.new(
		randomBetween(-(options.ScatterRadius or 0.7), options.ScatterRadius or 0.7),
		0.06,
		randomBetween(-(options.ScatterRadius or 0.7), options.ScatterRadius or 0.7)
	)

	local color = options.Color
	if color == nil and options.UseGroundColor ~= false and rayResult.Instance then
		color = rayResult.Instance.Color
	end

	local material = options.Material
	if material == nil and options.UseGroundColor ~= false and rayResult.Instance then
		material = rayResult.Instance.Material
	end

	self:CreateDebrisPart(
		"DivotDebris",
		randomVector3(
			options.MinSize or Vector3.new(0.5, 0.25, 0.5),
			options.MaxSize or Vector3.new(1.1, 0.45, 1.1)
		),
		CFrame.new(basePosition)
			* CFrame.Angles(
				math.rad(randomBetween(-12, 12)),
				math.rad(randomBetween(0, 360)),
				math.rad(randomBetween(-12, 12))
			),
		color or DEFAULT_GROUND_COLOR,
		material or Enum.Material.Concrete,
		options.Lifetime or 1.4,
		options.RemoveTweenTime or 0.3,
		{
			SinkDistance = options.SinkDistance or 0.22,
		}
	)
end

function DebrisVFXService:SpawnTrailChunk(position, options, exclude)
	return self:SpawnDivotChunk(position, options, exclude)
end

function DebrisVFXService:StartDivotTrail(character, attachmentsOrOffsets, options)
	options = options or {}

	local handle = {
		Active = true,
		Connections = {},
		LastSpawnPositionByPoint = {},
	}

	local function stop()
		self:StopDivotTrail(handle)
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(handle.Connections, humanoid.Died:Connect(stop))
	end

	if character then
		table.insert(handle.Connections, character.AncestryChanged:Connect(function(_, parent)
			if not parent then
				stop()
			end
		end))
	end

	task.spawn(function()
		local tickRate = math.max(options.TickRate or 0.035, 0.02)
		local minDistance = math.max(options.MinDistanceBetweenSpawns or 1.8, 0)
		local spawnPerPoint = math.clamp(options.SpawnPerPoint or options.SpawnPerSide or 1, 1, 4)
		local exclude = options.Exclude or character

		while handle.Active do
			if not character or not character.Parent then
				break
			end

			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if not currentHumanoid or currentHumanoid.Health <= 0 then
				break
			end

			for index, position in ipairs(self:GetTrailWorldPositions(character, attachmentsOrOffsets)) do
				local lastPosition = handle.LastSpawnPositionByPoint[index]
				local shouldSpawn = lastPosition == nil
					or minDistance <= 0
					or (position - lastPosition).Magnitude >= minDistance

				if shouldSpawn then
					handle.LastSpawnPositionByPoint[index] = position

					for _ = 1, spawnPerPoint do
						self:SpawnDivotChunk(position, options, exclude)
					end
				end
			end

			task.wait(tickRate)
		end

		stop()
	end)

	return handle
end

function DebrisVFXService:StopDivotTrail(handle)
	if not handle or handle.Active == false then
		return
	end

	handle.Active = false

	for _, connection in ipairs(handle.Connections or {}) do
		connection:Disconnect()
	end

	table.clear(handle.Connections or {})
end

function DebrisVFXService:StartDebrisTrail(character, attachmentsOrOffsets, options)
	return self:StartDivotTrail(character, attachmentsOrOffsets, options)
end

function DebrisVFXService:StopDebrisTrail(handle)
	return self:StopDivotTrail(handle)
end

return DebrisVFXService
