local RunService = game:GetService("RunService")

local CameraShake = {}

local activeOnce = {}
local sustained = {}
local bound = false

local function ensureConnection()
	if bound then return end

	bound = true

	RunService:BindToRenderStep("UTBGCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if not camera then return end

		local now = os.clock()
		local offset = Vector3.zero
		local rotation = Vector3.zero

		for index = #activeOnce, 1, -1 do
			local shake = activeOnce[index]
			local alpha = math.clamp((now - shake.StartTime) / shake.Duration, 0, 1)

			if alpha >= 1 then
				table.remove(activeOnce, index)
			else
				local fade = 1 - alpha
				local noiseTime = now * shake.Roughness
				local strength = shake.Intensity * fade

				offset += Vector3.new(
					math.noise(noiseTime, 1, 0),
					math.noise(1, noiseTime, 0),
					0
				) * strength * 0.18

				rotation += Vector3.new(
					math.noise(noiseTime, 2, 0),
					math.noise(2, noiseTime, 0),
					math.noise(3, noiseTime, 0)
				) * strength * 0.012
			end
		end

		for _, shake in pairs(sustained) do
			local noiseTime = now * shake.Roughness
			local strength = shake.Intensity

			offset += Vector3.new(
				math.noise(noiseTime, 4, 0),
				math.noise(4, noiseTime, 0),
				0
			) * strength * 0.12

			rotation += Vector3.new(
				math.noise(noiseTime, 5, 0),
				math.noise(5, noiseTime, 0),
				math.noise(6, noiseTime, 0)
			) * strength * 0.008
		end

		if offset.Magnitude > 0 or rotation.Magnitude > 0 then
			camera.CFrame = camera.CFrame
				* CFrame.new(offset)
				* CFrame.Angles(rotation.X, rotation.Y, rotation.Z)
		end

		if #activeOnce <= 0 and next(sustained) == nil then
			RunService:UnbindFromRenderStep("UTBGCameraShake")
			bound = false
		end
	end)
end

function CameraShake:ShakeOnce(intensity, roughness, duration)
	table.insert(activeOnce, {
		Intensity = intensity or 1,
		Roughness = roughness or 8,
		Duration = math.max(duration or 0.25, 0.03),
		StartTime = os.clock(),
	})

	ensureConnection()
end

function CameraShake:ShakeSustain(id, intensity, roughness)
	if not id then return end

	sustained[id] = {
		Intensity = intensity or 1,
		Roughness = roughness or 8,
	}

	ensureConnection()
end

function CameraShake:StopSustain(id)
	if not id then return end
	sustained[id] = nil
end

function CameraShake:StopAll()
	table.clear(activeOnce)
	table.clear(sustained)
end

return CameraShake
