local Workspace = game:GetService("Workspace")

local ShopPreviewController = {}
ShopPreviewController.__index = ShopPreviewController

local SHOP_FOLDER_NAME = "SHOP"
local SHOP_PLACEHOLDER_NAME = "Placeholder"
local PREVIEW_FOLDER_NAME = "ClientShopPreviews"
local PREVIEW_NAME_PREFIX = "ClientShopPreview_"

function ShopPreviewController.new(player, replicatedStorage)
	local self = setmetatable({}, ShopPreviewController)

	self.Player = player
	self.ReplicatedStorage = replicatedStorage
	self.ShopLocationRemote = nil
	self.ActivePreviewModel = nil
	self.OldCameraType = nil
	self.OldCameraSubject = nil
	self.OldCameraCFrame = nil
	self.CameraHoldCharacter = nil
	self.ShopCameraCFrame = nil
	self.LastCharacterName = nil
	self.LastShopPosition = nil

	return self
end

function ShopPreviewController:GetShopLocationRemote()
	if self.ShopLocationRemote then
		return self.ShopLocationRemote
	end

	local remotes = self.ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("ShopLocationRemote")

	if remote and remote:IsA("RemoteFunction") then
		self.ShopLocationRemote = remote
		return remote
	end

	return nil
end

function ShopPreviewController:GetServerShopLocation()
	local remote = self:GetShopLocationRemote()
	if not remote then
		return nil
	end

	local success, result = pcall(function()
		return remote:InvokeServer()
	end)

	if not success or typeof(result) ~= "table" or result.Exists ~= true then
		return nil
	end

	if typeof(result.PlaceholderPosition) == "Vector3" then
		self.LastShopPosition = result.PlaceholderPosition
		return result.PlaceholderPosition, result.PlaceholderCFrame
	end

	if typeof(result.PlaceholderCFrame) == "CFrame" then
		self.LastShopPosition = result.PlaceholderCFrame.Position
		return result.PlaceholderCFrame.Position, result.PlaceholderCFrame
	end

	return nil
end

function ShopPreviewController:RequestStreamAround(position)
	if typeof(position) ~= "Vector3" then
		return
	end

	self.LastShopPosition = position

	task.spawn(function()
		pcall(function()
			self.Player:RequestStreamAroundAsync(position, 3)
		end)
	end)
end

function ShopPreviewController:RequestShopStream()
	local position = self.LastShopPosition

	if not position then
		position = self:GetServerShopLocation()
	end

	if position then
		self:RequestStreamAround(position)
	end
end

function ShopPreviewController:Start()
	task.defer(function()
		self:RequestShopStream()
	end)
end

function ShopPreviewController:GetCurrentHumanoid()
	local character = self.Player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function ShopPreviewController:RestoreCameraToPlayer()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Custom

	local humanoid = self:GetCurrentHumanoid()
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function ShopPreviewController:GetShopFolder()
	local shopFolder = Workspace:FindFirstChild(SHOP_FOLDER_NAME)

	if not shopFolder then
		warn("[ShopPreviewController] Missing workspace.SHOP folder")
		return nil
	end

	return shopFolder
end

function ShopPreviewController:GetShopPlaceholder()
	local shopFolder = self:GetShopFolder()
	if not shopFolder then
		self:RequestShopStream()
		return nil
	end

	local placeholder = shopFolder:FindFirstChild(SHOP_PLACEHOLDER_NAME)

	if not placeholder or not placeholder:IsA("BasePart") then
		self:RequestShopStream()
		placeholder = shopFolder:WaitForChild(SHOP_PLACEHOLDER_NAME, 5)

		if not placeholder or not placeholder:IsA("BasePart") then
			warn("[ShopPreviewController] Missing workspace.SHOP.Placeholder part")
			return nil
		end
	end

	self.LastShopPosition = placeholder.Position

	return placeholder
end

function ShopPreviewController:GetPreviewFolder()
	local folder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PREVIEW_FOLDER_NAME
		folder.Parent = Workspace
	elseif not folder:IsA("Folder") then
		warn("[ShopPreviewController] Refused to use non-folder preview object:", folder:GetFullName())
		return nil
	end

	return folder
end

function ShopPreviewController:GetCharacterModel(characterName)
	local assets = self.ReplicatedStorage:FindFirstChild("Assets")
	local characters = assets and assets:FindFirstChild("Characters")
	local characterFolder = characters and characters:FindFirstChild(characterName)

	if not characterFolder then
		return nil
	end

	local characterModelFolder = characterFolder:FindFirstChild("CharacterModel")

	if characterModelFolder then
		if characterModelFolder:IsA("Model") then
			return characterModelFolder
		end

		if characterModelFolder:IsA("Folder") then
			local namedModel = characterModelFolder:FindFirstChild(characterName)

			if namedModel and namedModel:IsA("Model") then
				return namedModel
			end

			local firstModel = characterModelFolder:FindFirstChildWhichIsA("Model")

			if firstModel then
				return firstModel
			end
		end
	end

	for _, modelName in ipairs({ "Model", "Rig", "ViewportModel" }) do
		local model = characterFolder:FindFirstChild(modelName)

		if model and model:IsA("Model") then
			return model
		end
	end

	return nil
end

function ShopPreviewController:MakePreviewModelSafe(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
end

function ShopPreviewController:DestroyActivePreview()
	local model = self.ActivePreviewModel
	self.ActivePreviewModel = nil

	if not model or not model.Parent then
		return
	end

	if model.Name:match("^" .. PREVIEW_NAME_PREFIX) then
		model:Destroy()
	else
		warn("[ShopPreviewController] Refused to destroy unsafe preview object:", model:GetFullName())
	end
end

function ShopPreviewController:SetupPreviewModel(characterName)
	self:DestroyActivePreview()

	local placeholder = self:GetShopPlaceholder()
	if not placeholder then
		return
	end

	local previewFolder = self:GetPreviewFolder()
	if not previewFolder then
		return
	end

	local sourceModel = self:GetCharacterModel(characterName)
	local previewCFrame = placeholder.CFrame * CFrame.Angles(0, math.rad(180), 0)

	if sourceModel then
		local clone = sourceModel:Clone()
		clone.Name = PREVIEW_NAME_PREFIX .. characterName
		self:MakePreviewModelSafe(clone)
		clone.Parent = previewFolder
		clone:PivotTo(previewCFrame)
		self.ActivePreviewModel = clone
	else
		local fallback = Instance.new("Model")
		fallback.Name = PREVIEW_NAME_PREFIX .. characterName

		local body = Instance.new("Part")
		body.Name = "PreviewPlaceholderBody"
		body.Anchored = true
		body.CanCollide = false
		body.CanTouch = false
		body.CanQuery = false
		body.Size = Vector3.new(3, 5, 1)
		body.Color = Color3.fromRGB(120, 120, 140)
		body.CFrame = previewCFrame + Vector3.new(0, 2.5, 0)
		body.Parent = fallback

		fallback.PrimaryPart = body
		fallback.Parent = previewFolder
		self.ActivePreviewModel = fallback
	end
end

function ShopPreviewController:Enter(characterName)
	self.LastCharacterName = characterName
	self:RequestShopStream()

	local camera = Workspace.CurrentCamera
	local placeholder = self:GetShopPlaceholder()

	if not camera or not placeholder then
		return
	end

	if self.OldCameraType == nil then
		self.OldCameraType = camera.CameraType
		self.OldCameraSubject = camera.CameraSubject
		self.OldCameraCFrame = camera.CFrame
		self.CameraHoldCharacter = self.Player.Character
	end

	self:SetupPreviewModel(characterName)

	local focusPosition = placeholder.Position + Vector3.new(0, 2.8, 0)
	local cameraPosition = (placeholder.CFrame * CFrame.new(0, 3.2, 11)).Position
	local shopCameraCFrame = CFrame.lookAt(cameraPosition, focusPosition)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = shopCameraCFrame
	self.ShopCameraCFrame = shopCameraCFrame
end

function ShopPreviewController:Exit()
	local camera = Workspace.CurrentCamera

	self:DestroyActivePreview()

	if not camera then
		return
	end

	if self.OldCameraType ~= nil then
		local characterChanged = self.CameraHoldCharacter ~= nil and self.CameraHoldCharacter ~= self.Player.Character
		local subjectInvalid = self.OldCameraSubject == nil or self.OldCameraSubject.Parent == nil
		local oldHumanoid = self.OldCameraSubject and self.OldCameraSubject:IsA("Humanoid") and self.OldCameraSubject or nil
		local oldHumanoidDead = oldHumanoid and oldHumanoid.Health <= 0

		if characterChanged or subjectInvalid or oldHumanoidDead then
			self:RestoreCameraToPlayer()
		else
			camera.CameraType = self.OldCameraType
			camera.CameraSubject = self.OldCameraSubject

			if self.OldCameraType ~= Enum.CameraType.Custom and self.OldCameraCFrame then
				camera.CFrame = self.OldCameraCFrame
			end
		end
	else
		self:RestoreCameraToPlayer()
	end

	self.OldCameraType = nil
	self.OldCameraSubject = nil
	self.OldCameraCFrame = nil
	self.CameraHoldCharacter = nil
	self.ShopCameraCFrame = nil
end

function ShopPreviewController:HandleCharacterRespawnedDuringCustomize(character)
	task.wait(0.2)

	if not self.ShopCameraCFrame and self.LastCharacterName then
		self:Enter(self.LastCharacterName)
	end

	local function reapplyShopCamera()
		local camera = Workspace.CurrentCamera

		if camera and self.ShopCameraCFrame then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = self.ShopCameraCFrame
		end
	end

	reapplyShopCamera()

	if self.OldCameraType ~= nil then
		self.OldCameraType = Enum.CameraType.Custom
		self.OldCameraSubject = self:GetCurrentHumanoid()
		self.OldCameraCFrame = nil
		self.CameraHoldCharacter = character
	end

	task.delay(0.5, reapplyShopCamera)
end

return ShopPreviewController
