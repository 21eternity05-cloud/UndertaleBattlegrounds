--!strict
-- HollowSnowdinLighting.server.lua
-- Location:
-- src/ServerScriptService/HollowSnowdinLighting.server.lua
--
-- Purpose:
-- Sets the global Hollow Snowdin lighting mood.
--
-- Goal:
-- - eerie / empty / cold, but NOT pitch-black horror
-- - neon attacks should pop more
-- - map should still be readable for PvP
-- - bloom should make bones, slashes, souls, blasters, and neon VFX feel brighter

local Lighting = game:GetService("Lighting")

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
-- BASE LIGHTING
--============================================================
-- Use late evening instead of night.
-- 16.5 - 17.5 gives a cold dusk look without making the arena unreadable.
Lighting.ClockTime = 17.15

-- Higher brightness + slight exposure helps neon/VFX actually stand out.
Lighting.Brightness = 2.8
Lighting.ExposureCompensation = 0.12

-- Cold blue-gray ambience. Still bright enough for combat readability.
Lighting.Ambient = Color3.fromRGB(75, 86, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(115, 130, 160)

-- Cool sky/top lighting, dark lower bounce.
Lighting.ColorShift_Top = Color3.fromRGB(145, 175, 220)
Lighting.ColorShift_Bottom = Color3.fromRGB(45, 52, 70)

-- Keeps things from looking too flat, but not hyper-realistic.
Lighting.EnvironmentDiffuseScale = 0.45
Lighting.EnvironmentSpecularScale = 0.65

Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.45

-- Future lighting makes neon/bloom look better, but pcall keeps script safe
-- if Roblox changes available Technology values.
pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

--============================================================
-- ATMOSPHERE
--============================================================
-- Foggy and empty, but not so dense that attacks disappear.
local atmosphere = getOrCreate("Atmosphere", "HollowSnowdinAtmosphere") :: Atmosphere

atmosphere.Density = 0.24
atmosphere.Offset = -0.05
atmosphere.Color = Color3.fromRGB(185, 205, 235)
atmosphere.Decay = Color3.fromRGB(75, 90, 125)
atmosphere.Glare = 0.12
atmosphere.Haze = 1.15

--============================================================
-- COLOR CORRECTION
--============================================================
-- Slightly cinematic/cold.
-- Do not over-desaturate or red/blue attacks will stop popping.
local colorCorrection = getOrCreate("ColorCorrectionEffect", "HollowSnowdinColorCorrection") :: ColorCorrectionEffect

colorCorrection.Brightness = 0.02
colorCorrection.Contrast = 0.18
colorCorrection.Saturation = -0.06
colorCorrection.TintColor = Color3.fromRGB(220, 232, 255)

--============================================================
-- BLOOM
--============================================================
-- This is the main "make Neon pop" effect.
-- Higher Intensity + lower Threshold means more neon glow.
local bloom = getOrCreate("BloomEffect", "HollowSnowdinBloom") :: BloomEffect

bloom.Intensity = 1.15
bloom.Size = 36
bloom.Threshold = 0.78

--============================================================
-- DEPTH OF FIELD
--============================================================
-- Very subtle. Strong DOF is bad for battleground combat.
local depthOfField = getOrCreate("DepthOfFieldEffect", "HollowSnowdinDepthOfField") :: DepthOfFieldEffect

depthOfField.Enabled = true
depthOfField.FarIntensity = 0.05
depthOfField.NearIntensity = 0
depthOfField.FocusDistance = 120
depthOfField.InFocusRadius = 90

--============================================================
-- OPTIONAL SUN RAYS
--============================================================
-- Very low. Just gives the sky a little atmosphere.
local sunRays = getOrCreate("SunRaysEffect", "HollowSnowdinSunRays") :: SunRaysEffect

sunRays.Intensity = 0.025
sunRays.Spread = 0.65

print("[HollowSnowdinLighting] Applied Hollow Snowdin lighting preset.")