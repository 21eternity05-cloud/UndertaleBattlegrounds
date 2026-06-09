--!strict
-- HollowSnowdinLighting.server.lua
-- Location:
-- src/ServerScriptService/World/HollowSnowdinLighting.server.lua
--
-- Purpose:
-- Global Hollow Snowdin lighting preset.
--
-- Direction:
-- - eerie and empty, but NOT horror-night dark
-- - cold Undertale arena feeling
-- - no visible sun/moon feeling
-- - neon should pop, but not blind the whole screen
-- - use classic Lighting fog instead of Atmosphere

local Lighting = game:GetService("Lighting")

local function destroyIfExists(name: string)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local function getOrCreate(className: string, name: string)
	local existing = Lighting:FindFirstChild(name)

	if existing and existing.ClassName == className then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local object = Instance.new(className)
	object.Name = name
	object.Parent = Lighting

	return object
end

--============================================================
-- REMOVE EFFECTS WE DO NOT WANT
--============================================================

-- Atmosphere looked bad for this map, so force-remove it.
destroyIfExists("HollowSnowdinAtmosphere")

-- No sun/moon ray feeling in Hollow Snowdin.
destroyIfExists("HollowSnowdinSunRays")

--============================================================
-- BASE LIGHTING
--============================================================
-- Use a bright overcast dusk/day value, not night.
-- This keeps the arena readable but still cold/empty.
Lighting.ClockTime = 14.25

Lighting.Brightness = 2.6
Lighting.ExposureCompensation = 0.05

-- Cold ambient light. This is the main "there is no real sun" feeling.
Lighting.Ambient = Color3.fromRGB(82, 92, 115)
Lighting.OutdoorAmbient = Color3.fromRGB(125, 140, 165)

-- Slight cold top color, muted bottom.
Lighting.ColorShift_Top = Color3.fromRGB(140, 165, 205)
Lighting.ColorShift_Bottom = Color3.fromRGB(55, 62, 80)

Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.55

Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.55

pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

--============================================================
-- CLASSIC LIGHTING FOG
--============================================================
-- This replaces Atmosphere.
-- FogStart/FogEnd are easier to control for arena readability.
Lighting.FogColor = Color3.fromRGB(165, 180, 205)
Lighting.FogStart = 95
Lighting.FogEnd = 520

-- If you want heavier fog later:
-- FogStart = 65
-- FogEnd = 380
--
-- If combat feels too foggy:
-- FogStart = 140
-- FogEnd = 700

--============================================================
-- COLOR CORRECTION
--============================================================
-- Slight cold cinematic correction.
-- Keep saturation close to normal so red/blue attacks do not die.
local colorCorrection = getOrCreate("ColorCorrectionEffect", "HollowSnowdinColorCorrection") :: ColorCorrectionEffect

colorCorrection.Brightness = 0.01
colorCorrection.Contrast = 0.14
colorCorrection.Saturation = -0.03
colorCorrection.TintColor = Color3.fromRGB(222, 234, 255)

--============================================================
-- BLOOM
--============================================================
-- Neon was too bright before, so this is toned down.
-- Still enough to make Neon readable and more premium.
local bloom = getOrCreate("BloomEffect", "HollowSnowdinBloom") :: BloomEffect

bloom.Intensity = 0.55
bloom.Size = 22
bloom.Threshold = 1.1

-- More neon pop:
-- bloom.Intensity = 0.95
-- bloom.Size = 32
-- bloom.Threshold = 0.85
--
-- Less neon glow:
-- bloom.Intensity = 0.55
-- bloom.Size = 22
-- bloom.Threshold = 1.1

--============================================================
-- DEPTH OF FIELD
--============================================================
-- Keep this almost invisible for combat readability.
local depthOfField = getOrCreate("DepthOfFieldEffect", "HollowSnowdinDepthOfField") :: DepthOfFieldEffect

depthOfField.Enabled = true
depthOfField.FarIntensity = 0.025
depthOfField.NearIntensity = 0
depthOfField.FocusDistance = 130
depthOfField.InFocusRadius = 110

print("[HollowSnowdinLighting] Applied classic fog Hollow Snowdin lighting preset.")