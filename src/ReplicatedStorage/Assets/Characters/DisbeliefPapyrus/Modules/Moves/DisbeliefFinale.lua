local DisbeliefFinale = {
	DisplayName = "Disbelief Finale",
	AnimationName = nil,
	Cooldown = 1,
	Duration = 1,
	LockTime = 1,
	MaxLockTime = 2,
	Damage = 0,
	Stun = 0,
	Radius = 0,
	Offset = CFrame.new(),
	Blockable = false,
	Guardbreak = false,
}

function DisbeliefFinale.Execute(context)
	print("[DisbeliefPapyrus] Phase2 Ultimate placeholder fired.")

	task.delay(0.1, function()
		if context and context.FinishMove then
			context:FinishMove()
		end
	end)
end

return DisbeliefFinale
