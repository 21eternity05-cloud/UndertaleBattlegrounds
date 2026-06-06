print("[CombatServer] Starting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local combatFolder = script.Parent

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
local CharacterService = require(combatFolder:WaitForChild("CharacterService")).new(
	Config,
	WeaponService,
	ProgressionService,
	CharacterMorphService
)
local UltService = require(combatFolder:WaitForChild("UltService")).new(Config)

-- Status / utility services
local CombatStatusService = require(combatFolder:WaitForChild("CombatStatusService")).new(Config)
local CinematicService = require(combatFolder:WaitForChild("CinematicService")).new(Config)
local LoreCinematicService = require(combatFolder:WaitForChild("LoreCinematicService")).new(Config, ProgressionService)
local ShopLocationService = require(combatFolder:WaitForChild("ShopLocationService")).new(Config)
local DebugService = require(combatFolder:WaitForChild("DebugService")).new(Config)

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

-- Cross-service wiring
StateService.CounterService = CounterService
StateService.CombatStatusService = CombatStatusService
StateService.ProjectileService = ProjectileService
StateService.UltService = UltService
StateService.CinematicService = CinematicService

M1Service.UltService = UltService
M1Service.DamageNumberService = DamageNumberService

MoveService.ProjectileService = ProjectileService
MoveService.UltService = UltService
MoveService.CinematicService = CinematicService
MoveService.DamageNumberService = DamageNumberService
MoveService.ProgressionService = ProgressionService
MoveService.GrabService = GrabService

ProjectileService.UltService = UltService
ProjectileService.DamageNumberService = DamageNumberService
ProjectileService.ProgressionService = ProgressionService

CounterService.UltService = UltService
UltService.ProgressionService = ProgressionService

-- Remotes
combatRemote.OnServerEvent:Connect(function(player, action, payload)
	if action == "M1" then
		M1Service:PerformM1(player, payload)
	elseif action == "BlockStart" then
		BlockService:SetBlocking(player, true)
	elseif action == "BlockEnd" then
		BlockService:SetBlocking(player, false)
	end
end)

moveRemote.OnServerEvent:Connect(function(player, moveRequest)
	MoveService:PerformMove(player, moveRequest)
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
ProgressionService:Start()
CharacterMorphService:Start()
CharacterService:Start()
CinematicService:Start()
LoreCinematicService:Start()
ShopLocationService:Start()
UltService:Start()
DebugService:Start()

print("[CombatServer] Ready")
