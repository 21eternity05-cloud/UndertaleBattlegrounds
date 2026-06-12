print("[CombatServer] Starting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatFolder = script.Parent
local servicesFolder = script.Parent.Parent:WaitForChild("Services")

local Config = require(combatFolder:WaitForChild("CombatConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")

-- Core services
local AnimationService = require(combatFolder:WaitForChild("AnimationService")).new(Config)
local VFXService = require(combatFolder:WaitForChild("VFXService")).new(Config)
local StateService = require(combatFolder:WaitForChild("StateService")).new(Config, AnimationService, VFXService)
local HitboxService = require(combatFolder:WaitForChild("HitboxService")).new(Config)
local MovementService = require(combatFolder:WaitForChild("MovementService")).new(Config)
local BlockService = require(combatFolder:WaitForChild("BlockService")).new(Config, StateService, VFXService)
local WeaponService = require(combatFolder:WaitForChild("WeaponService")).new(Config)
local DamageNumberService = require(combatFolder:WaitForChild("DamageNumberService")).new(Config)
local CharacterMorphService = require(combatFolder:WaitForChild("CharacterMorphService")).new(Config)

-- Player / progression services
local ProgressionService = require(combatFolder:WaitForChild("ProgressionService")).new(Config)
_G.UTBGProgressionService = ProgressionService
local CharacterService = require(combatFolder:WaitForChild("CharacterService")).new(
	Config,
	WeaponService,
	ProgressionService,
	CharacterMorphService
)
local UltService = require(combatFolder:WaitForChild("UltService")).new(Config)
local AwakeningMusicService = require(combatFolder:WaitForChild("AwakeningMusicService")).new(Config)

-- Status / utility services
local CombatStatusService = require(combatFolder:WaitForChild("CombatStatusService")).new(Config)
local CinematicService = require(combatFolder:WaitForChild("CinematicService")).new(Config)
local CharacterIntroService = require(combatFolder:WaitForChild("CharacterIntroService")).new(
	Config,
	AnimationService,
	VFXService,
	CinematicService,
	CharacterMorphService
)
local LoreCinematicService = require(combatFolder:WaitForChild("LoreCinematicService")).new(Config, ProgressionService)
local ShopLocationService = require(combatFolder:WaitForChild("ShopLocationService")).new(Config)
local DebugService = require(combatFolder:WaitForChild("DebugService")).new(Config)
local SpawnService = require(combatFolder:WaitForChild("SpawnService")).new(
	Config,
	StateService,
	CombatStatusService
)
local EmoteService = require(servicesFolder:WaitForChild("EmoteService")).new(Config, StateService)

local CounterService = require(combatFolder:WaitForChild("CounterService")).new(
	Config,
	StateService,
	MovementService,
	VFXService
)

local ProjectileService = require(combatFolder:WaitForChild("ProjectileService")).new(
	Config,
	HitboxService,
	BlockService,
	StateService,
	VFXService,
	CounterService,
	CombatStatusService,
	MovementService,
	DamageNumberService,
	ProgressionService
)

local M1Service = require(combatFolder:WaitForChild("M1Service")).new(
	Config,
	StateService,
	HitboxService,
	MovementService,
	BlockService,
	VFXService,
	CounterService,
	CombatStatusService
)

local MoveService = require(combatFolder:WaitForChild("MoveService")).new(
	Config,
	StateService,
	HitboxService,
	MovementService,
	BlockService,
	VFXService,
	CounterService,
	CombatStatusService
)

local GrabService = require(combatFolder:WaitForChild("GrabService")).new(
	Config,
	StateService,
	MovementService,
	CombatStatusService,
	DamageNumberService,
	ProgressionService
)

local SoulBurstService = require(combatFolder:WaitForChild("SoulBurstService")).new(
	Config,
	StateService,
	CombatStatusService,
	MovementService,
	HitboxService,
	VFXService,
	CounterService,
	UltService,
	GrabService,
	CinematicService
)

local KillCreditService = require(combatFolder:WaitForChild("KillCreditService")).new(
	Config,
	ProgressionService,
	CombatStatusService
)

-- Cross-service wiring
StateService.CounterService = CounterService
StateService.CombatStatusService = CombatStatusService
StateService.ProjectileService = ProjectileService
StateService.UltService = UltService
StateService.CinematicService = CinematicService
StateService.SoulBurstService = SoulBurstService
StateService.SpawnService = SpawnService
StateService.KillCreditService = KillCreditService
CombatStatusService.KillCreditService = KillCreditService
CharacterService.CombatStatusService = CombatStatusService
CharacterService.SpawnService = SpawnService
CharacterService.CharacterIntroService = CharacterIntroService
BlockService.SpawnService = SpawnService

M1Service.UltService = UltService
M1Service.DamageNumberService = DamageNumberService
M1Service.SoulBurstService = SoulBurstService
M1Service.SpawnService = SpawnService
M1Service.KillCreditService = KillCreditService
M1Service.CinematicService = CinematicService

MoveService.ProjectileService = ProjectileService
MoveService.UltService = UltService
MoveService.CinematicService = CinematicService
MoveService.AwakeningMusicService = AwakeningMusicService
MoveService.DamageNumberService = DamageNumberService
MoveService.ProgressionService = ProgressionService
MoveService.GrabService = GrabService
MoveService.SoulBurstService = SoulBurstService
MoveService.SpawnService = SpawnService
MoveService.KillCreditService = KillCreditService

ProjectileService.UltService = UltService
ProjectileService.DamageNumberService = DamageNumberService
ProjectileService.ProgressionService = ProgressionService
ProjectileService.SoulBurstService = SoulBurstService
ProjectileService.KillCreditService = KillCreditService

CounterService.UltService = UltService
UltService.ProgressionService = ProgressionService
UltService.KillCreditService = KillCreditService
DebugService.SoulBurstService = SoulBurstService

-- Remotes
combatRemote.OnServerEvent:Connect(function(player, action, payload)
	local character = player.Character
	if character and character:GetAttribute("Emoting") == true then
		EmoteService:CancelEmote(player)
		return
	end

	if action == "M1" then
		M1Service:PerformM1(player, payload)
	elseif action == "BlockStart" then
		BlockService:SetBlocking(player, true)
	elseif action == "BlockEnd" then
		BlockService:SetBlocking(player, false)
	end
end)

moveRemote.OnServerEvent:Connect(function(player, moveRequest)
	local character = player.Character
	if character and character:GetAttribute("Emoting") == true then
		EmoteService:CancelEmote(player)
		return
	end

	MoveService:PerformMove(player, moveRequest)
end)

SoulBurstService.SoulBurstRemote.OnServerEvent:Connect(function(player, action)
	local character = player.Character
	if character and character:GetAttribute("Emoting") == true then
		EmoteService:CancelEmote(player)
		return
	end

	if action == "Activate" then
		SoulBurstService:ActivateSoulBurst(player)
	end
end)

local function parseCharacterRequest(action, payload)
	if action == "SelectCharacter" and typeof(payload) == "string" then
		return payload, nil
	end

	if (action == "PlayAsCharacter" or action == "SelectCharacter") and typeof(payload) == "table" then
		local characterName = payload.CharacterName

		if typeof(characterName) ~= "string" then
			return nil, nil
		end

		return characterName, {
			SkinName = payload.SkinName,
			MorphEnabled = payload.MorphEnabled == true,
		}
	end

	return nil, nil
end

characterRemote.OnServerEvent:Connect(function(player, action, payload)
	local currentCharacter = player.Character
	if currentCharacter and currentCharacter:GetAttribute("Emoting") == true then
		EmoteService:CancelEmote(player)
	end

	if action == "SelectCharacter" then
		local characterName, options = parseCharacterRequest(action, payload)
		if characterName then
			CharacterService:SetCharacter(player, characterName, options)
		end
	elseif action == "PlayAsCharacter" then
		local characterName, options = parseCharacterRequest(action, payload)
		if characterName then
			CharacterService:SetCharacter(player, characterName, options)
		end
	elseif action == "BuyCharacter" then
		local characterName = payload
		local ok = ProgressionService:PurchaseCharacter(player, characterName)

		if ok then
			CharacterService:SetCharacter(player, characterName)
		end
	end
end)

-- Startup
StateService:StartCharacterSetup()
EmoteService:Start()
KillCreditService:Start()
ProgressionService:Start()
CharacterMorphService:Start()
CharacterService:Start()
CinematicService:Start()
AwakeningMusicService:Start()
LoreCinematicService:Start()
ShopLocationService:Start()
UltService:Start()
SoulBurstService:Start()
SpawnService:Start()
DebugService:Start()

print("[CombatServer] Ready")
