--!strict

local createAnimation = require("./createAnimation")
local Signal = require("./Signal")

local Priorities = {
	[Enum.AnimationPriority.Core] = 0,
	[Enum.AnimationPriority.Idle] = 1,
	[Enum.AnimationPriority.Movement] = 2,
	[Enum.AnimationPriority.Action] = 3,
	[Enum.AnimationPriority.Action2] = 4,
	[Enum.AnimationPriority.Action3] = 5,
	[Enum.AnimationPriority.Action4] = 6,
}

local AnimationTrack = {}
AnimationTrack.__index = AnimationTrack

export type AnimationSequence = createAnimation.AnimationSequence
export type AnimationPose = createAnimation.AnimationPose
export type AnimationTrack = typeof(setmetatable(
	{} :: {
		-- animator
		Animator: any,
		
		-- main track
		Animation: AnimationSequence,

		-- timer
		TimePosition: number,

		-- looped
		Looped: boolean,

		-- additive
		Additive: boolean,

		-- playing
		IsPlaying: boolean,

		-- set target weight
		WeightTarget: number,

		-- speed of weight
		WeightSpeed: number,

		-- speed
		Speed: number,

		-- weight
		WeightCurrent: number,

		-- priority
		Priority: Enum.AnimationPriority,
		
		-- stopped
		Stopped: Signal.Signal<number>,
		
		-- changed
		Changed: Signal.Signal<number, number>,
		
		-- keyframe
		KeyframeReached: Signal.Signal<string>,
		
		-- did loop
		DidLoop: Signal.Signal<boolean>,
	},
	
	AnimationTrack
))

local function getPose(poses: { AnimationPose }, t: number): (CFrame, number)
	if #poses == 1 then
		return poses[1].cframe, poses[1].weight
	elseif #poses == 0 then
		return CFrame.identity, 0.0
	end

	local j = #poses - 1
	local i = 1

	-- binary search
	while i < j do
		local center = (i + j) // 2
		if poses[center].t < t then
			i = center + 1
		else
			j = center
		end
	end

	while i > 1 and poses[i].t > t do
		i -= 1
	end

	-- general case
	local after = poses[i + 1]
	local current = poses[i]

	local param = math.min((t - current.t) / (after.t - current.t), 1.0)
	local alpha = current.tween(param)
	local weight = current.weight * (1.0 - alpha) + after.weight * alpha

	return current.cframe:Lerp(after.cframe, alpha), weight
end

function AnimationTrack.new(self: any, track: AnimationSequence): AnimationTrack
	return setmetatable({
		Animator = self,

		-- weight
		WeightCurrent = 0.0,
		WeightSpeed = 0.0,
		WeightTarget = 0.0,

		-- playback
		TimePosition = 0.0,
		Speed = 1.0,
		Priority = track.priority,

		-- state
		Looped = track.looped,
		Animation = track,

		-- config
		Additive = false,
		IsPlaying = false,
		
		DidLoop = Signal.new(),
		Stopped = Signal.new(),
		Changed = Signal.new(),
		KeyframeReached = Signal.new(),
	}, AnimationTrack)
end

function AnimationTrack.Stop(self: AnimationTrack, fade: number?)
	local animations = self.Animator.animations
	if not self.IsPlaying then
		-- already stopped
		return
	elseif fade == 0.0 then
		-- straight up remove the animation
		local index = table.find(animations, self)
		assert(index, "playback could not find playback")

		table.remove(animations, index)
		self.WeightCurrent = 0.0
		self.IsPlaying = false
	else
		-- just fade out weight
		self.WeightSpeed = 1.0 / (fade or 0.3)
	end
	
	-- stop
	self.KeyframeReached:Fire("End")
	self.Stopped:Fire(fade or 0.3)
	self.WeightTarget = 0.0
end

function AnimationTrack.Play(
	self: AnimationTrack,
	fade: number?,
	weight: number?,
	speed: number?
)
	local animator = self.Animator
	local animations = animator.animations
	local length = #animations

	-- set playback properties
	self.WeightTarget = weight or 1.0
	self.WeightSpeed = 1.0 / (fade or 0.3)
	
	self.Speed = speed or self.Speed
	self.TimePosition = 0.0

	animator.AnimationPlayed:Fire(
		self,
		fade or 0.3,
		weight or 1.0,
		speed or 1.0
	)
	
	local priority = Priorities[self.Priority]
	if self.IsPlaying then
		-- just restart playback because
		-- this is already playing
		local index = table.find(animations, self) :: number
		local read = index
		
		while read > 0 and Priorities[animations[read].Priority] <= priority do
			read -= 1
		end

		-- swap indexes 
		read += 1
		animations[index], animations[read] = animations[read], animations[index]
		return
	end

	local j = length
	local i = 1

	-- binary search for insertion
	while i < j do
		local center = (i + j) // 2
		if Priorities[animations[center].Priority] <= priority then
			i = center + 1
		else
			j = center
		end
	end

	-- get left bound
	while i <= #animations and Priorities[animations[i].Priority] <= priority do
		i += 1
	end

	self.IsPlaying = true
	table.insert(animations, i, self)
end

function AnimationTrack.AdjustWeight(self: AnimationTrack, weight: number?, fadeTime: number?)
	local currentWeight = weight or 1
	currentWeight = math.clamp(currentWeight, 0, 1)
	
	if fadeTime == 0.0 then
		-- Adjusts the track weight
		self.WeightTarget = currentWeight
		self.WeightCurrent = currentWeight
	else
		-- Set fade time
		self.WeightTarget = currentWeight
		self.WeightSpeed = 1.0 / (fadeTime or 0.1)
	end
	
	self.Changed:Fire(self.Speed, self.WeightTarget)
end

function AnimationTrack.AdjustSpeed(self: AnimationTrack, speed: number)
	-- speed
	self.Speed = speed or 1.0
	self.Changed:Fire(self.Speed, self.WeightTarget)
end

function AnimationTrack.Step(self: AnimationTrack, dt: number)
	-- update scrubber
	local t = self.TimePosition + dt * self.Speed
	local track = self.Animation

	local bones = self.Animator.bones
	local weight = self.WeightCurrent
	for name, poses in track.data do
		-- get the bone and the pose
		local cframe, boneWeight = getPose(poses, t)
		local bone = bones[name]
		if not bone then
			-- no bone found here
			continue
		elseif bone.weight <= 0 then
			-- cannot update this bone
			continue
		end

		-- update the final weight
		local finalWeight = if not self.Additive
			then math.min(weight, bone.weight) * boneWeight
			else weight * boneWeight

		local costWeight = if not self.Additive
			then finalWeight
			else 0

		bone.weight -= costWeight
		bone.cframe = CFrame.identity:Lerp(cframe, finalWeight) * bone.cframe
	end

	local length = track.length
	if self.Looped then
		-- loop the animation and
		-- offset the starting time
		if t > length then
			t %= length
			self.DidLoop:Fire()
		end
	elseif t >= length - 0.2 then
		-- make the playback have
		-- no weight
		self.WeightTarget = 0.0
	elseif t < 0.0 then
		-- we have reversed playback,
		-- so we have to go backwards
		t %= length
	end

	self.TimePosition = t
	self.WeightCurrent += math.clamp(
		self.WeightTarget - self.WeightCurrent,
		-self.WeightSpeed * dt,
		self.WeightSpeed * dt
	)
end

return AnimationTrack