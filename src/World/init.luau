local Id = if game then require(script.Id) else require("src/World/Id") :: never

type Array<T> = { [number]: T }
type Map<T, U> = { [T]: U }

type Entity<T = unknown> = number -- entities are components
type EntityKey = number
type EntityVersion = number
type CType<T = unknown> = number
type Index = number

type Components = Map<CType, Array<Archetype>>

type Archetype = {
	size: number,

	values: Map<CType, Map<Index, unknown>>,
	sorted: Array<CType>,
	index: Array<CType>,

	fastAdd: Map<CType, Archetype>,
	fastRemove: Map<CType, Archetype>,
}
type ArchetypeIndex = {
	archetype: Archetype?,
	[number]: ArchetypeIndex,
}

--FIXME: Need Roblox to implement a Partial type instead so this can be shortened
type Query<A, B, C, D, E, F, G, H> = {

	exclude: (Query<A, B, C, D, E, F, G, H>, ...CType) -> Query<A, B, C, D, E, F, G, H>,
	each: (Query<A, B, C, D, E, F, G, H>) -> () -> (A, B, C, D, E, F, G, H),
}

type GetCall = <A, B, C, D, E, F, G, H>(
	World,
	id: Entity,
	CType<A>,
	CType<B>?,
	CType<C>?,
	CType<D>?,
	CType<E>?,
	CType<F>?,
	CType<G>?,
	CType<H>?
) -> (A, B, C, D, E, F, G, H)

type QueryCall = <A, B, C, D, E, F, G, H>(
	World,
	id: Entity,
	CType<A>,
	CType<B>?,
	CType<C>?,
	CType<D>?,
	CType<E>?,
	CType<F>?,
	CType<G>?,
	CType<H>?
) -> Query<A, B, C, D, E, F, G, H>

type Signal<T...> = {
	connect: (Signal<T...>, listener: (T...) -> ()) -> { disconnect: (_: any?) -> () },
}

export type World = {

	create: (World) -> number,
	component: <T>(World, constructor: (() -> T)?) -> CType<T>,
	contains: (World, id: Entity) -> (boolean, boolean),
	current: (World, id: Entity) -> number,

	get: GetCall,
	tryGet: <T>(World, id: Entity, component: CType<T>) -> T?,
	has: (World, id: Entity, ...CType) -> boolean,

	set: <T>(World, id: Entity, component: CType<T>, value: T?) -> T,
	addArchetype: (World, id: Entity, ...CType) -> <T>(ctype: CType<T>, value: T) -> (),
	remove: (World, id: Entity, ...CType) -> (),

	destroy: (World, id: Entity) -> (),
	clear: (World, ...CType) -> (),

	query: QueryCall,

	added: <T>(World, ctype: CType<T>) -> Signal<Entity, T>, -- when a new value is added
	changing: <T>(World, ctype: CType<T>) -> Signal<Entity, T>, -- fires before value is updated, old value is readable
	removing: (World, ctype: CType) -> Signal<Entity>, -- fires before a component is removed
}

local createId = Id.createId
local idKey = Id.idKey
local idKeyVersion = Id.idKeyVersion
local idVersion = Id.idVersion

local INITIAL_ENTITY_VERSION = Id.INITIAL_ENTITY_VERSION
local INVALID_ENTITY = Id.ID_INVALID_KEY
local MAX_VERSION = Id.ID_MAX_VERSION
local MAX_KEY = Id.ID_MAX_KEY

-- inlines better haha
local function setValuesAndComponents(sorted: Array<CType>, components: Components, archetype)
	local values = {}
	for _, ctype in sorted do
		values[ctype] = {}
		if components[ctype] == nil then components[ctype] = {} end
		table.insert(components[ctype], archetype)
	end
	return values
end

local function createArchetype(
	archetypeIndex: ArchetypeIndex,
	components: Components,
	sorted: { CType }
): (Archetype, ArchetypeIndex)
	-- creates a new archetype
	local archetype = {
		size = 0,
		sorted = sorted,
		index = {},
		fastAdd = {},
		fastRemove = {},
	}

	archetype.values = setValuesAndComponents(sorted, components, archetype)
	archetypeIndex.archetype = archetype

	return archetype, archetypeIndex
end

local function findArchetype(current: ArchetypeIndex, components: Components, sorted: { CType })
	local previous = nil
	for _, ctype in sorted do
		if previous == ctype then continue end
		local archetypeIndex = current[ctype]

		-- creates a new entry for a archetype index.
		if archetypeIndex == nil then
			archetypeIndex = {}
			current[ctype] = archetypeIndex
		end

		previous = ctype
		current = archetypeIndex
	end
	return current
end

-- getting archetypes is expensive! try to not use this function.
-- now inlined!
local function getArchetype(
	components: Components,
	storage: ArchetypeIndex,
	ctypes: { CType }
): (Archetype, ArchetypeIndex)
	local sorted = ctypes
	table.sort(sorted)

	local current = findArchetype(storage, components, sorted)

	-- creates a new archetype
	if current.archetype then return current.archetype, current end
	local archetype, index = createArchetype(current, components, sorted)
	return archetype, index
end

local function getNewArchetypeAdd(
	components: Components,
	storage: ArchetypeIndex,
	archetype: Archetype,
	...: CType
): Archetype
	local current = archetype
	for i = 1, select("#", ...) do
		local ctype: CType = select(i, ...)

		local new = current.fastAdd[ctype]
		if new == nil then
			new = getArchetype(components, storage, { ctype, unpack(current.sorted) })
			current.fastAdd[ctype] = new
		end

		current = new
	end

	return current
end

local function getNewArchetypeRemove(
	components: Components,
	storage: ArchetypeIndex,
	archetype: Archetype,
	...: CType
): Archetype
	local current = archetype
	for i = 1, select("#", ...) do
		local ctype: CType = select(i, ...)

		local new = current.fastRemove[ctype]
		if current.values[ctype] == nil then
			continue
		elseif new == nil then -- slow :(
			local cts = table.clone(current.sorted)
			table.remove(cts, table.find(cts, ctype))
			new = getArchetype(components, storage, cts)
			current.fastRemove[ctype] = new
		end

		current = new
	end

	return current
end

-- swaps a archetype
local function swapArchetypeAdd(archetype: Archetype, newArchetype: Archetype, index: Index, id: Entity)
	if archetype == newArchetype then return index end
	newArchetype.size += 1

	local newValues = newArchetype.values
	local newIndex = newArchetype.size

	for ctype, values in archetype.values do
		newValues[ctype][newIndex] = values[index]
		values[index] = nil
	end

	newArchetype.index[newIndex] = id
	archetype.index[index] = nil
	return newIndex
end

local function swapArchetypeRemove(archetype: Archetype, newArchetype: Archetype, index: Index, id: Entity)
	if archetype == newArchetype then return index end
	newArchetype.size += 1

	local values = archetype.values
	local newIndex = newArchetype.size

	for ctype, newValues in newArchetype.values do
		newValues[newIndex] = values[ctype][index]
		values[ctype][index] = nil
	end

	newArchetype.index[newIndex] = id
	archetype.index[index] = nil
	return newIndex
end

-- creates a basic signal
local function createSignal<T...>(): Signal<T...>
	local size = 0
	local listeners = {}

	local self = {}

	function self:connect(listener: (T...) -> ())
		size += 1
		local n = size
		listeners[n] = listener

		return {
			disconnect = function(_)
				listeners[n] = nil
			end,
		}
	end

	(self :: any).fire = function(_, ...: T...)
		for _, listener in listeners do
			listener(...)
		end
	end

	return self
end

local function createObserver(world: World, storage: Map<Entity, Archetype>, ...: CType)
	local map = {}
	local changed = {}
	local connections = {}

	local include = { ... }
	local exclude = {}

	local function addChanged(id: number)
		if map[id] then return end
		table.insert(changed, id)
		map[id] = #changed
	end

	local function reconnect()
		for _, ctype in include do
			table.insert(connections, world:added(ctype):connect(addChanged))
			table.insert(connections, world:changing(ctype):connect(addChanged))
		end
	end

	local function disconnect()
		for _, connection in connections do
			connection:disconnect()
		end
	end

	reconnect()

	local mt = {}
	local observer = setmetatable({}, mt)

	function observer:each()
		local thread = coroutine.wrap(function()
			for _, id in changed do
				local key = idKey(id)
				local archetype = storage[key]

				local hasNone = true
				for _, exclude in exclude do
					if archetype.values[exclude] then
						hasNone = false
						break
					end
				end

				if hasNone then continue end

				local tuple = table.clone(include)
				local hasAll = true
				for i, include in include do
					if not archetype.values[include] then
						hasAll = false
						break
					end
					tuple[i] = archetype.values[include][key]
				end

				if hasAll then continue end

				coroutine.yield(id, unpack(tuple))
			end
		end)

		return function()
			return thread()
		end
	end

	function observer:disconnect()
		disconnect()
	end

	function observer:reconnect()
		reconnect()
	end

	function observer:exclude(...)
		exclude = { ... }
	end

	return observer
end

local function newQuery(components: Components, storage: ArchetypeIndex, ...: CType)
	assert(... ~= nil, "must include atleast 1 component")
	local include = { ... }

	for i, v in include do
		if table.find(include, v, i + 1) then error("duplicate include") end
	end

	local exclude = {}

	local query = {}
	local compatible
	local max
	local tuple = table.clone(include)

	local function updateCompatibleArchetypes()
		if #exclude == 0 and #include == 1 then
			local a = include[1]
			compatible = table.clone(components[a])
			max = table.create(#compatible)
			for i, archetype in compatible do
				max[i] = archetype.size
			end
		elseif #exclude == 0 and #include == 2 then
			local a, b = include[1], include[2]

			if #components[a] > #components[b] then
				b, a = a, b
			end

			max = {}
			compatible = {}

			for _, archetype in components[a] do
				if archetype.values[b] ~= nil then
					--print("found compatible archetype")
					table.insert(compatible, archetype)
					table.insert(max, archetype.size)
				end
			end
		else
			max = {}
			compatible = {}
			for _, archetype in components[include[1]] do
				-- exclude
				local bad = false
				for _, ctype in exclude do
					if archetype.values[ctype] then
						bad = true
						break
					end
				end

				if bad then continue end

				for _, ctype in include do
					if archetype.values[ctype] == nil then
						bad = true
						break
					end
				end

				if bad then continue end

				--print("found compatible archetype")
				table.insert(compatible, archetype)
				table.insert(max, archetype.size)
			end
		end
	end

	function query:exclude(...: CType)
		for i = 1, select("#", ...) do
			if table.find(include, select(i, ...)) then error(`component #{i} is already included, cannot exclude`) end
		end
		exclude = { ... }
		return self
	end

	function query:each()
		updateCompatibleArchetypes()

		local a = include[1]

		local thread = coroutine.wrap(function()
			for i, archetype: Archetype in compatible do
				local maximum = max[i]
				for index in archetype.values[a] do
					if index > maximum then break end
					local id = archetype.index[index]

					for i = 1, #include do
						local ctype = include[i]
						tuple[i] = archetype.values[ctype][index]
					end

					coroutine.yield(id, unpack(tuple))
				end
			end
		end)

		return function()
			return thread()
		end
	end

	query._update = updateCompatibleArchetypes
	query.__iter = query.each

	return setmetatable(query, query)
	-- get any compatible archetypes
end

return function()
	local components: Components = {}
	local archetypes: ArchetypeIndex = {}

	local entities: Map<EntityKey, Archetype> = {}
	local indexes: Map<EntityKey, Index> = {}

	local size = 0
	local ctypes: Map<CType, () -> ()> = {}
	local newest: Map<EntityKey, Entity> = {}
	local free = INVALID_ENTITY

	local World = {}
	local default = getArchetype(components, archetypes, {})

	local added: Map<CType, Signal<Entity, any>> = {}
	local changing: Map<CType, Signal<Entity, any>> = {}
	local removing: Map<CType, Signal<Entity>> = {}

	local function contains(id: number)
		local key = idKey(id)
		return entities[key] and newest[key] == id, not not ctypes[key]
	end

	local function get<T>(index: Index, values: Map<CType, Map<Index, T>>, ctype: CType<T>)
		return values[ctype] and values[ctype][index]
	end

	function World:create()
		if free == INVALID_ENTITY then
			assert(size < MAX_KEY, "max entities reached")
			size += 1
			local key = size
			local id = createId(key, INITIAL_ENTITY_VERSION)

			entities[key] = default
			default.size += 1
			default.index[default.size] = id
			indexes[key] = default.size
			newest[key] = id

			return id
		else
			local key = free
			local oldNewest = newest[key]
			local version = idVersion(oldNewest)
			local id = createId(key, version)

			free = indexes[free]

			entities[key] = default
			default.size += 1
			default.index[default.size] = id
			indexes[key] = default.size
			newest[key] = id

			return id
		end
	end

	function World:component<T>(constructor: (() -> T)?): CType<T>
		assert(size < MAX_KEY, "max entities reached")
		size += 1

		local key = size
		local id = createId(key, 0)

		entities[key] = default
		default.size += 1
		default.index[default.size] = id
		indexes[key] = default.size
		newest[key] = id
		ctypes[key] = constructor or function() end
		components[id] = {}

		return id
	end

	World.contains = function(_, id)
		return contains(id)
	end

	function World:current(id: Entity)
		local key = idKey(id)
		local newest = newest[key]
		return idVersion(newest)
	end

	--FIXME: Necessary to type properly.
	World.get = function(self, id: Entity, ...: CType)
		assert(contains(id), "invalid entity")
		local key = idKey(id)

		local archetype = entities[key]
		local index = indexes[key]
		local values = archetype.values

		local a, b, c, d, e = ...

		local function safeGet(ctype: CType, i: number?)
			local value = get(index, values, ctype)
			if value == nil then error(`component #{i} is nil`) end
			return value
		end

		if b == nil then
			return safeGet(a, 1)
		elseif c == nil then
			return safeGet(a, 1), safeGet(b, 2)
		elseif d == nil then
			return safeGet(a, 1), safeGet(b, 2), safeGet(c, 3)
		elseif e == nil then
			return safeGet(a, 1), safeGet(b, 2), safeGet(c, 3), safeGet(d, 4)
		else
			local tuple = table.create(select("#", ...) - 5)

			for i = 1, #tuple do
				tuple[i] = safeGet(select(i + 5, ...), i)
			end

			return safeGet(a, 1), safeGet(b, 2), safeGet(c, 3), safeGet(d, 4), safeGet(e, 5), unpack(tuple)
		end
	end :: GetCall

	function World:set<T>(id: Entity, ctype: CType<T>, value: T?)
		assert(contains(id), "invalid entity")
		--assert(value ~= nil, "Value must not be nil")

		local key = idKey(id)

		local archetype = entities[key]
		local index = indexes[key]

		if value == nil then
			local newArchetype = getNewArchetypeRemove(components, archetypes, archetype, ctype)

			if newArchetype == archetype then return end
			local removingSignal = removing[ctype]
			if removingSignal then removingSignal:fire(id) end

			indexes[key] = swapArchetypeRemove(archetype, newArchetype, index, id)
			entities[key] = newArchetype
		elseif archetype.values[ctype] then
			local changingSignal = changing[ctype]
			if changingSignal then changingSignal:fire(id, value) end

			archetype.values[ctype][index] = value
		else
			local newArchetype = getNewArchetypeAdd(components, archetypes, archetype, ctype)
			index = swapArchetypeAdd(archetype, newArchetype, index, id)
			indexes[key] = index
			entities[key] = newArchetype
			newArchetype.values[ctype][index] = value

			local addedSignal = added[ctype]
			if addedSignal then addedSignal:fire(id, value) end
		end
	end

	function World:addArchetype(id: Entity, ...: CType)
		assert(contains(id), "invalid entity")
		--assert(value ~= nil, "Value must not be nil")

		local key = idKey(id)

		local archetype = entities[key]
		local index = indexes[key]

		local newArchetype = getNewArchetypeAdd(components, archetypes, archetype, ...)
		index = swapArchetypeAdd(archetype, newArchetype, index, id)
		indexes[key] = index
		entities[key] = newArchetype

		local values = newArchetype.values

		return function<T>(ctype: CType<T>, value: T)
			local isChanging = archetype.values[ctype]

			if isChanging then
				local changingSignal = changing[ctype]
				if changingSignal then changingSignal:fire(id, value) end
			end

			values[ctype][index] = value

			if not isChanging then
				local addedSignal = added[ctype]
				if addedSignal then addedSignal:fire(id, value) end
			end
		end
	end

	function World:remove(id: Entity, ...: CType)
		assert(contains(id), "invalid entity")
		local key = idKey(id)

		local archetype = entities[key]
		local index = indexes[key]

		local newArchetype = getNewArchetypeRemove(components, archetypes, archetype, ...)
		if newArchetype == archetype then return end

		for i = 1, select("#", ...) do
			local ctype = select(i, ...)
			if archetype.values[ctype] == nil then continue end
			local removingSignal = removing[ctype]
			if removingSignal then removingSignal:fire(id) end
		end

		indexes[key] = swapArchetypeRemove(archetype, newArchetype, index, id)
		entities[key] = newArchetype
	end

	function World:has(id: Entity, ...: CType)
		if type(id) ~= "number" then return false end
		if contains(id) == false then return false end

		local key = idKey(id)

		local archetype = entities[key]

		for i = 1, select("#", ...) do
			local ctype = select(i, ...)

			if archetype.values[ctype] == nil then return false end
		end

		return true
	end

	function World:tryGet<T>(id: Entity, ctype: CType<T>): T?
		assert(contains(id), "invalid entity")
		local key = idKey(id)

		local archetype = entities[key]
		local index = indexes[key]

		return if archetype.values[ctype] then archetype.values[ctype][index] else nil
	end

	function World:destroy(id: Entity)
		assert(contains(id), "invalid entity")

		local key, version = idKeyVersion(id)

		local archetype = entities[key]
		local index = indexes[key]

		-- fire the signals before removing values.
		for ctype, values in archetype.values do
			local removingSignal = removing[ctype]
			if removingSignal then removingSignal:fire(id) end
		end

		for ctype, values in archetype.values do
			values[index] = nil
		end

		archetype.index[index] = nil
		entities[key] = nil

		if version == MAX_VERSION then
			indexes[key] = INVALID_ENTITY
			return
		end

		newest[key] = createId(key, version + 1)
		indexes[key] = free
		free = key
	end

	-- clears all components
	function World:clear(...: CType)
		local a = ...

		if a == nil then
			for key, id in newest do
				if ctypes[id] == nil then self:destroy(id) end
			end

			for component, archetypes in components do
				for _, archetype in archetypes do
					for key, index in indexes do
						local id = newest[key]
						swapArchetypeRemove(archetype, default, index, id)
					end
				end
			end
		else
			for i = 1, select("#", ...) do
				local component: CType = select(i, ...)

				for _, archetype in components[component] do
					for key, index in indexes do
						local id = newest[key]
						swapArchetypeRemove(archetype, default, index, id)
					end
				end
			end
		end
	end

	function World:added<T>(ctype: CType<T>): Signal<Entity, T>
		return added[ctype] or (function()
			added[ctype] = createSignal()
			return added[ctype]
		end)()
	end

	function World:changing<T>(ctype: CType<T>): Signal<Entity, T>
		return changing[ctype] or (function()
			changing[ctype] = createSignal()
			return changing[ctype]
		end)()
	end

	function World:removing(ctype: CType): Signal<Entity>
		return removing[ctype] or (function()
			removing[ctype] = createSignal()
			return removing[ctype]
		end)()
	end

	World.query = function(_, ...: CType)
		return newQuery(components, archetypes, ...)
	end :: QueryCall;

	(World :: any)._getCurrentEntityVersion = function(_, id)
		return World:current(id)
	end;

	(World :: any)._setEntityVersion = function(_, key, version)
		local id = createId(key, version)
		local archetype = entities[key]
		local index = indexes[key]
		newest[key] = id

		archetype.index[index] = id
	end;

	(World :: any)._getArchetype = function(_, ...: CType)
		return getArchetype(components, archetypes, { ... })
	end

	return World :: World
end
