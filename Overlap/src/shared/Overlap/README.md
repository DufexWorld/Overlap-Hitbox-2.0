# Modulo criado por Dufex

*Como usar?*

```lua
--Client

--Dando require no module para usar o serviço
local Overlap = require(ReplicatedStorage.Overlap)

--Criando o overlapParams
local PunchOverlapParams = OverlapParams.new()
PunchOverlapParams.FilterDescendantsInstances = {Player.Character}
PunchOverlapParams.MaxParts = 3

local OverlapData: Overlap.OverlapData = {
   BasePart = Player.Character.HumanoidRootPart, -- Usando a humanoid root part como base para colisão
   Paramters = PunchOverlapParams, -- Paramters recebe OverlapParams
   HitBoxSize = Vector3.new(4,4,4) -- Tamanho da hitbox
}
local PlayerPunchColision = Overlap.new(OverlapData)

--Caso queira deixar sua colisão visivel faça
PlayerPunchColision.Visible = true

--Supondo que toda vez que você de um soco queira que ele dure alguns segundos da animação conforme a colisão.

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
   if gameProcessed then return end

   if input.UserInputType == Enum.UserInputType.MouseButton1 then
      PlayerPunchColision:HitStart(1) -- Ele vai rodar o overlap por 1 segundo
      --caso colida em algo ele vai disparar o signal<OnHit>
      --em caso de colisão antes do fim da duração(1 segundo), ele vai parar a colisão automaticamente.
   end
end)

PlayerPunchColision.OnHit:Connect(function(Humanoid: Humanoid)
   --o signal só é disparado se bater em algo com humanoid.
   Humanoid:TakeDamage(10)
end)

--Caso queira destruir a colisão é simples
PlayerPunchColision:Destroy()