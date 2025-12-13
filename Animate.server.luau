--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimatorPackage = require(ReplicatedStorage["luau-animator"])

export type Animator = AnimatorPackage.Animator

local createAnimator = AnimatorPackage.createAnimator

-- Animate.lua
-- magicoal_nerb/poopbarrel :3

local AnimateScriptKeymap: {[string]: string} = {
	Climbing = "climb",
	Freefall = "fall",
	Running = "run",
	Jumping = "jump",
	Seated = "sit",
	Idle = "idle",

	ToolNone = "toolnone",
	ToolSlash = "toolslash",
	ToolLunge = "toollunge",
}

local AnimationKeymap = {
	[Enum.HumanoidStateType.Jumping] = "Jumping",
	[Enum.HumanoidStateType.Seated] = "Seated",
}

local ToolKeymap: { [string]: string } = {
	slash = "ToolSlash",
	lunge = "ToolLunge",
	none = "ToolNone",
}

local Animate = {}
Animate.__index = Animate

export type Animate = typeof(setmetatable({} :: {
	humanoid: Humanoid,
	character: Model,
	animator: Animator,

	animations: {[string]: AnimationTrack},
	connections: {RBXScriptConnection},

	toolAnimation: RBXScriptConnection?,
	heightScale: number,

	previousAnimation: AnimationTrack?,
	currentState: Enum.HumanoidStateType,

	tool: Tool?,
}, Animate))

local function waitForChildOfClass(inst: Instance, class: string): Instance
	local child = inst:FindFirstChildOfClass(class)
	while not child do
		inst.ChildAdded:Wait()
		child = inst:FindFirstChildOfClass(class)
	end

	return child
end

function Animate.new(character: Model): Animate
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = createAnimator(character)
		
	return setmetatable({
		animations = {},
		connections = {},

		heightScale = 1.0,
		character = character,
		humanoid = humanoid,
		animator = animator,

		currentState = Enum.HumanoidStateType.Physics,
	}, Animate):ready()
end

function Animate.getCurrentAnimation(self: Animate): string
	-- Gets the current animation name.
	if not self.previousAnimation then
		return "<error animation>"
	end

	return self.previousAnimation.Name
end

function Animate.ready(self: Animate): Animate
	-- Loads new animation tracks for players.
	local animations = {}

	-- Use the player's R15 animation packages
	-- instead.
	local animate = self.character:FindFirstChild("Animate") :: LocalScript
	assert(animate)

	local scaleDampening = animate:FindFirstChild("ScaleDampeningPercent") :: NumberValue
	if scaleDampening then
		-- This happens in R15 rigs, where the running animation scales
		-- with respect to the avatar's height.
		local scale = self.humanoid.HipHeight * 0.5
		local percent = scaleDampening.Value

		local heightScale = 1 + (self.humanoid.HipHeight - 2) * (percent * 0.5)
		self.heightScale = heightScale * self.character:GetScale()
	end

	for name, path in AnimateScriptKeymap do
		if path:find("://") then
			-- It's a separate animation
			local animation = Instance.new("Animation")
			animation.AnimationId = path
			animation.Name = path
			animation.Parent = self.character

			local track = self.animator:LoadAnimation(animation)
			track.Priority = Enum.AnimationPriority.Action2
			track.Looped = true

			-- Remove the animation object once we're done
			-- loading it in
			animation:Destroy()
			animations[name] = track
		else
			-- It's within the datamodel
			local root: Instance = animate
			for word in path:gmatch("[^/]+")do
				root = root:WaitForChild(word)
				if not root then
					break
				end
			end

			if not root then
				continue
			end

			root = waitForChildOfClass(root, "Animation") :: Animation
			assert(root, `{path} expected Animation. Got nil`)

			local track = self.animator:LoadAnimation(root :: Animation)
			assert(track)
			
			track.Name = name
			track.Looped = true
			animations[name] = track
		end
	end

	for prefix, name in ToolKeymap do
		-- make these the highest priority
		local animation = animations[name]
		if not animation then
			continue
		end

		animation.Priority = if prefix == "none"
			then Enum.AnimationPriority.Action2
			else Enum.AnimationPriority.Action4
		animation.Looped = prefix == "none"
	end

	self.animations = animations
	self.connections = {
		-- Other miscellaneous stuff
		self.humanoid.StateChanged:Connect(function(old, new)
			self:stateChanged(old, new)
		end),

		self.humanoid.Died:Once(function()
			self:Destroy()
		end),

		self.humanoid.Climbing:Connect(function(speed: number)
			self:climbingChanged(speed)
		end),

		self.humanoid.Running:Connect(function(speed: number)
			self:runningChanged(speed)
		end),

		self.character.Destroying:Connect(function()
			self:Destroy()
		end),

		-- Tool animations
		self.character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.RequiresHandle then
				self:toolEquipped(child)
			end
		end),

		self.character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child.RequiresHandle then
				self:toolUnequipped(child)
			end
		end),
	}

	-- Keep it disabled
	local playEmote = animate:WaitForChild("PlayEmote") :: BindableFunction
	if playEmote then
		self:bindEmotes(playEmote)
	end

	return self
end

function Animate.playEmote(self: Animate, track: Animation): boolean
	if not track then
		-- The track didn't exist!
		return false
	end

	local name = track.AnimationId
	if not self.animations[name] then
		-- The animation wasn't initialized yet, so we
		-- have to load it in
		self.animations[name] = self.animator:LoadAnimation(track)
	end

	self:playAnimation(name, 0.2)
	return true
end

function Animate.bindEmotes(self: Animate, playEmote: BindableFunction)
	local description = assert(self.humanoid:FindFirstChildOfClass("HumanoidDescription"))
	local emotes = description:GetEmotes()

	function playEmote.OnInvoke(track: Animation)
		return self:playEmote(track)
	end
end

function Animate.toolEquipped(self: Animate, tool: Tool)
	if self.toolAnimation then
		self.toolAnimation:Disconnect()
	end

	-- Play the toolnone animation.
	self.tool = tool
	self.animations.ToolNone:Play(0.2)
	self.toolAnimation = tool.ChildAdded:Connect(function(object: Instance)
		if object.Name ~= "toolanim"
			or not object:IsA("StringValue") then
			return
		end

		local value = object.Value:lower()
		local anim = self.animations[ToolKeymap[value]]
		anim:Play(0)

		task.defer(object.Destroy, object)
		task.wait(0.2)
		anim:Stop(0.1)
	end)
end

function Animate.toolUnequipped(self: Animate, tool: Tool)
	-- Remove the tool animation connection.
	if self.tool ~= tool then
		return
	elseif not self.toolAnimation then
		return
	end

	self.tool = nil
	self.toolAnimation = self.toolAnimation:Disconnect()
	self.animations.ToolNone:Stop()
end

function Animate.playAnimation(self: Animate, name: string, fadeTime: number)
	assert(self.animations[name], `Animation '{name}' doesn't exist!`)

	local previous = self.previousAnimation
	local current = self.animations[name]
	if previous and previous ~= current then
		previous:Stop(fadeTime)
	elseif previous == current and (previous :: AnimationTrack).IsPlaying then
		-- Don't replay the animation. It automatically
		-- loops for you.
		return
	end

	current:Play(fadeTime)
	self.previousAnimation = current
end

function Animate.adjustSpeed(self: Animate, speed: number)
	-- Adjust the current animation if it is
	-- playing.
	if self.previousAnimation then
		self.previousAnimation:AdjustSpeed(speed)
	end
end

function Animate.runningChanged(self: Animate, speed: number)
	if speed > 0.1 then
		-- Player is moving.
		local speedScale = (speed / 16) * 1.25
		self:playAnimation("Running", 0.2)
		self:adjustSpeed(speedScale / self.heightScale)
	else
		-- Player is not moving.
		self:playAnimation("Idle", 0.2)
	end
end

function Animate.climbingChanged(self: Animate, speed: number)
	-- Player is climbing
	speed /= self.heightScale

	self:playAnimation("Climbing", 0.1)
	self:adjustSpeed(speed / 5)
end

function Animate.stateChanged(
	self: Animate,
	old: Enum.HumanoidStateType,
	new: Enum.HumanoidStateType
)
	local keymap = AnimationKeymap[new]
	if keymap then
		-- Generic keymap, the majority of states use
		-- this.
		self:playAnimation(keymap, 0.2)
	elseif new == Enum.HumanoidStateType.Freefall then
		-- We wait for the jump delay to finish, and we will determine
		-- if we are able to play the freefall animation.
		task.wait(0.3)

		local animation = self:getCurrentAnimation()
		if self.humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			return
		end

		self:playAnimation("Freefall", 0.3)
	end

	self.currentState = new
end

function Animate.Destroy(self: Animate)
	-- Remove tool animation bug
	if self.toolAnimation then
		self.toolAnimation = self.toolAnimation:Disconnect()
	end

	-- Remove connections and animations from memory.
	for _, connection in self.connections do
		connection:Disconnect()
	end

	for _, animation in self.animations do
		animation:Stop()
		animation:Destroy()
	end

	-- Clear and freeze so we don't accidentally
	-- use this anymore
	table.clear(self :: any)
	table.freeze(self :: any)
end

return Animate.new(script.Parent)