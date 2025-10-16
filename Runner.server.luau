--!strict

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LuauAnimator = require(ReplicatedStorage["luau-animator"])

local createAnimation = LuauAnimator.createAnimation
local Animator = LuauAnimator.Animator

-- Helper function to create a humanoid rig
local function createRig(outfitId: number, pivot: CFrame): LuauAnimator.Animator
	local description = Players:GetHumanoidDescriptionFromOutfitId(outfitId)
	local rig = Players:CreateHumanoidModelFromDescription(
		description,
		Enum.HumanoidRigType.R15
	)

	rig:PivotTo(pivot)
	rig.PrimaryPart.Anchored = true
	rig.Parent = workspace

	return Animator.new(rig)
end

-- Helper function that gets the animations from
-- ROBLOX, which we then process so the animator
-- recognizes what to do
local function loadAnimations(
	rig: LuauAnimator.Animator,
	animations: { number }
): { LuauAnimator.AnimationPlayback }
	local output = {} :: { LuauAnimator.AnimationPlayback }
	for i, id in animations do
		-- Get the keyframe sequence
		local animation = KeyframeSequenceProvider:GetKeyframeSequenceAsync(`rbxassetid://{id}`)
		local animationTrack = createAnimation(animation)
		output[i] = rig:loadAnimation(animationTrack)
	end

	return output
end

-- Create the dummy character
local Cursor = 1
local Rig = createRig(1998955759533732, CFrame.new(0, 2.2, 10))
local Animations = loadAnimations(Rig, {
	10714061912, -- curtsy
	10921242013, -- jump
	10921240218, -- walk
})

local function playNextAnimation()
	-- just cycle through animations to test
	-- playback
	Rig:stopAnimation(Animations[Cursor], 0.3)
	
	Cursor = (Cursor % #Animations) + 1
	Rig:playAnimation(Animations[Cursor])
end

RunService.PreSimulation:Connect(function(dt)
	dt = math.min(dt, 1/30)
	Rig:update(dt)
end)

while task.wait(1) do
	playNextAnimation()
end