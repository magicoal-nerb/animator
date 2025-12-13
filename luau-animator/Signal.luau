--!strict

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (this: Connection) -> () }
export type Dispatcher<T...> = (T...) -> ()
export type Signal<T...> = typeof(setmetatable({} :: {
	tasks: { [Dispatcher<T...>]: boolean }
}, Signal))

function Signal.new<T...>()
	return setmetatable({
		tasks = {}
	}, Signal)
end

function Signal.Fire<T...>(
	self: Signal<T...>,
	...: any
)
	for fn in self.tasks do
		task.defer(fn, ...)
	end
end

function Signal.Connect<T...>(
	self: Signal<T...>,
	fn: Dispatcher<T...>
): Connection
	self.tasks[fn] = true
	
	local function disconnect(this: Connection)
		self.tasks[fn] = nil
	end

	return {
		Disconnect = disconnect,
		disconnect = disconnect,
	}
end

Signal.connect = Signal.Connect

return Signal