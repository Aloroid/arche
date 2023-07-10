local Id = if game then require(script.Id) else require("src/World/Id") :: never
local Components = if game
	then require(script.Parent.Components)
	else require("src/Components") :: never

type Array<T> = { [number]: T }
type Map<T, U> = { [T]: U }

type Entity = number
type InternalComponent = number

export type QueryImpl<T...> = {
	__index: QueryImpl<T...>,
	exclude: (Query<T...>, ...any) -> Query<T...>,
	each: (Query<T...>) -> () -> (Entity, T...),
	size: (Query<T...>) -> number,
	__len: (Query<T...>) -> number,
	__iter: (Query<T...>) -> () -> (Entity, T...),
}

export type Query<T...> = typeof(setmetatable(
	{} :: {
		_includes: Array<number>,
		_excludes: Array<number>,
		_includesOrder: Map<number, number>,
	},
	{} :: QueryImpl<T...>
))

export type Archetype = {
	id: number,
	size: number,

	values: Map<InternalComponent, Array<unknown>>,
	index: Map<number, number>,

	sorted: { InternalComponent },
	compatible: Map<Archetype, boolean>,
	addArchetypes: { Archetype },
	removeArchetypes: { Archetype },
}

export type ArchetypeIndex = {
	archetype: Archetype?,
	[number]: ArchetypeIndex,
}

export type WorldImpl = {
	__index: WorldImpl,

	new: () -> World,

	-- entities
	create: (World) -> Entity,
	createAt: (World, id: number) -> Entity,
	contains: (World, id: number) -> boolean,

	-- querying
	query: <T...>(World, T...) -> Query<T...>,
	--track: <T...>(World, T...) -> Track<T...>,

	-- reading
	get: <T...>(World, id: Entity, T...) -> T...,
	try_get: <T>(World, id: Entity, component: T) -> T,
	has: (World, id: Entity, ...any) -> boolean,

	-- writing
	set: <T>(World, id: Entity, component: T, value: T) -> T,
	--batch_sert: (World, id: Entity, ) -> (),
	remove: (World, id: Entity, component: any) -> (),
	--patch: <T>(World, id: Entity, component: T, patch: (old: T) -> T?) -> (),

	-- removing

	-- getting rid of
	destroy: (World, id: Entity) -> (),

	-- internal
	_getArchetype: (World, ...number) -> Archetype,
	_isCurrentVersion: (World, index: number, version: number) -> boolean,
	_setEntityVersion: (World, index: number, version: number) -> (),
	_getCurrentEntityVersion: (World, index: number) -> number,
	_getComponentIndex: (World, component: any, archetype: Archetype) -> (),
}

export type World = typeof(setmetatable(
	{} :: {

		size: number,
		_free: Array<number>,
		_version: Array<number>,

		_totalArchetypes: number,
		_entities: Map<Entity, Archetype>,
		_archetypes: ArchetypeIndex,
		_components: Map<
			InternalComponent,
			{ size: number, [number]: Archetype }
		>,
	},
	{} :: {
		__index: WorldImpl,
	}
))

local function get(index: number, component: number, archetype: Archetype)
	if archetype.values[component] == nil then return nil end
	local archetypeIndex = archetype.index[index]
	return archetype.values[component][archetypeIndex]
end

local function fastSet(
	index: number,
	component: number,
	archetype: Archetype,
	value: unknown
)
	local archetypeIndex = archetype.index[index]
	archetype.values[component][archetypeIndex] = value
end

local function archetypeSwapAdd(
	world: World,
	index: number,
	archetype: Archetype,
	newArchetype: Archetype
)
	local archetypeIndex = archetype.index[index]

	newArchetype.size += 1
	local newArchetypeIndex = newArchetype.size
	local newArchetypeValues = newArchetype.values
	newArchetype.index[index] = newArchetypeIndex

	for component, values in archetype.values do
		newArchetypeValues[component][newArchetypeIndex] =
			values[archetypeIndex]
		values[archetypeIndex] = nil
	end

	archetype.index[index] = nil
	world._entities[index] = newArchetype
end

local function archetypeSwapRemove(
	world: World,
	index: number,
	archetype: Archetype,
	newArchetype: Archetype
)
	local archetypeIndex = archetype.index[index]
	newArchetype.size += 1
	local newArchetypeIndex = newArchetype.size
	local archetypeValues = archetype.values
	newArchetype.index[index] = newArchetypeIndex

	for component, values in newArchetype.values do
		values[newArchetypeIndex] = archetypeValues[component][archetypeIndex]
		archetypeValues[component][archetypeIndex] = nil
	end

	archetype.index[index] = nil
	world._entities[index] = newArchetype
end

local Query = {} :: QueryImpl<...any>
Query.__index = Query

function Query.new(world: World, ...)
	local order = {}
	local components = { ... }

	for k, v in components do
		if order[v] then error(`component #{k} already is included earlier`) end

		order[v] = k
	end

	return setmetatable({
		_includes = components,
		_excludes = {},
		_includesOrder = order,

		_world = world,
	}, Query)
end

function Query:each()
	local world: World = self._world

	table.sort(self._includes, function(a, b)
		local componentA, componentB =
			world._components[a] or {}, world._components[b] or {}
		return #componentA < #componentB
	end)

	table.sort(self._excludes, function(a, b)
		local componentA, componentB =
			world._components[a] or {}, world._components[b] or {}
		return #componentA > #componentB
	end)

	local main = world:_getArchetype(unpack(self._includes))

	local thread = coroutine.wrap(function()
		local componentId = self._includes[1]

		local archetypes = {}

		-- gets all valid archetypes
		for _, archetype in world._components[componentId] do
			if main.compatible[archetype] == nil then
				-- check if the archetype meets our requirements
				local valid = true

				-- check if it has all the included components
				for _, component in self._includes do
					if archetype.values[component] == nil then
						valid = false
						break
					end
				end

				if not valid then
					main.compatible[archetype] = false
					continue
				end
				-- check if it has none of the excluded components
				for _, component in self._excludes do
					if archetype.values[component] ~= nil then
						valid = false
						break
					end
				end

				main.compatible[archetype] = valid
				if not valid then continue end
				table.insert(archetypes, 1, archetype)
			elseif main.compatible[archetype] == true then
				table.insert(archetypes, 1, archetype)
			end
		end

		-- iterates over the archetypes that are valid
		for _, archetype in archetypes do
			for index in archetype.values[componentId] do
				--if ids[index] then continue end
				local tuple = table.create(#self._includes)

				for component, i in self._includesOrder do
					tuple[i] = archetype.values[component][index]
				end

				--ids[index] = true

				coroutine.yield(
					Id.createId(index, world:_getCurrentEntityVersion(index)),
					unpack(tuple)
				)
			end
		end

		coroutine.yield(nil)
	end)

	return function()
		return thread()
	end
end

function Query:exclude(...)
	for i = 1, select("#", ...) do
		local component = select(i, ...)
		if self._includesOrder[component] then
			error(`component #{i} is already included`)
		end

		table.insert(self._excludes, component)
	end

	return self
end

Query.__iter = Query.each

local World = {} :: WorldImpl
World.__index = World

function World.new()
	local self = setmetatable({

		size = 0,
		_count = 0,
		_free = {},
		_version = {},

		_totalArchetypes = 0,
		_entities = {},
		_archetypes = {},
		_components = table.create(Components.count),
	}, World) :: World

	self:_getArchetype() -- converts the first archetype table into a archetype

	return self
end

function World:create(id)
	assert(id == nil, "attempted to pass id? to :create. use :createAt instead")
	local index, version = table.remove(self._free)

	if index == nil then
		repeat
			self._count += 1
		until self._entities[self._count] == nil

		index = self._count
		version = Id.INITIAL_ENTITY_VERSION
	else
		version = self._version[index]
	end

	self.size += 1

	self._entities[index] = self._archetypes.archetype
	self._version[index] = version

	return Id.createId(index, version)
end

function World:createAt(id)
	local index, version = Id.idIndexVersion(id)
	assert(
		index >= 1
			and version >= 1
			and index <= Id.ID_MAX_INDEX
			and version <= Id.ID_MAX_VERSION,
		"malformed id"
	)

	-- check if it doesn't exist already
	assert(self._entities[index] == nil, "entity already exists")

	self.size += 1

	self._entities[index] = self._archetypes.archetype
	self._version[index] = version

	return id
end

function World:contains(id)
	local index, version = Id.idIndexVersion(id)
	return not not self._entities[index]
		and self:_isCurrentVersion(index, version)
end

function World:set(id, component, value)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	assert(archetype ~= nil, "invalid entity")
	assert(self:_isCurrentVersion(index, version), "invalid entity")

	if value == nil then
		if archetype.values[component] == nil then return end

		local newArchetype = archetype.removeArchetypes[component]

		-- finds a new archetype by cloning the sorted table and removing
		-- the component that is no longer necessary.
		if newArchetype == nil then
			local components = table.clone(archetype.sorted)
			table.remove(components, table.find(components, component))
			newArchetype = self:_getArchetype(unpack(components))
		end

		archetypeSwapRemove(self, index, archetype, newArchetype)
	elseif archetype.values[component] then
		fastSet(index, component, archetype, value)
	else
		-- swap archetype
		local newArchetype = archetype.addArchetypes[component]
		if newArchetype == nil then
			newArchetype =
				self:_getArchetype(component, unpack(archetype.sorted))
			archetype.addArchetypes[component] = newArchetype
		end

		archetypeSwapAdd(self, index, archetype, newArchetype)
		fastSet(index, component, newArchetype, value)
	end
end

function World:get(id, ...)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	if archetype == nil then error("invalid entity") end
	if self:_isCurrentVersion(index, version) == false then
		error("invalid entity")
	end

	local archetypeIndex = archetype.index[index]
	local a, b, c, d, e = ...

	local function get(component, i)
		if archetype.values[component] == nil then
			error(`component #{i} does not exist on entity`)
		end
		local value = archetype.values[component][archetypeIndex]
		if value == nil then
			error(`component #{i} does not exist on entity`)
		end
		return value
	end

	if b == nil then
		return get(a, 1)
	elseif c == nil then
		return get(a, 1), get(b, 2)
	elseif d == nil then
		return get(a, 1), get(b, 2), get(c, 3)
	elseif e == nil then
		return get(a, 1), get(b, 2), get(c, 3), get(d, 4)
	else
		local size = select("#", ...)
		local tuple = table.create(size - 5)
		for i = 6, select("#", size) do
			local component = select(i, ...)
			tuple[i - 5] = get(component, i)
		end
		return get(a, 1),
			get(b, 2),
			get(c, 3),
			get(d, 4),
			get(e, 5),
			unpack(tuple)
	end
end

function World:try_get(id, component)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	if archetype == nil then return nil end
	if self:_isCurrentVersion(index, version) == false then return nil end

	return get(index, component, archetype)
end

function World:has(id, ...)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	if archetype == nil then return false end
	if self:_isCurrentVersion(index, version) == false then return false end

	for i = 1, select("#", ...) do
		local component = select(i, ...)
		if archetype.values[component] == nil then return false end
	end

	return true
end

function World:remove(id, ...)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	assert(archetype ~= nil, "invalid entity")
	assert(self:_isCurrentVersion(index, version), "invalid entity")

	local components
	local newArchetype = archetype

	for i = 1, select("#", ...) do
		local component = select(i, ...)
		if newArchetype.values[component] == nil then continue end
		local removingArchetype = newArchetype.removeArchetypes[component]

		if removingArchetype == nil then
			if components == nil then components = newArchetype.sorted end
			table.remove(components, table.find(components, component))
			removingArchetype = self:_getArchetype(unpack(components))
			newArchetype.removeArchetypes[component] = removingArchetype
		end

		newArchetype = removingArchetype
	end

	if newArchetype == archetype then return end

	archetypeSwapRemove(self, index, archetype, newArchetype)
end

function World:query(...)
	local a = ...

	assert(a, "atleast one component must be provided")

	return Query.new(self, ...)
end

function World:destroy(id)
	local index, version = Id.idIndexVersion(id)
	local archetype = self._entities[index]

	assert(self:_isCurrentVersion(index, version), "invalid entity")
	assert(archetype ~= nil, "invalid entity")

	self.size -= 1
	self._entities[index] = nil -- resets the archetype

	-- gets rid of any values
	for _, values in archetype.values do
		values[index] = nil
	end

	version += 1
	if version > Id.ID_MAX_VERSION then return end
	self._version[index] = version
	if version == Id.ID_MAX_VERSION then return end
	table.insert(self._free, index)
end

function World:_getArchetype(...)
	local sorted = { ... }

	-- sorts the set of components so that we can get the same archetype
	table.sort(sorted)

	local current = self._archetypes
	for _, component in sorted do
		if current[component] == nil then current[component] = {} end
		current = current[component]
	end

	if current.archetype == nil then
		local archetype = {
			size = 0,

			values = {},
			index = {},

			compatible = {}, -- caches which archetypes are compatible

			addArchetypes = {},
			removeArchetypes = {},

			sorted = sorted,
		}

		for i, component in sorted do
			archetype.values[component] = {}
			self._components[component] = self._components[component] or {}
			table.insert(self._components[component], archetype)
		end

		current.archetype = archetype
	end

	return current.archetype
end

function World:_isCurrentVersion(index, version)
	local current = self._version[index] or 0
	return current <= version
end

function World:_setEntityVersion(index, version)
	self._version[index] = version
end

function World:_getCurrentEntityVersion(id)
	local index = Id.idIndex(id)
	return self._version[index]
end

function World:_getComponentIndex(component, archetype)
	return archetype.values[component]
		and self._components[component][archetype]
end

return World
