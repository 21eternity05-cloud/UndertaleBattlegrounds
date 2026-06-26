local Debris = game:GetService("Debris")

local MoveHelperUtil = {}

function MoveHelperUtil.GetHumanoidAndRoot(character)
	if not character or not character.Parent then
		return nil, nil
	end

	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

function MoveHelperUtil.GetRoot(character)
	local _, root = MoveHelperUtil.GetHumanoidAndRoot(character)
	return root
end

function MoveHelperUtil.BuildSphereHitbox(radius, offset)
	return {
		Radius = radius,
		Offset = offset or CFrame.new(),
	}
end

function MoveHelperUtil.CloneData(source, overrides)
	local data = {}

	for key, value in pairs(source or {}) do
		data[key] = value
	end

	for key, value in pairs(overrides or {}) do
		data[key] = value
	end

	return data
end

function MoveHelperUtil.SafeDisconnect(connection)
	if connection and connection.Disconnect then
		connection:Disconnect()
	end
end

function MoveHelperUtil.SafeDestroy(instance)
	if instance and instance.Parent then
		instance:Destroy()
	end
end

function MoveHelperUtil.SafeCleanup(items)
	for _, item in ipairs(items or {}) do
		if typeof(item) == "RBXScriptConnection" then
			MoveHelperUtil.SafeDisconnect(item)
		elseif typeof(item) == "Instance" then
			MoveHelperUtil.SafeDestroy(item)
		elseif typeof(item) == "function" then
			pcall(item)
		end
	end
end

function MoveHelperUtil.CleanupAfter(seconds, items)
	task.delay(seconds or 0, function()
		MoveHelperUtil.SafeCleanup(items)
	end)
end

function MoveHelperUtil.AddDebris(instance, lifetime)
	if instance and lifetime then
		Debris:AddItem(instance, lifetime)
	end

	return instance
end

function MoveHelperUtil.SafeStopTrack(track, fadeTime)
	if not track then
		return
	end

	pcall(function()
		track:Stop(fadeTime or 0.05)
	end)
end

function MoveHelperUtil.ConnectMarker(track, markerName, callback)
	if not track or typeof(markerName) ~= "string" or markerName == "" then
		return nil
	end

	return track:GetMarkerReachedSignal(markerName):Connect(callback)
end

function MoveHelperUtil.ZeroVelocity(root)
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function MoveHelperUtil.SetTemporaryAttribute(instance, attributeName, value, duration)
	if not instance or not instance.Parent then
		return
	end

	local previousValue = instance:GetAttribute(attributeName)
	instance:SetAttribute(attributeName, value)

	task.delay(duration or 0, function()
		if instance and instance.Parent and instance:GetAttribute(attributeName) == value then
			instance:SetAttribute(attributeName, previousValue)
		end
	end)
end

return MoveHelperUtil
