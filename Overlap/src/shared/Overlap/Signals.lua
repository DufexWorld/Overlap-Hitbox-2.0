--[=[
	@class Connection
	
	A class that represents a listener of Signals, returned by Signal:Connect() and Signal:Once().
	Useful to handle if callback will be called or not.
]=]
local Connection = {}

function Connection.new(signal: Signal, callback: (...any) -> any...)
	
	local meta = { __metatable = "locked", __call = callback }
	local self = setmetatable({}, meta)
	
	--[=[
		@within Connection
		@prop IsConnected boolean
		
		Determine if connection is connected or not
	]=]
	self.IsConnected = true
	
	--[=[
		@within Connection
		@method Disconnect
		
		Does the callback stop to be called when signal has fired.
	]=]
	function self:Disconnect()
		
		self.IsConnected = false
		signal:_remove(self)
	end
	
	--[=[
		@within Connection
		@method Reconnect
		
		Does the callback begin to be called when signal has fired.
	]=]
	function self:Reconnect()
		
		self.IsConnected = true
		signal:_add(self)
	end
	
	--// Behaviour
	function meta:__tostring()
		
		return `Connection({if self.IsConnected then "connected" else "disconnected"} to '{signal:GetFullName()}')`
	end
	
	--// End
	return self
end

--[=[
	@class Signal
	A class that represents a emitter.
	Useful to does things happen when its fired.
]=]
local Signal = {}
local signals = {}

--[=[
	@within Signal
	@function wrap
	@param bindableEvent BindableEvent
	@return Signal
	
	Wraps the bindableEvent with a Signal instance
]=]
function Signal.wrap(bindableEvent: BindableEvent)
	
	local meta = { __metatable = "locked" }
    local self = setmetatable({ roblox = bindableEvent }, meta)
	
	local event = bindableEvent.Event
	local connections = {}
	local data = {}
	
	--[=[
		@within Signal
		@method Connect
		@param callback function	-- function called when signal fired
		@return Connection		-- object to handle the callback, like disconnect the callback or reconnect
		
		Create a listener/observer for signal.
		Useful to bind and unbind functions to some emitter, which can be fired when something happens during game.
	]=]

	function self:Connect(callback: (...any) -> ()): Connection
		
		local connection = Connection.new(connections, callback)
		connections[connection] = callback
		
		return connection
	end

	--[=[
		@within Signal
		@method Once
		@param callback function	-- function called when signal fired
		@return Connection		-- object to handle the callback, like disconnect the callback or reconnect
		
		Create a listener/observer for signal.
		Like Signal:Connect, but the connection is :Disconnect()'ed after triggered, but can be :Reconnect()'ed multiple times.
	]=]
	
	function self:Once(callback: (...any) -> ()): Connection
		
		local connection; connection = self:Connect(function(...)
			
			callback(...)
			connection:Disconnect()
		end)
		
		return connection
	end
	
	--[=[
		@within Signal
		@method AwaitWithinTimeout
		
		Wait until the signal was fired within a given timeout, and returns your data if signal was fired before timeout.
		Useful to wait some event without blocking infinitely the coroutine. Such wait some client response.
	]=]
	function self:AwaitWithinTimeout(timeout: number): any...
		
		local thread = coroutine.running()
		local alreadyFired = false
		
		task.delay(timeout, function()
			
			if alreadyFired then return end
			coroutine.resume(thread)
		end)
		
		event:Wait()
		alreadyFired = true
		
		return unpack(data)
	end
	--[=[
		@within Signal
		@method Await
		
		Wait until the signal was fired and returns your data.
	]=]
	function self:Await(): any...
		
		event:Wait()
		return unpack(data)
	end
	
	--[=[
		@within Signal
		@method _tryEmit
		@param data any...
		@return boolean -- if havent any error on any listener
		
		Call all connected listeners within pcall, then return if the operation has been succeeded.
		This has made thinking in listeners which can cancel the operation.
	]=]
	function self:_tryEmit(...: any): boolean
		
		return pcall(self._emit, self,...)
	end
	--[=[
		@within Signal
		@method _emit
		@param data any...
		
		Call all connected listeners.
	]=]
	function self:fire(...: any)
		
		for connection, callback in connections do
			
			callback(...)
		end
        
        data = {...}
        bindableEvent:Fire()
		data = {}
	end
	self.Fire = self.fire
	--[=[
		@within Signal
		@method _disconnectAll
		
		Does :Disconnect() in all listeners.
	]=]
	function self:_disconnectAll()
		
		for connection in connections do connection:Disconnect() end
	end
	function self:_remove(connection: Connection)
		
		connections[connection] = nil
	end
	function self:_add(connection: Connection)
		
		connections[connection] = true
	end
	
	--// Behaviours
	function self:__tostring()
		
		return `Signal('{bindableEvent:GetFullName()}')`
	end
	
	--// Listeners
	bindableEvent.Destroying:Connect(function()
        
        local label = tostring(self)
        self:_disconnectAll()
		
        task.wait()
        table.clear(self)
        
        function meta:__newindex(index: string, value: any)
            
            error(`attempt to write '{index}' to {value} on {self}`)
        end
        function meta:__index(index: string)
            
            error(`attempt to read '{index}' on {self}`)
        end
        function meta:__tostring()
            
            return `destroyed {label}`
        end
	end)
	
	--// End
	signals[bindableEvent] = self
	return self
end
--[=[
	@within Signal
	@function new
	@param name string
	@return Signal
	
	Creates a new bindable with given name, then wraps it with Signal
]=]
function Signal.new(name: string): Signal
	
	local bindableEvent = Instance.new("BindableEvent")
	bindableEvent.Name = name
	
	return Signal.wrap(bindableEvent)
end

--[=[
	@within Signal
	@function find
	@param bindableEvent BindableEvent
	@return Signal?
	
	Find the signal which is wrapping given bindableEvent, if not finded, will be returned nil
]=]
function Signal.find(bindableEvent: BindableEvent): Signal?

	return signals[bindableEvent]
end

--// End
export type Connection = typeof(Connection.new())
export type Signal<Data...> = typeof(Signal.new()) & {
	Connect: (self: any, callback: (...any) -> ()) -> Connection,
	Once: (self: any, callback: (...any) -> ()) -> Connection,
	Wait: () -> ...any,
	AwaitWithinTimeout: (self: any, timeout: number) -> ...any,
}
return Signal