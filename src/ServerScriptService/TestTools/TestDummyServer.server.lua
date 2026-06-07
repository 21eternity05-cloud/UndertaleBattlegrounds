local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatServer = ServerScriptService:WaitForChild("CombatServer")
local Config = require(CombatServer:WaitForChild("CombatConfig"))

local AnimationService = require(CombatServer:WaitForChild("AnimationService")).new(Config)
local VFXService = require(CombatServer:WaitForChild("VFXService")).new(Config)
local StateService = require(CombatServer:WaitForChild("StateService")).new(Config, AnimationService, VFXService)
local MovementService = require(CombatServer:WaitForChild("MovementService")).new(Config)
local BlockService = require(CombatServer:WaitForChild("BlockService")).new(Config, StateService, VFXService)
local CombatStatusService = require(CombatServer:WaitForChild("CombatStatusService")).new(Config)
local CounterService = require(CombatServer:WaitForChild("CounterService")).new(
	Config,
	StateService,
	MovementService,
	VFXService
)

StateService.CounterService = CounterService
StateService.CombatStatusService = CombatStatusService

local NPCM1Module = require(script.Parent:WaitForChild("NPCM1"))
local NPCM1 = NPCM1Module.new(Config, {
	StateService = StateService,
	MovementService = MovementService,
	BlockService = BlockService,
	VFXService = VFXService,
	CounterService = CounterService,
	CombatStatusService = CombatStatusService,
})

local dummyFolder = workspace:WaitForChild("TestDummies")

local ATTACK_RANGE = Config.TestDummyAttackRange or 8
local ATTACK_INTERVAL = Config.TestDummyAttackInterval or 0.36
local COMBO_PAUSE = Config.TestDummyComboPause or 1.5

local RESPAWN_TIME = Config.TestDummyRespawnTime or 1.5
local IMMORTAL_DUMMY_HEALTH = Config.TestDummyHealth or 100000
local RESPAWN_DUMMY_HEALTH = Config.RespawnDummyHealth or 100

local activeLoops = {}
local respawnTemplates = {}
local respawnCFrames = {}

local function findHumanoidAndRoot(model)
	if not model then return nil, nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	return humanoid, root
end

local function getOrCreateObjectValue(parent, name)
	local value = parent:FindFirstChild(name)

	if not value then
		value = Instance.new("ObjectValue")
		value.Name = name
		value.Parent = parent
	end

	return value
end

local function prepareCounterStorage(character)
	if not character then return end

	local counterAttacker = getOrCreateObjectValue(character, "CounterAttacker")
	counterAttacker.Value = nil

	if character:GetAttribute("Countering") == nil then
		character:SetAttribute("Countering", false)
	end

	if character:GetAttribute("CounterTriggered") == nil then
		character:SetAttribute("CounterTriggered", false)
	end

	if character:GetAttribute("CounterToken") == nil then
		character:SetAttribute("CounterToken", 0)
	end

	if character:GetAttribute("CounterMoveId") == nil then
		character:SetAttribute("CounterMoveId", nil)
	end

	if character:GetAttribute("CounterAttackName") == nil then
		character:SetAttribute("CounterAttackName", nil)
	end
end

local function initializeCombatAttributes(character)
	if not character then return end

	if character:GetAttribute("CharacterName") == nil then
		character:SetAttribute("CharacterName", Config.DefaultCharacterName or "Chara")
	end

	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("LastM1Time", 0)

	character:SetAttribute("Attacking", false)
	character:SetAttribute("Stunned", false)
	character:SetAttribute("Guardbroken", false)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("BlockBufferedUntil", 0)
	character:SetAttribute("BlockHeld", false)
	character:SetAttribute("BlockBufferToken", 0)
	character:SetAttribute("BlockLockedUntil", 0)
	character:SetAttribute("BlockInputReleasedAfterGuardbreak", true)

	character:SetAttribute("UsingMove", false)
	character:SetAttribute("MoveToken", 0)

	character:SetAttribute("AirComboReady", false)
	character:SetAttribute("UsedUptiltInCombo", false)
	character:SetAttribute("UptiltCooldownUntil", 0)

	character:SetAttribute("JumpLockedUntil", 0)
	character:SetAttribute("M1ImmuneUntil", 0)
	character:SetAttribute("StunId", 0)

	prepareCounterStorage(character)
end

local function isRespawnDummy(dummy)
	if not dummy then
		return false
	end

	if dummy:GetAttribute("RespawnDummy") == true then
		return true
	end

	local loweredName = string.lower(dummy.Name)

	if string.find(loweredName, "respawn") then
		return true
	end

	return false
end

local function isImmortalDummy(dummy)
	if not dummy then
		return false
	end

	if isRespawnDummy(dummy) then
		return false
	end

	if dummy:GetAttribute("Immortal") == false then
		return false
	end

	return true
end

local function cacheRespawnTemplate(dummy)
	if not isRespawnDummy(dummy) then
		return
	end

	if respawnTemplates[dummy.Name] then
		return
	end

	respawnCFrames[dummy.Name] = dummy:GetPivot()

	local template = dummy:Clone()
	template.Name = dummy.Name .. "_Template"
	template.Parent = nil

	-- Important:
	-- Do not let the respawn clone skip setupDummy().
	template:SetAttribute("TestDummySetup", nil)
	template:SetAttribute("RespawnDummy", true)
	template:SetAttribute("Immortal", false)

	local templateHumanoid = template:FindFirstChildOfClass("Humanoid")
	if templateHumanoid then
		templateHumanoid.MaxHealth = RESPAWN_DUMMY_HEALTH
		templateHumanoid.Health = RESPAWN_DUMMY_HEALTH
		templateHumanoid.BreakJointsOnDeath = false
		templateHumanoid.RequiresNeck = false
	end

	respawnTemplates[dummy.Name] = template

	print("[TestDummyServer] Cached respawn template:", dummy.Name)
end

local function getNearestPlayer(position)
	local nearestPlayer = nil
	local nearestCharacter = nil
	local nearestHumanoid = nil
	local nearestRoot = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if character and humanoid and root and humanoid.Health > 0 then
			prepareCounterStorage(character)

			local distance = (root.Position - position).Magnitude

			if distance < nearestDistance then
				nearestPlayer = player
				nearestCharacter = character
				nearestHumanoid = humanoid
				nearestRoot = root
				nearestDistance = distance
			end
		end
	end

	return nearestPlayer, nearestCharacter, nearestHumanoid, nearestRoot, nearestDistance
end

local function faceTarget(dummyRoot, targetRoot)
	if not dummyRoot or not targetRoot then return end

	local lookPosition = Vector3.new(
		targetRoot.Position.X,
		dummyRoot.Position.Y,
		targetRoot.Position.Z
	)

	if (lookPosition - dummyRoot.Position).Magnitude <= 0.05 then
		return
	end

	dummyRoot.CFrame = CFrame.lookAt(dummyRoot.Position, lookPosition)
end

local function canDummyAttack(dummy)
	local humanoid, root = findHumanoidAndRoot(dummy)
	if not humanoid or not root then return false end
	if humanoid.Health <= 0 then return false end

	if dummy:GetAttribute("Stunned") then return false end
	if dummy:GetAttribute("Guardbroken") then return false end
	if dummy:GetAttribute("UsingMove") then return false end
	if dummy:GetAttribute("Countering") then return false end

	return true
end

local function performDummyM1(dummy, targetCharacter, targetRoot, wantUptilt)
	if not canDummyAttack(dummy) then
		return
	end

	local _, dummyRoot = findHumanoidAndRoot(dummy)
	if not dummyRoot then return end

	if targetRoot then
		faceTarget(dummyRoot, targetRoot)
	end

	NPCM1:PerformM1(dummy, {
		wantUptilt = wantUptilt == true,
		AttackerCharacter = dummy,
		TargetCharacter = targetCharacter,
		TargetRoot = targetRoot,
	})
end

local function startComboDummy(dummy)
	if activeLoops[dummy] then return end
	activeLoops[dummy] = true

	task.spawn(function()
		while dummy.Parent and activeLoops[dummy] do
			local humanoid, root = findHumanoidAndRoot(dummy)

			if not humanoid or not root or humanoid.Health <= 0 then
				task.wait(0.25)
				continue
			end

			local _, targetCharacter, _, targetRoot, distance = getNearestPlayer(root.Position)

			if targetCharacter and targetRoot and distance <= ATTACK_RANGE then
				for _ = 1, Config.FinalM1 or 5 do
					if not dummy.Parent or not activeLoops[dummy] then
						break
					end

					local _, currentTargetCharacter, _, currentTargetRoot, currentDistance = getNearestPlayer(root.Position)

					if not currentTargetCharacter or not currentTargetRoot or currentDistance > ATTACK_RANGE + 4 then
						break
					end

					performDummyM1(dummy, currentTargetCharacter, currentTargetRoot, false)

					task.wait(ATTACK_INTERVAL)
				end

				task.wait(COMBO_PAUSE)
			else
				task.wait(0.15)
			end
		end

		activeLoops[dummy] = nil
	end)
end

local function startAirComboDummy(dummy)
	if activeLoops[dummy] then return end
	activeLoops[dummy] = true

	task.spawn(function()
		while dummy.Parent and activeLoops[dummy] do
			local humanoid, root = findHumanoidAndRoot(dummy)

			if not humanoid or not root or humanoid.Health <= 0 then
				task.wait(0.25)
				continue
			end

			local _, targetCharacter, _, targetRoot, distance = getNearestPlayer(root.Position)

			if targetCharacter and targetRoot and distance <= ATTACK_RANGE then
				performDummyM1(dummy, targetCharacter, targetRoot, false)

				task.wait(ATTACK_INTERVAL)

				local _, currentTargetCharacter, _, currentTargetRoot, currentDistance = getNearestPlayer(root.Position)

				if currentTargetCharacter and currentTargetRoot and currentDistance <= ATTACK_RANGE + 8 then
					performDummyM1(dummy, currentTargetCharacter, currentTargetRoot, true)
				end

				task.wait(0.55)

				for _ = 1, 3 do
					if not dummy.Parent or not activeLoops[dummy] then
						break
					end

					local _, airTargetCharacter, _, airTargetRoot, airDistance = getNearestPlayer(root.Position)

					if not airTargetCharacter or not airTargetRoot or airDistance > ATTACK_RANGE + 12 then
						break
					end

					performDummyM1(dummy, airTargetCharacter, airTargetRoot, false)

					task.wait(ATTACK_INTERVAL)
				end

				task.wait(COMBO_PAUSE + 0.8)
			else
				task.wait(0.15)
			end
		end

		activeLoops[dummy] = nil
	end)
end

local function startDummyBehavior(dummy)
	if dummy.Name == "ComboDummy" or dummy:GetAttribute("ComboDummy") == true then
		startComboDummy(dummy)
	elseif dummy.Name == "AirComboDummy" or dummy:GetAttribute("AirComboDummy") == true then
		startAirComboDummy(dummy)
	end
end

local function respawnDummy(dummyName)
	local template = respawnTemplates[dummyName]
	local spawnCFrame = respawnCFrames[dummyName]

	if not template or not spawnCFrame then
		warn("[TestDummyServer] Missing respawn template for:", dummyName)
		return
	end

	local clone = template:Clone()
	clone.Name = dummyName

	-- Important:
	-- Force setupDummy() to run again on the fresh clone.
	clone:SetAttribute("TestDummySetup", nil)
	clone:SetAttribute("RespawnDummy", true)
	clone:SetAttribute("Immortal", false)

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = RESPAWN_DUMMY_HEALTH
		humanoid.Health = RESPAWN_DUMMY_HEALTH
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end

	clone.Parent = dummyFolder
	clone:PivotTo(spawnCFrame)

	task.wait()

	print("[TestDummyServer] Respawned:", dummyName)
end

local function setupDummy(dummy)
	if not dummy:IsA("Model") then return end
	if dummy:GetAttribute("TestDummySetup") == true then return end
	dummy:SetAttribute("TestDummySetup", true)

	local humanoid, root = findHumanoidAndRoot(dummy)

	if not humanoid or not root then
		warn("[TestDummyServer] Missing Humanoid or HumanoidRootPart:", dummy.Name)
		return
	end

	local respawns = isRespawnDummy(dummy)

	if respawns then
	dummy:SetAttribute("RespawnDummy", true)
	dummy:SetAttribute("Immortal", false)

	humanoid.MaxHealth = RESPAWN_DUMMY_HEALTH
	humanoid.Health = RESPAWN_DUMMY_HEALTH
else
	humanoid.MaxHealth = IMMORTAL_DUMMY_HEALTH
	humanoid.Health = IMMORTAL_DUMMY_HEALTH
end

	cacheRespawnTemplate(dummy)

	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	if respawns then
		humanoid.MaxHealth = RESPAWN_DUMMY_HEALTH
		humanoid.Health = RESPAWN_DUMMY_HEALTH
	else
		humanoid.MaxHealth = IMMORTAL_DUMMY_HEALTH
		humanoid.Health = IMMORTAL_DUMMY_HEALTH
	end

	root.Anchored = false

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	initializeCombatAttributes(dummy)

	if dummy.Name == "BlockDummy" or dummy:GetAttribute("BlockDummy") == true then
		dummy:SetAttribute("Blocking", true)
	else
		dummy:SetAttribute("Blocking", false)
	end

	NPCM1:SetupNPC(dummy)

	if isImmortalDummy(dummy) then
		humanoid.HealthChanged:Connect(function()
			if humanoid.Health < humanoid.MaxHealth and humanoid.Health > 0 then
				task.delay(0.05, function()
					if humanoid and humanoid.Parent and humanoid.Health > 0 then
						humanoid.Health = humanoid.MaxHealth
					end
				end)
			end
		end)
	end

	if respawns then
		humanoid.Died:Connect(function()
			local dummyName = dummy.Name
			activeLoops[dummy] = nil

			task.delay(RESPAWN_TIME, function()
				if dummy and dummy.Parent then
					dummy:Destroy()
				end

				respawnDummy(dummyName)
			end)
		end)
	end

	dummy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			activeLoops[dummy] = nil
		end
	end)

	print("[TestDummyServer] Set up:", dummy.Name, "Respawn:", respawns, "Immortal:", isImmortalDummy(dummy))
end

for _, dummy in ipairs(dummyFolder:GetChildren()) do
	setupDummy(dummy)
	startDummyBehavior(dummy)
end

dummyFolder.ChildAdded:Connect(function(child)
	task.wait(0.2)

	setupDummy(child)
	startDummyBehavior(child)
end)

dummyFolder.ChildRemoved:Connect(function(child)
	activeLoops[child] = nil
end)

RunService.Heartbeat:Connect(function()
	local blockDummy = dummyFolder:FindFirstChild("BlockDummy")
	if not blockDummy then return end

	local humanoid, root = findHumanoidAndRoot(blockDummy)
	if not humanoid or not root or humanoid.Health <= 0 then return end

	blockDummy:SetAttribute("Blocking", true)

	local _, _, _, nearestRoot = getNearestPlayer(root.Position)
	if not nearestRoot then return end

	faceTarget(root, nearestRoot)
end)

print("[TestDummyServer] Ready. Block buffer test: stand near ComboDummy, get hit, hold block during stun, and block should start as stun ends.")
