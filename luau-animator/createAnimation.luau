--!strict

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local KeyframeCache = {} :: { [AnimationObject]: AnimationSequence }
local Tween = require("./Tween")

export type AnimationObject = KeyframeSequence | Animation | string
export type AnimationPose = {
	-- easing direction
	tween: (t: number) -> (number),

	-- cframe
	cframe: CFrame,
	
	-- weight
	weight: number,

	-- time in seconds
	t: number,
}

export type AnimationSequence = {
	-- pose targets
	data: { [string]: { AnimationPose } },
	
	-- length in seconds
	length: number,

	-- priority of the track
	priority: Enum.AnimationPriority,

	-- whether it is additive
	additive: boolean,

	-- whether it is looped
	looped: boolean,
}

local PoseEasings = table.freeze({
	[Enum.PoseEasingStyle.Linear] = {
		[Enum.PoseEasingDirection.InOut] = Tween.linear,
		[Enum.PoseEasingDirection.Out] = Tween.linear,
		[Enum.PoseEasingDirection.In] = Tween.linear,
	},

	[Enum.PoseEasingStyle.Constant] = {
		[Enum.PoseEasingDirection.InOut] = Tween.constant,
		[Enum.PoseEasingDirection.Out] = Tween.constant,
		[Enum.PoseEasingDirection.In] = Tween.constant,
	},

	[Enum.PoseEasingStyle.CubicV2] = {
		[Enum.PoseEasingDirection.InOut] = Tween.easeInOutCubic,
		[Enum.PoseEasingDirection.Out] = Tween.easeOutCubic,
		[Enum.PoseEasingDirection.In] = Tween.easeInCubic,
	},
	
	[Enum.PoseEasingStyle.Cubic] = {
		[Enum.PoseEasingDirection.InOut] = Tween.easeInOutCubic,
		[Enum.PoseEasingDirection.Out] = Tween.easeOutCubic,
		[Enum.PoseEasingDirection.In] = Tween.easeInCubic,
	},
	
	[Enum.PoseEasingStyle.Bounce] = {
		[Enum.PoseEasingDirection.InOut] = Tween.easeInOutBounce,
		[Enum.PoseEasingDirection.Out] = Tween.easeOutBounce,
		[Enum.PoseEasingDirection.In] = Tween.easeInBounce,
	},

	[Enum.PoseEasingStyle.Elastic] = {
		[Enum.PoseEasingDirection.InOut] = Tween.easeInOutElastic,
		[Enum.PoseEasingDirection.Out] = Tween.easeOutElastic,
		[Enum.PoseEasingDirection.In] = Tween.easeInElastic,
	},
})

local function createPose(pose: Pose, t: number): AnimationPose
	local cframe = pose.CFrame
	
	return {
		-- get the easing style
		tween = PoseEasings[pose.EasingStyle][pose.EasingDirection],
		
		-- set the axis
		cframe = cframe,
		
		-- weight
		weight = pose.Weight,
		
		-- set the t
		t = t,
	}
end

local function createAnimation(object: AnimationObject): AnimationSequence
	if KeyframeCache[object] then
		-- its in the cache already
		return KeyframeCache[object]
	end

	local sequence: KeyframeSequence
	if typeof(object) == "string" then
		-- get the keyframe sequence
		sequence = KeyframeSequenceProvider:GetKeyframeSequenceAsync(object)
	elseif object:IsA("Animation") then
		-- get the animation from the site
		return createAnimation(object.AnimationId)
	else
		-- the keyframe sequence is the object itself
		sequence = object
	end

	-- get the keyframes
	local keyframes = sequence:GetKeyframes()
	table.sort(keyframes, function(a: Keyframe, b: Keyframe)
		return a.Time < b.Time
	end)

	local data = {}
	for i, keyframe in keyframes do
		-- get the keyframe data
		local t = keyframe.Time
		for j, pose in keyframe:GetDescendants() do
			if not pose:IsA("Pose") then
				-- not a pose
				continue
			elseif pose.Weight == 0 then
				continue
			end

			-- add to the data
			local name = pose.Name
			if not data[name] then
				data[name] = { createPose(pose, t) }
			else
				table.insert(data[name], createPose(pose, t))
			end
		end
	end

	-- create the animation track data
	local result = {
		-- data
		data = data,

		-- length in seconds
		length = if #keyframes == 0
			then 0.1
			else math.max(keyframes[#keyframes].Time - (1/60), 0.1),

		-- priority of the track
		priority = sequence.Priority,

		-- whether it is additive
		additive = false,

		-- whether it is looped
		looped = sequence.Loop,
	}
	
	KeyframeCache[object] = result
	return result
end

return createAnimation