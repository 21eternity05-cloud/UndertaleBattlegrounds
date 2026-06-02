print("[CombatServer] Starting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")

local Config = require(script:WaitForChild("CombatConfig"))

local AnimationService = require(script:WaitForChild("AnimationService")).new(Config)
local VFXService = require(script:WaitForChild("VFXService")).new(Config)
local StateService = require(script:WaitForChild("StateService")).new(Config, AnimationService, VFXService)
local HitboxService = require(script:WaitForChild("HitboxService")).new(Config)
local MovementService = require(script:WaitForChild("MovementService")).new(Config)
local BlockService = require(script:WaitForChild("BlockService")).new(Config, StateService, VFXService)
local WeaponService = require(script:WaitForChild("WeaponService")).new(Config)
local CharacterService = require(script:WaitForChild("CharacterService")).new(Config, WeaponService)
local UltService = require(script:WaitForChild("UltService")).new(Config)
local DebugService = require(script:WaitForChild("DebugService")).new(Config)

local CombatStatusService = require(script:WaitForChild("CombatStatusService")).new(Config)
local CinematicService = require(script:WaitForChild("CinematicService")).new(Config)

local CounterService = require(script:WaitForChild("CounterService")).new(
	Config,
	StateService,
	MovementService,
	VFXService
)

local ProjectileService = require(script:WaitForChild("ProjectileService")).new(
	Config,
	HitboxService,
	BlockService,
	StateService,
	VFXService,
	CounterService,
	CombatStatusService,
	MovementService
)

StateService.CounterService = CounterService
StateService.CombatStatusService = CombatStatusService
StateService.ProjectileService = ProjectileService
StateService.UltService = UltService
StateService.CinematicService = CinematicService

local M1Service = require(script:WaitForChild("M1Service")).new(
	Config,
	StateService,
	HitboxService,
	MovementService,
	BlockService,
	VFXService,
	CounterService,
	CombatStatusService
)

local MoveService = require(script:WaitForChild("MoveService")).new(
	Config,
	StateService,
	HitboxService,
	MovementService,
	BlockService,
	VFXService,
	CounterService,
	CombatStatusService
)

MoveService.ProjectileService = ProjectileService
MoveService.UltService = UltService
MoveService.CinematicService = CinematicService

M1Service.UltService = UltService
ProjectileService.UltService = UltService
CounterService.UltService = UltService

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

characterRemote.OnServerEvent:Connect(function(player, action, characterName)
	if action == "SelectCharacter" then
		CharacterService:SetCharacter(player, characterName)
	end
end)

StateService:StartCharacterSetup()
CharacterService:Start()
CinematicService:Start()
UltService:Start()
DebugService:Start()

print("[CombatServer] Ready")