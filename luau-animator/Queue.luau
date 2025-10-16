--!strict

local Queue = {}
Queue.__index = Queue

export type Queue<T> = typeof(setmetatable({} :: {
	data: { T },
	cursor: number,
}, Queue))

function Queue.new()
	return setmetatable({
		cursor = 0,
		data = {},		
	}, Queue)
end

function Queue.enqueue<T>(self: Queue<T>, what: T)
	table.insert(self.data, what)
end

function Queue.dequeue<T>(self: Queue<T>): T
	return table.remove(self.data) :: T
end

function Queue.empty<T>(self: Queue<T>): boolean
	return #self.data == 0
end

return Queue