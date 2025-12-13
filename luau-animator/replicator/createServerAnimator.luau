--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Animator = require("../Animator")
local Buffer = require("./Buffer")

local Replicator = Instance.new("RemoteEvent")
Replicator.Name = "Replicator"
Replicator.Parent = script.Parent

local ServerAnimator = {}
ServerAnimator.buffers = {} :: { [number]: buffer }
ServerAnimator.actors = {} :: { [number]: boolean }
ServerAnimator.timestamp = 0.0
ServerAnimator.cursor = 0

local function getFreeIndex(): number
	-- Finds a potential index candidate thx :D
	while ServerAnimator.actors[ServerAnimator.cursor] do
		ServerAnimator.cursor = bit32.band(ServerAnimator.cursor + 1, 0xFF)
	end
	
	return ServerAnimator.cursor	
end

local function characterAdded(character: Model)
	-- Character added, animator added
	local index = getFreeIndex()
	ServerAnimator.actors[index] = true
	
	character:SetAttribute("Id", index)
	character:AddTag("Animator")
	
	character.Destroying:Once(function()
		ServerAnimator.actors[index] = nil
	end)
end

local function playerAdded(player: Player)
	if player.Character then
		characterAdded(player.Character)
	end
	
	player.CharacterAdded:Connect(characterAdded)
end

local function processClientTick(client: Player, raw: buffer)
	-- Read the buffer and if we can properly access it,
	-- it is a behaving buffer
	local data = Buffer.read(raw)
	local count = data:readU8()
	for i = 1, count do
		-- Try reading the CFrame data
		data:readString()
		data:readCFrame()
	end
	
	assert(data:eof(), "Buffer is not at the end")
	
	local character = client.Character
	assert(character)
	
	ServerAnimator.buffers[character:GetAttribute("Id")] = raw
end

local function step()
	local clock = os.clock()
	if not next(ServerAnimator.buffers, nil) then
		return
	elseif clock - ServerAnimator.timestamp < 1 / 30 then
		return
	end
	
	-- Set the timestamp
	ServerAnimator.timestamp = clock
	
	-- Create the animation snapshot
	local data = Buffer.write(4)
	data:writeU32(0)
	
	local count = 0
	for id, raw in ServerAnimator.buffers do
		count += 1
		data:writeU8(id)
		data:writeBuffer(raw)
	end
	
	-- Send to everyone!! :3
	local output = data:getData()
	buffer.writeu32(output, 0, count)
	
	Replicator:FireAllClients(output)
end

-- Connections
for i, player in Players:GetPlayers() do
	task.defer(playerAdded, player)
end

Replicator.OnServerEvent:Connect(processClientTick)
Players.PlayerAdded:Connect(playerAdded)
RunService.Heartbeat:Connect(step)

return function(character: Model)
	-- TODO: make server side animator objects lol
	return Animator.new(character)
end