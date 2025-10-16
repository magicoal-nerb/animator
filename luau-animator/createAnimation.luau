--!strict

local Tween = require("./Tween")

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

export type AnimationTrack = {
	-- pose targets
	data: { [string]: { AnimationPose } },
	
	-- length in seconds
	length: number,

	-- priority of the track
	priority: number,

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

return function(sequence: KeyframeSequence)
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
	return {
		-- data
		data = data,
		
		-- length in seconds
		length = keyframes[#keyframes].Time - (1/60),
		
		-- priority of the track
		priority = sequence.Priority.Value,
		
		-- whether it is additive
		additive = false,
		
		-- whether it is looped
		looped = sequence.Loop,
	}
end