local Debris = game:GetService("Debris")

local TorielVFX = {}
TorielVFX.__index = TorielVFX

function TorielVFX.new(config, vfxService)
	local self = setmetatable({}, TorielVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

function TorielVFX:MakeFireFlash(position, size, lifetime)
	local part = Instance.new("Part")
	part.Name = "TorielFirePlaceholder"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 98, 35)
	part.Transparency = 0.35
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(position)
	part.Parent = workspace

	Debris:AddItem(part, lifetime or 0.25)
end

function TorielVFX:PlayM1(character, combo, targetCharacter, targetRoot, didHit)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	self:MakeFireFlash(root.Position + root.CFrame.LookVector * 3, 2.5, 0.18)

	if didHit and targetRoot then
		self:MakeFireFlash(targetRoot.Position, 3, 0.2)
	end
end

function TorielVFX:PlayMove(character, moveName, targetCharacter, targetRoot)
	local root = targetRoot or (character and character:FindFirstChild("HumanoidRootPart"))
	if not root then return end

	local size = 4

	if moveName == "FlamePillar" then
		size = 8
	elseif moveName == "RoyalPyre" then
		size = 18
	elseif moveName == "GuardianBreak" then
		size = 6
	end

	self:MakeFireFlash(root.Position, size, 0.3)
end

return TorielVFX
