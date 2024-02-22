debug.setmemorycategory("overlap")

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Overlap = {}

local Signals = require(script.Signals)

export type OverlapData = {
   BasePart: BasePart,
   HitBoxSize: Vector3,
   Paramters: OverlapParams
}


local function visible(cframe, size)
   local debug = Instance.new("Part")

   debug.Size = size
   debug.Anchored = true
   debug.Transparency = .6
   debug.CanCollide = false
   debug.CanQuery = false
   debug.CanTouch = false
   debug.BrickColor = BrickColor.Red()
   debug.CFrame = cframe
   debug.Parent = workspace

   Debris:AddItem(debug, .02)
end

local function selectHumanoid(list: {[any]: BasePart}): Humanoid
   for _, part in list do
      local modelAncestor = part:FindFirstAncestorOfClass("Model")
      if modelAncestor then
         local humanoid = modelAncestor:FindFirstChildWhichIsA("Humanoid", true)
         if humanoid then
            return humanoid 
         end
      end
   end
end

function Overlap.new(overlapData: OverlapData)
   assert(typeof(overlapData) == "table", "overlap data is invalid")
   assert(typeof(overlapData.BasePart) == "Instance", `Base part<Instance> was not valid {typeof(overlapData.BasePart)}`)
   assert(typeof(overlapData.BasePart:IsA("BasePart")), `Base part<Instance> was not valid {typeof(overlapData.BasePart)}`)
   assert(typeof(overlapData.HitBoxSize) == "Vector3", `Vector3 was expected on HitBoxSize, got {typeof(overlapData.HitBoxSize)}`)
   assert(typeof(overlapData.Paramters) == "OverlapParams", `Invalid overlap paramters`)

   local object = {
      Paramters = nil,
      OnHit = Signals.new("OverlapHitted") :: Signals.Signal,
      Destroyed = Signals.new("OverlapRemoved") :: Signals.Signal, 
      Visible = false,
      overlapData = overlapData :: OverlapData
   }

   return setmetatable(object, {__index = Overlap, __tostring = function()
      return "OverlapObject"
   end})
end

--[=[
   Start the hitbox

   @param duration: number -- duration in secs of your hitbox colision
]=]
function Overlap:HitStart(duration: number)
   assert(duration, "duration<number> was expected")
   assert(typeof(duration) == "number", "duration is not a number")

   local overlap = self :: typeof(Overlap.new())
   local start = os.clock()

   local BasePartDestroyed;

   local RunningThread; RunningThread = RunService.Heartbeat:Connect(function()
      if not overlap.overlapData.BasePart.Parent then 
         RunningThread:Disconnect()
         BasePartDestroyed:Disconnect()
         return
      end
      if (os.clock() - start) >= duration then BasePartDestroyed:Disconnect() RunningThread:Disconnect() end
      local position = overlap.overlapData.BasePart.CFrame
      local size = overlap.overlapData.HitBoxSize

      local result = workspace:GetPartBoundsInBox(
         position,
         size,
         overlap.overlapData.Paramters
      )
      if overlap.Visible then
         task.spawn(visible, position, size)
      end

      if result then
         local humanoid = selectHumanoid(result)
         if not humanoid then return end
         overlap.OnHit:Fire(humanoid)
         
         overlap.Destroyed:Fire()
         RunningThread:Disconnect()
         BasePartDestroyed:Disconnect()
      end
   end)

   BasePartDestroyed = overlap.overlapData.BasePart.Destroying:Once(function()
      if RunningThread.Connected then
         overlap.Destroyed:Fire()
         RunningThread:Disconnect()
      end
   end)

   self.RunningThread = RunningThread
   self.BasePartDestroyed = BasePartDestroyed
end

--[=[
   From run, if your want to resize your hitbox when is running
   
   Example
   ```lua
      local Overlap = Overlap.new(OverlapData)

      Overlap:FromRun(OverlapData.HitBoxSize+Vector3.new(10,10,10))
   ```
]=]
function Overlap:FromRun(hitBoxGoal: Vector3?)
   local overlap = self :: typeof(Overlap.new())
   local BasePartDestroyed;

   hitBoxGoal = hitBoxGoal or self.overlapData.HitBoxSize
   local time = 0

   local RunningThread; RunningThread = RunService.Heartbeat:Connect(function(delta)
      local position = overlap.overlapData.BasePart.CFrame
      local size = overlap.overlapData.HitBoxSize:Lerp(hitBoxGoal, math.min(time + delta, 1))
      
      local result = workspace:GetPartBoundsInBox(
         position,
         size,
         overlap.overlapData.Paramters
      )
      if overlap.Visible then
         task.spawn(visible, position, size)
      end

      if result then
         local humanoid = selectHumanoid(result)
         if not humanoid then return end
         overlap.OnHit:Fire(humanoid)
         
         RunningThread:Disconnect()
         BasePartDestroyed:Disconnect()
      end
   end)

   BasePartDestroyed = overlap.overlapData.BasePart.Destroying:Once(function()
      if RunningThread.Connected then
         RunningThread:Disconnect()
      end
   end)

   self.RunningThread = RunningThread
   self.BasePartDestroyed = BasePartDestroyed
end

--[=[
   Stop the runnin thread
]=]
function Overlap:Stop()
   if self.RunningThread.Connected then self.RunningThread:Disconnect() end
   if self.BasePartDestroyed.Connected then self.BasePartDestroyed:Disconnect() end
end

--[=[
   Destroy your object and connections
]=]
function Overlap:Destroy()
   setmetatable(self, nil)
   table.clear(self)
end

return Overlap