local DisbeliefPapyrusVFX = {}
DisbeliefPapyrusVFX.__index = DisbeliefPapyrusVFX

function DisbeliefPapyrusVFX.new(config, vfxService)
	local self = setmetatable({}, DisbeliefPapyrusVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

return DisbeliefPapyrusVFX
