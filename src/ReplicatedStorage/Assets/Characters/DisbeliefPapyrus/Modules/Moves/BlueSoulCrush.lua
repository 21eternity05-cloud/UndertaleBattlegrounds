local BlueSoulCrush = {
	DisplayName = "Blue Soul Crush",
	AnimationName = nil,
	Cooldown = 6,
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

function BlueSoulCrush.Execute(context)
	print("[DisbeliefPapyrus] Placeholder move used:", BlueSoulCrush.DisplayName)

	task.delay(0.1, function()
		if context and context.FinishMove then
			context:FinishMove()
		end
	end)
end

return BlueSoulCrush
