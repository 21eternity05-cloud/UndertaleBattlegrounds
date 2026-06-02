local Players = game:GetService("Players")

local DebugService = {}
DebugService.__index = DebugService

function DebugService.new(config)
	local self = setmetatable({}, DebugService)

	self.Config = config
	self.Enabled = false
	self.TouchDebounce = {}

	return self
end

function DebugService:SetEnabled(enabled)
	self.Enabled = enabled == true

	self.Config.DebugEnabled = self.Enabled
	self.Config.DebugHitboxes = self.Enabled

	workspace:SetAttribute("DebugEnabled", self.Enabled)

	print("[DebugService] Debug enabled:", self.Enabled)
end

function DebugService:Toggle()
	self:SetEnabled(not self.Enabled)
end

function DebugService:Start()
	local button = workspace:FindFirstChild("DEBUG_BUTTON")

	if not button or not button:IsA("BasePart") then
		warn("[DebugService] Missing workspace.DEBUG_BUTTON")
		return
	end

	button.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local now = os.clock()
		local lastTouch = self.TouchDebounce[player] or 0

		if now - lastTouch < 1.5 then
			return
		end

		self.TouchDebounce[player] = now

		self:Toggle()
	end)
end

return DebugService
