--!strict

local Replicator = script.Parent:WaitForChild("Replicator") :: RemoteEvent

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Animator = require("../Animator")
local Buffer = require("./Buffer")

local ClientReplicator = {}
local Actors = {} :: { [number]: Actor }

export type Actor = {
	animator: Animator.Animator,
	clock: number,
	
	previous: { [string]: CFrame },
	targets: { [string]: CFrame },
}

local function createAnimationBuffer(animator: Animator.Animator): buffer
	local length = #animator.order
	local data = Buffer.write(length * 28)
	data:writeU8(length)
	
	-- Roblox did this btw, if you saw the
	-- replicated motor6D transform exploit back then
	for i, name in animator.order do
		local bone = animator.bones[name]
		data:writeString(name)
		data:writeCFrame(bone.transform)
	end
	
	return data:getData()
end

local function waitForAttribute<T>(character: Model, att: string): T
	local value = character:GetAttribute(att)
	if value then
		return value
	end
	
	character:GetPropertyChangedSignal(att):Wait()
	return character:GetAttribute(att)
end

local function createActor(character: Model)
	local id = waitForAttribute(character, "Id")
	Actors[id] = {
		animator = Animator.new(character),
		clock = os.clock(),
		
		previous = {},
		targets = {},
	}
end

local function readAnimationBuffer(
	actor: Actor,
	clock: number,
	data: Buffer.Buffer
)
	local count = data:readU8()
	if actor then
		-- Consume the following fields
		local previous = actor.previous
		local targets = actor.targets
		
		local alpha = math.min(27 * (clock - actor.clock), 1)
		for current, currentCFrame in actor.targets do
			local previousCFrame = actor.previous[current] or currentCFrame
			previous[current] = previousCFrame:Lerp(currentCFrame, alpha)
		end
	
		for i = 1, count do
			local name = data:readString()
			local cframe = data:readCFrame()
			targets[name] = cframe
		end
		
		actor.clock = clock
	else
		-- Skip these fields
		for i = 1, count do
			data:readString()
			data:readCFrame()
		end
	end
end

local function readAnimationTick(raw: buffer)
	-- Reads an animation server tick 
	local data = Buffer.read(raw)
	local count = data:readU32()

	local clock = os.clock()
	for i = 1, count do
		local actor = Actors[data:readU8()]
		readAnimationBuffer(actor, clock, data)
	end
end

local function stepped()
	for _, actor in Actors do
		-- Update according to the tickrate
		local alpha = math.min(27 * (os.clock() - actor.clock), 1)
		local bones = actor.animator.bones
		
		for current, currentCFrame in actor.targets do
			local previousCFrame = actor.previous[current] or currentCFrame
			local bone = (bones[current].bone :: Motor6D)
			bone.Transform = previousCFrame:Lerp(currentCFrame, alpha)
		end
	end
end

-- Connections
for _, character in CollectionService:GetTagged("Animator") do
	task.defer(createActor, character)
end

RunService.Stepped:Connect(stepped)
Replicator.OnClientEvent:Connect(readAnimationTick)
CollectionService:GetInstanceAddedSignal("Animator"):Connect(createActor)

return function(character: Model)
	local animator = Animator.new(character)
	local connections

	local stepped = 0.0
	connections = {
		RunService.Stepped:Connect(function(_, dt: number)
			stepped += dt
			animator:StepAnimations(dt)
			if stepped < 1/30 then
				return
			end

			stepped %= 1/30
			Replicator:FireServer(createAnimationBuffer(animator))
		end),

		character.Destroying:Once(function()
			for i, connection in connections do
				connection:Disconnect()
			end

			animator:Destroy()
		end)
	}
	
	-- Wait until we have the attribute
	-- and wait for it on the actor side
	local id = waitForAttribute(character, "Id")
	while not Actors[id] do
		task.wait()
	end
	
	-- Removes that race condition :<
	Actors[id] = nil
	
	return animator
end