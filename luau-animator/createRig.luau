local Queue = require("./Queue")

export type BoneInstance = Motor6D | Bone
export type RigBone = {
	-- cframe
	cframe: CFrame,

	-- weight
	weight: number,
	
	-- transform
	transform: CFrame,

	-- bone of the thing i guess
	bone: BoneInstance,
}

local function getRoot(front: { [string]: RigBone }, reverse: { [string]: { string } }): string?
	-- the difference between the sets reverse and front
	-- is that the root part is the only element in the set
	for part in reverse do
		if not front[part] then
			return part
		end
	end

	return nil
end

return function(rig: Model)
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

				-- transform
				transform = CFrame.identity,
				
				-- weight
				weight = 1.0,

				-- bone of the thing i guess
				bone = bone,
			}
		elseif bone:IsA("Motor6D") then
			-- Check the bones parts
			if not bone.Part0 then
				continue
			elseif not bone.Part1 then
				continue
			end

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
				
				-- transform
				transform = CFrame.identity,
				c0 = bone.C0,

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
