local World = if game then require(script.World) else require("src/World/init") :: never
local Id = if game then require(script.World.Id) else require("src/World/Id") :: never

local arch = {

	World = World,

	extract = Id.idKeyVersion,
};

-- debug functions
(arch :: any).id = Id.createId

return arch
