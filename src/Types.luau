type Array<T> = { [number]: T }
type Map<T, U> = { [T]: U }

type Entity = number
type InternalComponent = number

export type Query<T...> = typeof(setmetatable(
	{} :: {
		exclude: (...any) -> Query<T...>,
		each: () -> (Entity, T...),
	},
	{} :: {
		__iter: () -> () -> (Entity, T...),
	}
))

export type Track<T...> = typeof(setmetatable(
	{} :: {
		exclude: (...any) -> Query<T...>,
		each: () -> () -> (number, T...),
	},
	{} :: {
		__iter: () -> () -> (Entity, T...),
	}
))

export type Archetype = {
	values: Map<InternalComponent, Array<unknown>>,

	sorted: { InternalComponent },
	contained: { ArchetypeIndex },
}

export type ArchetypeIndex = {
	archetype: Archetype?,
	[number]: ArchetypeIndex,
}

export type WorldImpl = {
	__index: WorldImpl,

	new: () -> World,

	-- spawning
	create: (World) -> Entity,

	-- querying
	--query: <T...>(World, T...) -> Query<T...>,
	--track: <T...>(World, T...) -> Track<T...>,

	-- reading
	get: <T...>(World, id: Entity, T...) -> T...,
	--try_get: <T>(World, id: Entity, component: T) -> T,

	-- writing
	set: <T>(World, id: Entity, component: T, value: T) -> T,
	--patch: <T>(World, id: Entity, component: T, patch: (old: T) -> T?) -> (),

	-- internal
	_getArchetype: (World, ...number) -> Archetype,
}

export type World = typeof(setmetatable(
	{} :: {

		size: number,
		_free: Array<number>,
		_version: Array<number>,

		_entities: Map<Entity, Archetype>,
		_archetypes: { ArchetypeIndex },
	},
	{} :: {
		__index: WorldImpl,
	}
))

return nil
