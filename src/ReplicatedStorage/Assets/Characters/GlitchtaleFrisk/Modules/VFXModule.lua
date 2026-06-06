local GlitchtaleFriskVFX = {}
GlitchtaleFriskVFX.__index = GlitchtaleFriskVFX

function GlitchtaleFriskVFX.new(config, vfxService)
	local self = setmetatable({}, GlitchtaleFriskVFX)

	self.Config = config
	self.VFXService = vfxService

	return self
end

return GlitchtaleFriskVFX
