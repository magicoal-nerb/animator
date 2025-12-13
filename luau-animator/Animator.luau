--!strict

local EPSILON = 1e-3

local createAnimation = require("./createAnimation")
local createRig = require("./createRig")

local AnimationTrack = require("./AnimationTrack")
local Signal = require("./Signal")

local Animator = {}
Animator.__index = Animator

export type AnimationSequence = createAnimation.AnimationSequence
export type AnimationTrack = AnimationTrack.AnimationTrack
export type Signal<T...> = Signal.Signal<T...>

export type BoneInstance = createRig.BoneInstance
export type RigBone = createRig.RigBone

export type Animator = typeof(setmetatable(
	{} :: {
		-- animation played
		AnimationPlayed: Signal<AnimationTrack>,
		
		-- the rig
		rig: Model,
		
		-- the current animation
		currentAnimation: AnimationTrack?,
		
		-- get teh current animation
		animations: { AnimationTrack },
		
		-- connections
		connections: { RBXScriptConnection },

		-- current bone
		bones: { [string]: RigBone },

		-- ordered stuff :D
		order: { string },

		-- queue
		queue: { number },
	},
	Animator
))

function Animator.new(rig: Model): Animator
	local order, bones = createRig(rig)
	local self = setmetatable({
		AnimationPlayed = Signal.new(),
		rig = rig,
		
		-- animations and queue
		connections = {},
		animations = {},
		queue = {},

		-- order, bones
		order = order,
		bones = bones,
	}, Animator) :: Animator

	self.connections = {
		-- Destroy animator once rig is removed
		self.rig.Destroying:Connect(function()
			for i, connection in self.connections do
				connection = connection:Disconnect()
			end
		end),
		
		-- Update the order and bones when a Motor6D is added or removed
		self.rig.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") then
				self.order, self.bones = createRig(self.rig)
			end
		end),

		self.rig.DescendantRemoving:Connect(function(descendant: Instance)
			if descendant:IsA("Motor6D") then
				self.order, self.bones = createRig(self.rig)
			end
		end),
	}

	return self
end

function Animator.Destroy(self: Animator)	
	-- Disconnect and clear the animator object
	for i, connection in self.connections do
		connection:Disconnect()
	end
	
	table.clear(self :: any)
	table.freeze(self)
end

function Animator.LoadAnimation(self: Animator, track: createAnimation.AnimationObject): AnimationTrack
	-- Load an animation track
	local data = AnimationTrack.new(
		self,
		createAnimation(track)
	)
	
	return data
end

function Animator.StepAnimations(self: Animator, dt: number)
	local queue = self.queue
	for i, playback in self.animations do
		-- Update animation
		playback:Step(dt)
		
		if playback.WeightTarget == 0.0
			and playback.WeightCurrent < EPSILON then
			table.insert(queue, i)
		end
	end

	for i = #queue, 1, -1 do
		-- When an animation stops normally, we call the stopped
		-- method in order to remove it
		local id = queue[i]
		local playback = self.animations[id]
		playback:Stop(0)
	end

	local bones = self.bones
	for i, pose in self.order do
		-- Set the bone transform
		local data = bones[pose]
		local bone = data.bone :: any
		
		local cframe = data.cframe:Lerp(bone.Transform, data.weight)
		bone.Transform = cframe
		
		data.transform = cframe
		data.cframe = CFrame.identity
		data.weight = 1.0
	end

	table.clear(queue)
end

return Animator
