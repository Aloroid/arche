local INITIAL_ENTITY_VERSION = 1
local MAX_ENTITIES = 0x000F_FFFF

local ID_INVALID_INDEX = 0
local ID_MAX_INT = 2 ^ 53 - 1
local ID_MASK_INDEX = MAX_ENTITIES
local ID_MASK_VER = ID_MAX_INT - ID_MASK_INDEX

local ID_LSHIFT = ID_MASK_INDEX + 1
local ID_RSHIFT = 1 / ID_LSHIFT

local ID_MAX_INDEX = ID_MASK_INDEX
local ID_MAX_VERSION = ID_MASK_VER * ID_RSHIFT

local function createId(index: number, version: number): number
	--assert(INDEX <= ID_MAX_INDEX)
	--assert(ver <= ID_MAX_VERSION)
	return version * ID_LSHIFT + index
end

local function idIndex(ID: number): number
	return bit32.band(ID, ID_MASK_INDEX)
end

local function idIndexVersion(ID: number): (number, number)
	local index = idIndex(ID)
	local ver = (ID - index) * ID_RSHIFT
	return index, ver
end

local function idVersion(ID: number): number
	return (ID - idIndex(ID)) * ID_RSHIFT
end

local function idSwapIndex(ID: number, index: number): number
	return ID - idIndex(ID) + index
end

return {

	INITIAL_ENTITY_VERSION = INITIAL_ENTITY_VERSION,
	MAX_ENTITIES = MAX_ENTITIES,

	ID_INVALID_INDEX = ID_INVALID_INDEX,

	ID_MAX_INDEX = ID_MAX_INDEX,
	ID_MAX_VERSION = ID_MAX_VERSION,

	createId = createId,
	idIndex = idIndex,
	idIndexVersion = idIndexVersion,
	idVersion = idVersion,
	idSwapIndex = idSwapIndex,
}
