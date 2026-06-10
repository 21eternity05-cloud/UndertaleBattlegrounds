local BrokenBoneRush = {
	DisplayName = "Broken Bone Rush",
	AnimationName = nil,
	Cooldown = 4,
	Duration = 0.5,
	LockTime = 0.5,
	MaxLockTime = 1,
	Damage = 0,
	Stun = 0,
	Radius = 0,
	Offset = CFrame.new(),
	Blockable = true,
	Guardbreak = false,
}

function BrokenBoneRush.Execute(context)
	print("[DisbeliefPapyrus] Placeholder move used:", BrokenBoneRush.DisplayName)

	task.delay(0.1, function()
		if context and context.FinishMove then
			context:FinishMove()
		end
	end)
end

return BrokenBoneRush
