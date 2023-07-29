local INITIAL_ENTITY_VERSION = 1
local MAX_ENTITIES = 0x000F_FFFF

local ID_INVALID_KEY = 0
local ID_MAX_INT = 2 ^ 53 - 1
local ID_MASK_KEY = MAX_ENTITIES
local ID_MASK_VER = ID_MAX_INT - ID_MASK_KEY

local ID_LSHIFT = ID_MASK_KEY + 1
local ID_RSHIFT = 1 / ID_LSHIFT

local ID_MAX_KEY = ID_MASK_KEY
local ID_MAX_VERSION = ID_MASK_VER * ID_RSHIFT

local function idCreate(key: number, version: number): number
	--assert(Key <= ID_MAX_Key)
	--assert(ver <= ID_MAX_VERSION)
	return version * ID_LSHIFT + key
end

local function idKey(ID: number): number
	return bit32.band(ID, ID_MASK_KEY)
end

local function idKeyVersion(ID: number): (number, number)
	local key = idKey(ID)
	local ver = (ID - key) * ID_RSHIFT
	return key, ver
end

local function idVersion(ID: number): number
	return (ID - idKey(ID)) * ID_RSHIFT
end

local function idSwapKey(ID: number, key: number): number
	return ID - idKey(ID) + key
end

return {

	INITIAL_ENTITY_VERSION = INITIAL_ENTITY_VERSION,
	MAX_ENTITIES = MAX_ENTITIES,

	ID_INVALID_KEY = ID_INVALID_KEY,

	ID_MAX_KEY = ID_MAX_KEY,
	ID_MAX_VERSION = ID_MAX_VERSION,

	idCreate = idCreate,
	idKey = idKey,
	idKeyVersion = idKeyVersion,
	idVersion = idVersion,
	idSwapKey = idSwapKey,
}
