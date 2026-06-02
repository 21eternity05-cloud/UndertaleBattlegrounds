print("[CombatServer] Starting")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatRemote = remotes:WaitForChild("CombatRemote")
local characterRemote = remotes:WaitForChild("CharacterRemote")
local moveRemote = remotes:WaitForChild("MoveRemote")

local combatFolder = script.Parent

local Config = require(combatFolder:WaitForChild("CombatConfig"))

local AnimationService = require(combatFolder:WaitForChild("AnimationService")).new(Config)
local VFXService = require(combatFolder:WaitForChild("VFXService")).new(Config)
local StateService = require(combatFolder:WaitForChild("StateService")).new(Config, AnimationService, VFXService)
local HitboxService = require(combatFolder:WaitForChild("HitboxService")).new(Config)
local MovementService = require(combatFolder:WaitForChild("MovementService")).new(Config)
local BlockService = require(combatFolder:WaitForChild("BlockService")).new(Config, StateService, VFXService)
local WeaponService = require(combatFolder:WaitForChild("WeaponService")).new(Config)
local CharacterService = require(combatFolder:WaitForChild("CharacterService")).new(Config, WeaponService)
local UltService = require(combatFolder:WaitForChild("UltService")).new(Config)
local DebugService = require(combatFolder:WaitForChild("DebugService")).new(Config)

local CombatStatusService = require(combatFolder:WaitForChild("CombatStatusService")).new(Config)
local CinematicService = require(combatFolder:WaitForChild("CinematicService")).new(Config)

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
	MovementService
)

StateService.CounterService = CounterService
StateService.CombatStatusService = CombatStatusService
StateService.ProjectileService = ProjectileService
StateService.UltService = UltService
StateService.CinematicService = CinematicService

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