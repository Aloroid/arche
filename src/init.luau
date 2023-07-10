local World = if game
	then require(script.World)
	else require("src/World/init") :: never
local Component = if game
	then require(script.Components)
	else require("src/Components") :: never
local Id = if game
	then require(script.World.Id)
	else require("src/World/Id") :: never

local arch = {

	World = World.new,
	component = Component.new,

	extract = Id.idIndexVersion,
};

-- debug functions
(arch :: any).id = Id.createId

return arch
