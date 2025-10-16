--!strict

local EPSILON = 1e-3

local createAnimation = require("./createAnimation")

local Queue = require("./Queue")

local Animator = {}
Animator.__index = Animator

export type AnimationTrack = createAnimation.AnimationTrack
export type AnimationPose = createAnimation.AnimationPose

export type BoneInstance = Motor6D | Bone

export type RigBone = {
	-- cframe
	cframe: CFrame,
	
	-- weight
	weight: number,
	
	-- bone of the thing i guess
	bone: BoneInstance,	
}

export type AnimationPlayback = {
	-- main track
	track: AnimationTrack,
	
	-- timer
	timer: number,
	
	-- looped
	looped: boolean,
	
	-- additive
	additive: boolean,
	
	-- playing
	playing: boolean,
	
	-- set target weight
	targetWeight: number,
	
	-- speed of weight
	speedWeight: number,
	
	-- speed
	speed: number,
	
	-- weight
	weight: number,
	
	-- priority
	priority: number,
}

export type Animator = typeof(setmetatable({} :: {
	-- get teh current animation
	animations: { AnimationPlayback },
	
	-- current bone
	bones: { [string]: RigBone },
	
	-- ordered stuff :D
	order: { string },
	
	-- queue
	queue: { number },
}, Animator))

local function getPose(poses: { AnimationPose }, t: number): (CFrame, number)
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
	return current.cframe:Lerp(after.cframe, alpha),
		current.weight * (1.0 - alpha) + after.weight * alpha
end

local function getRoot(
	front: { [string]: RigBone },
	reverse: { [string]: { string }}
): string?
	-- the difference between the sets reverse and front
	-- is that the root part is the only element in the set
	for part in reverse do
		if not front[part] then
			return part
		end
	end	
	
	return nil
end

local function getRig(rig: Model)
	local bones = {} :: { [string]: RigBone }
	local order = {}
	
	-- if its a bone then doing a dfs
	-- on the entire rig is good enough
	local reverse = {} :: { [string]: { string } }
	for i, bone in rig:GetDescendants() do
		if not bone then
			continue
		elseif bone:IsA("Bone") then
			table.insert(order, bone.Name)
			bones[bone.Name] = {
				-- cframe
				cframe = CFrame.identity,

				-- weight
				weight = 1.0,

				-- bone of the thing i guess
				bone = bone,	
			}
		elseif bone:IsA("Motor6D") then
			local part0 = (bone.Part0 :: BasePart).Name
			local part1 = (bone.Part1 :: BasePart).Name
			
			if reverse[part0] then
				table.insert(reverse[part0], part1)
			else
				reverse[part0] = { part1 }
			end

			bones[part1] = {
				-- cframe
				cframe = CFrame.identity,
				
				-- weight
				weight = 1.0,
				
				-- bone of the thing i guess
				bone = bone,	
			}
		end
	end
	
	-- the root joint is the node whose
	-- part0 is not in the reverse table
	local root = getRoot(bones, reverse)
	if not root then
		-- if there exists no root, then
		-- this was not setup using motor6d
		return order, bones
	end
	
	local queue = Queue.new() :: Queue.Queue<string>
	queue:enqueue(root)

	-- do a DAG on the rig root lol
	while not queue:empty() do
		local part = queue:dequeue()
		local edges = reverse[part]
		
		if not edges then
			-- this means that it doesnt
			-- have an edge
			continue
		end
		
		for i, edge in edges do
			-- insert this bone into the queue
			queue:enqueue(edge)
			table.insert(order, edge)
		end
	end
	
	return order, bones
end

function Animator.getPlayingAnimations(self: Animator)
	return self.animations
end

function Animator.new(rig: Model): Animator
	local order, bones = getRig(rig)
	return setmetatable({
		-- animations and queue
		animations = {},
		queue = {},
		
		-- order, bones
		order = order,
		bones = bones,
	}, Animator)
end

function Animator.loadAnimation(self: Animator, track: AnimationTrack): AnimationPlayback
	return {
		-- weight
		weight = 0.0,
		speedWeight = 0.0,
		targetWeight = 0.0,
		
		-- playback
		timer = 0.0,
		speed = 1.0,
		priority = track.priority,
		
		-- state
		looped = track.looped,
		track = track,
		
		-- config
		additive = false,
		playing = false,
	}
end

function Animator.stopAnimation(
	self: Animator,
	playback: AnimationPlayback,
	fade: number?
)
	local animations = self.animations
	if not playback.playing then
		-- already stopped
		return
	elseif fade == 0.0 then
		-- straight up remove the animation
		local index = table.find(animations, playback)
		assert(index, "playback could not find playback")
		
		table.remove(animations, index)
		playback.weight = 0.0
	else
		-- just fade out weight
		playback.speedWeight = 1.0 / (fade or 0.3)
	end
	
	playback.targetWeight = 0.0
end

function Animator.playAnimation(
	self: Animator,
	playback: AnimationPlayback,
	fade: number?
)
	if playback.playing then
		-- just restart playback because
		-- this is already playing
		playback.timer = 0.0
		return
	end
	
	local animations = self.animations
	local j = #animations
	local i = 1
	
	-- binary search for insertion
	while i < j do
		local center = (i + j) // 2
		if animations[center].priority <= playback.priority then
			i = center + 1
		else
			j = center
		end
	end

	i = math.max(i - 1, 1)
	
	-- add to the animation table
	playback.targetWeight = 1.0
	playback.speedWeight = 1.0 / (fade or 0.3)
	playback.playing = true
	
	playback.timer = 0.0
	table.insert(animations, i, playback)
end

function Animator.updateAnimation(
	self: Animator,
	playback: AnimationPlayback,
	dt: number
)
	-- update scrubber
	local t = playback.timer + dt * playback.speed
	local track = playback.track
	
	local bones = self.bones
	local weight = playback.weight
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
		local finalWeight = if not playback.additive
			then math.min(weight, bone.weight) * boneWeight
			else weight * boneWeight
		
		local costWeight = if not playback.additive
			then finalWeight
			else 0
		
		bone.weight -= costWeight
		bone.cframe = CFrame.identity:Lerp(cframe, finalWeight)
			* bone.cframe
	end

	local length = track.length
	if playback.looped then
		-- loop the animation and
		-- offset the starting time
		t %= length
	elseif t >= length - 0.2 then
		-- make the playback have
		-- no weight
		playback.targetWeight = 0.0
	elseif t < 0.0 then
		-- we have reversed playback,
		-- so we have to go backwards
		t %= length;
	end
	
	playback.timer = t
	playback.weight += math.clamp(
		playback.targetWeight - playback.weight,
		-playback.speedWeight * dt,
		playback.speedWeight * dt
	)
end

function Animator.update(self: Animator, dt: number)
	local queue = self.queue
	for i, animation in self.animations do
		-- update animation
		self:updateAnimation(animation, dt)
		if animation.targetWeight == 0.0
		and animation.weight < EPSILON then
			table.insert(queue, i)
		end
	end
	
	for i = #queue, 1, -1 do
		-- remove the animation
		local id = queue[i]
		local playback = self.animations[id]
		playback.playing = false
		
		table.remove(self.animations, id)
	end
	
	local bones = self.bones
	for i, pose in self.order do
		-- set the bone transform
		local data = bones[pose]
		local bone = data.bone :: any
		
		bone.Transform = data.cframe
		data.cframe = CFrame.identity
		data.weight = 1.0
	end
	
	table.clear(queue)
end

return Animator