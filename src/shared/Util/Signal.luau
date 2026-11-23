--!strict
-- Minimal synchronous signal (no BindableEvent, so no serialization cost and tables pass by reference).
export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [any]: (...any) -> () } }, Signal)
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local conn = { Connected = true }
	function conn.Disconnect(c)
		c.Connected = false
		self._handlers[c] = nil
	end
	self._handlers[conn] = fn
	return conn :: any
end

function Signal.Fire(self: any, ...: any)
	for conn, fn in self._handlers do
		if conn.Connected then
			task.spawn(fn, ...)
		end
	end
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

return Signal
