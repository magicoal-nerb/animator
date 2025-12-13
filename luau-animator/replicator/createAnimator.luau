local RunService = game:GetService("RunService")

return if RunService:IsServer()
	then require("./createServerAnimator")
	else require("./createClientAnimator")