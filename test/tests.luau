local testkit = require("test/testkit")

local TEST, CASE, CHECK, FINISH = testkit.test()

local function CHECK_ERR<T...>(s: string, fn: (T...) -> (), ...: T...)
	local ok, err: string? = pcall(fn, ...)
	if CHECK(not ok, 2) then
		local i = string.find(err :: string, " ")
		assert(i)
		local msg = string.sub(err :: string, i + 1)
		CHECK(msg == s, 2)
	end
end

type Map<T, U> = { [T]: U }
type Array<T> = { T }

local arch = require("src/init")

local A, B, C, D =
	arch.component(), arch.component(), arch.component(), arch.component()
local E, F, G, H =
	arch.component(), arch.component(), arch.component(), arch.component()

local MAX_VER = 2 ^ 33 - 1

local function KEY(id: number): number
	local key = arch.extract(id)
	return key
end

local function VER(id: number): number
	local _, ver = arch.extract(id)
	return ver
end

local function CREATE_ID(key: number, ver: number)
	return (arch :: any).id(key, ver)
end

local function SET_ENTITY_VERSION(reg, key: number, ver: number)
	reg:destroy(reg:createAt(CREATE_ID(KEY(key), 1)))
	reg:_setEntityVersion(KEY(key), ver)
end

local function CURRENT_VER(reg, id): number
	return reg:_getCurrentEntityVersion(id)
end

local function CREATE_DEPRECATED_ID(reg)
	local id = reg:create()
	reg:destroy(id)
	SET_ENTITY_VERSION(reg, KEY(id), MAX_VER)
	id = reg:create()
	reg:destroy(id)
	return id
end

local function BULK_CREATE_IDS(reg, n: number): { number }
	local ids = table.create(n)
	for i = 1, n do
		ids[i] = reg:create()
	end
	return ids
end

local N = 1e3

TEST("registry:create()", function()
	do
		CASE("New ids unique")
		local reg = arch.World()

		local cache = {}

		for i = 1, N do
			local id = reg:create()
			CHECK(not cache[id])
			cache[id] = true
		end
	end

	do
		CASE("Reusing keys produce unique ids")
		local reg = arch.World()

		local cache = {}

		for i = 1, N do
			local id = reg:create()
			cache[id] = true
		end

		for id in cache do
			reg:destroy(id)
		end

		for i = 1, N do
			local id = reg:create() -- key reused
			CHECK(not cache[id])
			cache[id] = true
		end
	end

	do
		CASE("Create entity with specific id")
		do
			local sreg = arch.World()

			local ids = BULK_CREATE_IDS(sreg, N)

			-- mix array of ids
			local mixed = table.clone(ids)
			for i = 1, N do
				local a = math.random(1, N)
				local b = math.random(1, N)
				mixed[a], mixed[b] = mixed[b], mixed[a]
			end

			local reg = arch.World()

			for i = 1, N do
				reg:createAt(mixed[i])
			end

			for i = 1, N do
				CHECK(reg:contains(ids[i]))
			end
		end

		local reg = arch.World()
		reg:createAt(CREATE_ID(3, 2))
		CHECK(reg:create() == CREATE_ID(1, 1))
		CHECK(reg:create() == CREATE_ID(2, 1))
		CHECK(reg:create() == CREATE_ID(4, 1))
	end

	do
		CASE("Create entity with previously used id")
		do
			local reg = arch.World()
			local id = reg:create()
			reg:destroy(id)
			reg:createAt(id)
			CHECK(reg:contains(id))
		end

		do
			local reg = arch.World()
			local id1, id2, id3 = reg:create(), reg:create(), reg:create()
			local id4 = reg:create()

			reg:destroy(id4)
			reg:destroy(id3)
			reg:destroy(id2)
			reg:destroy(id1)

			-- 1 -> 2 -> 3 -> 4
			reg:createAt(id4)
			-- 1 -> 2 -> 3
			reg:createAt(id2)
			-- 1 -> 3
			reg:createAt(id1)
			-- 3
			local id5 = reg:createAt(CREATE_ID(5, 1))
			reg:destroy(id5)
			-- 3 -> 5
			reg:createAt(id5)
			-- 3
			reg:createAt(id3)
			-- [empty]

			CHECK(reg:contains(id1))
			CHECK(reg:contains(id2))
			CHECK(reg:contains(id3))
			CHECK(reg:contains(id4))
			CHECK(reg:contains(id5))

			CHECK(KEY(id1) == 1)
			CHECK(KEY(id2) == 2)
			CHECK(KEY(id3) == 3)
			CHECK(KEY(id4) == 4)
			CHECK(KEY(id5) == 5)
		end
	end
end)

TEST("registry:destroy()", function()
	local reg = arch.World()

	do
		CASE("Destroyed entities invalid")
		local id = reg:create()
		reg:destroy(id)
		CHECK(not reg:contains(id))
	end

	do
		CASE("Destroy invalid id")
		local id = reg:create()
		reg:destroy(id)
		CHECK_ERR("invalid entity", function()
			reg:destroy(id)
		end)
	end

	--[[do
		CASE("Destroy null id")
		CHECK_ERR("invalid entity", function()
			reg:destroy(arch.null)
		end)
	end]]

	do
		CASE("Destroy deprecated id")
		local id = CREATE_DEPRECATED_ID(reg)
		CHECK_ERR("invalid entity", function()
			reg:destroy(id)
		end)
	end
end)

TEST("registry:contains()", function()
	local reg = arch.World()

	do
		local id = reg:create()

		do
			CASE("New entity valid")
			CHECK(reg:contains(id))
		end

		reg:destroy(id)

		do
			CASE("Released entity invalid")
			CHECK(not reg:contains(id))
		end

		local newid = reg:create()

		do
			CASE("Id with reused key valid")
			CHECK(reg:contains(newid))
		end

		do
			CASE("Released entity still invalid despite key reuse")
			CHECK(not reg:contains(id))
		end
	end

	do
		CASE("Integer invalid")
		local id = reg:create()
		assert(KEY(id) == 2)
		CHECK(not reg:contains(2))
	end

	--[[do CASE "Null entity invalid"
        CHECK(not reg:contains(ecr.null))
    end]]

	do
		CASE("Deprecated id invalid")
		local id = CREATE_DEPRECATED_ID(reg)
		CHECK(not reg:contains(id))
	end
end)

TEST("registry:version()", function()
	local reg = arch.World()

	do
		CASE("Get version")
		local id = reg:create()
		CHECK(VER(id) == 1)
	end

	do
		CASE("Version increments on reuse")
		local id_old = reg:create()
		CHECK(VER(id_old) == 1)
		reg:destroy(id_old)
		local id_new = reg:create()
		CHECK(VER(id_old) == 1)
		CHECK(VER(id_new) == 2)
	end

	do
		CASE("Version overflow")
		local reg2 = arch.World()

		reg2:destroy(reg2:create()) -- ensure id internally exists

		SET_ENTITY_VERSION(reg2, 1, MAX_VER - 1)

		-- verify version was set to MAX-1 correctly
		local id = reg2:create()
		CHECK(VER(id) == MAX_VER - 1)
		CHECK(KEY(id) == 1)
		-- trigger version increment
		reg2:destroy(id)

		-- verify version is now MAX
		id = reg2:create()
		CHECK(VER(id) == MAX_VER)
		CHECK(KEY(id) == 1)

		-- id deprecated
		reg2:destroy(id)
		CHECK(VER(id) == MAX_VER)

		-- should produce a new key and not recycle as the previous key is at MAX version
		id = reg2:create()
		CHECK(VER(id) == 1)
		CHECK(KEY(id) == 2)
	end
end)

TEST("registry:current()", function()
	local reg = arch.World()
	local id_old = reg:create()
	reg:destroy(id_old)
	local id_new = reg:create()

	do
		CASE("Gets current version")
		CHECK(VER(id_old) == 1)
		CHECK(CURRENT_VER(reg, id_old) == 2)
	end

	do
		CASE("Version increments on release")
		reg:destroy(id_new)
		CHECK(CURRENT_VER(reg, id_new) == 3)
	end

	do
		CASE("Deprecated key")
		local ver = CURRENT_VER(reg, CREATE_DEPRECATED_ID(reg))
		CHECK(ver == MAX_VER)
	end
end)

TEST("registry:set()", function()
	local reg = arch.World()

	do
		local id = reg:create()

		do
			CASE("Add component")
			reg:set(id, A, 1)
			CHECK(reg:get(id, A) == 1)
		end

		do
			CASE("Change component")
			reg:set(id, A, 2)
			CHECK(reg:get(id, A) == 2)
		end

		do
			CASE("Remove component")
			reg:set(id, A, nil)
			CHECK(reg:tryGet(id, A) == nil)
			CHECK(not reg:has(id, A))
		end
	end

	do
		CASE("Add component to invalid id with unused key")
		CHECK_ERR("invalid entity", function()
			local id = reg:create()
			reg:destroy(id)
			reg:set(id, A, 1)
		end)
	end

	do
		CASE("Add component to invalid id with used key")
		CHECK_ERR("invalid entity", function()
			local id = reg:create()
			reg:destroy(id)
			reg:create() -- reuse key
			reg:set(id, A, 1)
		end)
	end

	do
		CASE("Add component to invalid id with used key that has component")
		CHECK_ERR("invalid entity", function()
			local id = reg:create()
			reg:destroy(id)

			local newid = reg:create() -- reuse key
			reg:set(newid, A, 0)

			reg:set(id, A, 1)
		end)
	end

	--[[do CASE "Add component to null entity"
        CHECK_ERR("invalid entity", function()
            reg:set(ecr.null, A, true)
        end)
    end]]

	do
		CASE("Add component to deprecated id")
		CHECK_ERR("invalid entity", function()
			local id = CREATE_DEPRECATED_ID(reg)
			reg:set(id, A, 1)
		end)
	end

	do
		CASE(
			"Change component of invalid entity with used key that has component"
		)
		CHECK_ERR("invalid entity", function()
			local id = reg:create()
			reg:destroy(id)

			local newid = reg:create() -- reuse key
			reg:set(newid, A, 1)

			reg:set(id, A, 2)
		end)
	end

	do
		CASE("Remove component from invalid entity")
		local id = reg:create()
		reg:destroy(id)

		CHECK_ERR("invalid entity", function()
			reg:set(id, A, nil)
		end)
	end

	do
		CASE("Remove component from invalid entity with used key")
		local id = reg:create()
		reg:destroy(id)
		reg:create() -- reuse key

		CHECK_ERR("invalid entity", function()
			reg:set(id, A, nil)
		end)
	end

	do
		CASE(
			"Remove component from invalid entity with used key that has component"
		)
		local id = reg:create()
		reg:destroy(id)

		local newid = reg:create() -- reuse key
		reg:set(newid, A, 1)

		CHECK_ERR("invalid entity", function()
			reg:set(id, A, nil)
		end)

		CHECK(reg:get(newid, A) == 1)
	end
end)

TEST("registry:get()", function()
	local reg = arch.World()

	do
		local id = reg:create()

		do
			CASE("Get component")
			reg:set(id, A, 1)
			CHECK(reg:get(id, A) == 1)
		end

		do
			CASE("Get multiple components")
			reg:set(id, B, 2)
			reg:set(id, C, 3)
			reg:set(id, D, 4)
			reg:set(id, E, 5)

			local values = { reg:get(id, A, B, C, D, E) }

			for i, value in values do
				CHECK(value == i)
			end
		end

		do
			CASE("Get nil component")
			reg:remove(id, A)
			CHECK_ERR("component #1 does not exist on entity", function()
				reg:get(id, A)
			end)
		end
	end

	do
		CASE("Get component of invalid id")
		local id = reg:create()
		reg:destroy(id)
		CHECK_ERR("invalid entity", function()
			reg:get(id, A)
		end)
	end

	do
		CASE("Get component of invalid id with used key that has component")
		local id = reg:create()
		reg:destroy(id)

		local newid = reg:create()
		reg:set(newid, A, 1)

		CHECK_ERR("invalid entity", function()
			reg:get(id, A)
		end)
	end
end)

TEST("registry:remove()", function()
	local reg = arch.World()

	do
		local id = reg:create()
		reg:set(id, A, 1)
		reg:set(id, B, 1)
		reg:set(id, C, 1)

		local id2 = reg:create()
		reg:set(id2, A, 2)

		do
			CASE("Remove single component")

			reg:remove(id, A)
			CHECK(reg:has(id, A) == false)
			CHECK(reg:get(id2, A) == 2) -- check removal maintains associativity
		end

		do
			CASE("Remove multiple components")
			reg:remove(id, B, C)
			CHECK(reg:has(id, B) == false)
			CHECK(reg:has(id, C) == false)
		end
	end

	do
		CASE("Remove component from invalid entity")
		local id = reg:create()
		reg:destroy(id)

		CHECK_ERR("invalid entity", function()
			reg:remove(id, A)
		end)
	end

	do
		CASE(
			"Remove component from invalid id that shares key with entity that has component"
		)
		local id = reg:create()
		reg:destroy(id)

		local newid = reg:create()
		reg:set(newid, A, 1)

		CHECK_ERR("invalid entity", function()
			reg:remove(id, A)
		end)

		CHECK(reg:has(newid, A))
	end
end)

TEST("registry:query()", function()
	local function flip()
		return math.random() > 0.3
	end

	local function empty(t)
		return next(t) == nil
	end

	local function getids(view): {}
		local cache = {}
		local size = 0
		for id, a, b, c, d in view do
			size += 1
			cache[id] = { a, b, c, d }
		end

		return cache, size
	end

	local reg = arch.World()

	local ids = {}
	local As = {}
	local Bs = {}
	local Cs = {}
	local ABCs = {}
	local ABnotCs = {}

	for i = 1, N do
		local id = reg:create()
		ids[i] = id

		local has = {}
		for _, component in { A, B, C, D, E, F, G, H } do
			if flip() then
				reg:set(id, component, id)
				has[component] = true
			end
		end

		if has[A] then table.insert(As, id) end
		if has[B] then table.insert(Bs, id) end
		if has[C] then table.insert(Cs, id) end
		if has[A] and has[B] and has[C] then table.insert(ABCs, id) end
		if has[A] and has[B] and not has[C] then table.insert(ABnotCs, id) end
	end

	do
		CASE("View all entities with A")
		local viewed, size = getids(reg:query(A))
		CHECK(not empty(viewed))
		CHECK(size == #As)
		for _, id in As do
			local v = viewed[id]
			if not CHECK(v) then continue end
			CHECK(v[1] == id)
		end
	end

	do
		CASE("View all entities with B")
		local viewed, size = getids(reg:query(B))
		CHECK(not empty(viewed))
		CHECK(size == #Bs)
		for _, id in Bs do
			local v = viewed[id]
			if not CHECK(v) then continue end
			CHECK(v[1] == id)
		end
	end

	do
		CASE("View all entities with ABC")
		local viewed = getids(reg:query(A, B, C))
		CHECK(not empty(viewed))
		for _, id in ABCs do
			local v = viewed[id]
			if not CHECK(v) then continue end
			CHECK(v[1] == id)
			CHECK(v[2] == id)
			CHECK(v[3] == id)
		end
	end

	do
		CASE("View all entities with AB and not C")
		local viewed = getids(reg:query(A, B):exclude(C))
		CHECK(not empty(viewed))
		for _, id in ABnotCs do
			local v = viewed[id]
			if not CHECK(v) then continue end
			CHECK(v[1] == id)
		end
	end

	do
		CASE("Addition during view iteration")
		local cache = {}
		for id, c in reg:query(C) do
			-- check that newly added entities+components are not included in iterations
			CHECK(not cache[id])
			if flip() then -- create new entity+component
				local new = reg:create()
				reg:set(new, C, true)
				table.insert(Cs, id)
				cache[new] = true
			end
		end
	end

	do
		CASE("Component removal during view iteration")
		local viewed = {}
		for entity in reg:query(A) do
			if flip() then reg:remove(entity, A) end
			viewed[entity] = true
		end
		CHECK(not empty(viewed))
		for _, entity in As do -- check that an entity isn't skipped
			CHECK(viewed[entity])
		end
	end

	do
		CASE("Duplicate include errors")
		local ok = pcall(function()
			reg:query(A, B, A)
		end)
		CHECK(not ok)
	end

	do
		CASE("Exclude an include errors")
		local ok = pcall(function()
			reg:query(A, B):exclude(C, A)
		end)
		CHECK(not ok)
	end
end)

local success = FINISH()
if not success then error(nil, 0) end
