local testkit = require("test/testkit")
local BENCH, START = testkit.benchmark()

local function TITLE(name: string)
	print()
	print(testkit.color.white(name))
end

local arch = require("src/init")

local function rtrue()
	return true :: any
end

-- power of 2 so arrays are better alined for accurate memory usage reading
local N = 2 ^ 18 --~ 262k

do
	TITLE("Entity creation and release")
	BENCH("Entity creation", function()
		local reg = arch.World()

		for i = 1, START(N) do
			reg:create()
		end
	end)

	BENCH("Entity creation (no pre-alloc)", function()
		local reg = arch.World()

		for i = 1, START(N) do
			reg:create()
		end
	end)

	BENCH("Entity release", function()
		local reg = arch.World()

		local id = table.create(N)

		for i = 1, N do
			id[i] = reg:create()
		end

		for i = 1, START(N) do
			reg:destroy(id[i])
		end
	end)

	--[[BENCH("Entity creation with desired id", function()
		local sreg = arch.World()

		local id = table.create(N)

		for i = 1, N do
			id[i] = sreg:create()
		end

		local reg = arch.World()

		for i = 1, START(N) do
			reg:createAt(id[i])
		end
	end)]]
end

--[[do TITLE "Adding components"
    local function setup()
        local reg = arch.World()
        local ids = table.create(N)
        for i = 1, N do
            ids[i] = reg:create()
        end
        return reg, ids
    end

    do
        local reg, ids = setup()

        BENCH("Add 1 component", function()
            for i = 1, START(N) do
                reg:add(ids[i], A)
            end
        end)
    end

    do
        local reg, ids = setup()

        BENCH("Add 2 components", function()
            for i = 1, START(N) do
                reg:add(ids[i], A, B)
            end
        end)
    end

    do
        local reg, ids = setup()

        BENCH("Add 4 components", function()
            for i = 1, START(N) do
                reg:add(ids[i], A, B, C, D)
            end
        end)
    end

    do
        local reg, ids = setup()
        BENCH("Add 1 tag", function()
            for i = 1, START(N) do
                reg:add(ids[i], TA)
            end
        end)
    end

    do
        local reg, ids = setup()
        BENCH("Add 4 tags", function()
            for i = 1, START(N) do
                reg:add(ids[i], TA, TB, TC, TD)
            end
        end)
    end
end]]

do
	TITLE("Setting components")
	local function setup()
		local reg = arch.World()
		local ids = table.create(N)
		for i = 1, N do
			ids[i] = reg:create()
		end
		return reg, ids
	end

	do
		local reg, ids = setup()
		local A = reg:component()

		BENCH("Add 1 component", function()
			for i = 1, START(N) do
				reg:set(ids[i], A, true)
			end
		end)

		BENCH("Change 1 component", function()
			for i = 1, START(N) do
				reg:set(ids[i], A, true)
			end
		end)

		BENCH("Remove 1 component", function()
			for i = 1, START(N) do
				reg:set(ids[i], A, nil)
			end
		end)
	end

	do
		local reg, ids = setup()
		local A, B = reg:component(rtrue), reg:component(rtrue)

		BENCH("Add 2 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, true)
				reg:set(e, B, true)
			end
		end)

		BENCH("Change 2 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, true)
				reg:set(e, B, true)
			end
		end)

		BENCH("Remove 2 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, nil)
				reg:set(e, B, nil)
			end
		end)
	end

	do
		local reg, ids = setup()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		BENCH("Add 4 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, true)
				reg:set(e, B, true)
				reg:set(e, C, true)
				reg:set(e, D, true)
			end
		end)

		BENCH("Change 4 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, true)
				reg:set(e, B, true)
				reg:set(e, C, true)
				reg:set(e, D, true)
			end
		end)

		BENCH("Remove 4 components", function()
			for i = 1, START(N) do
				local e = ids[i]
				reg:set(e, A, nil)
				reg:set(e, B, nil)
				reg:set(e, C, nil)
				reg:set(e, D, nil)
			end
		end)
	end
end

do
	TITLE("Fast Adding components")
	local function setup()
		local reg = arch.World()
		local ids = table.create(N)
		for i = 1, N do
			ids[i] = reg:create()
		end
		return reg, ids
	end

	do
		BENCH("Fast Set Call Add 1", function()
			local reg, ids = setup()
			local A = reg:component()
			local fastSets = table.create(N)
			for i = 1, N do
				fastSets[i] = reg:addArchetype(ids[i], A)
			end
			for i = 1, START(N) do
				local fastSet = fastSets[i]
				fastSet(A, true)
			end
		end)
	end

	do
		BENCH("Fast Set Call Add 2", function()
			local reg, ids = setup()
			local A, B = reg:component(), reg:component()
			local fastSets = table.create(N)
			for i = 1, N do
				fastSets[i] = reg:addArchetype(ids[i], A, B)
			end
			for i = 1, START(N) do
				local fastSet = fastSets[i]
				fastSet(A, true)
				fastSet(B, true)
			end
		end)
	end

	do
		BENCH("Fast Set Call Add 4", function()
			local reg, ids = setup()
			local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
			local fastSets = table.create(N)
			for i = 1, N do
				fastSets[i] = reg:addArchetype(ids[i], A, B, C, D)
			end
			for i = 1, START(N) do
				local fastSet = fastSets[i]
				fastSet(A, true)
				fastSet(B, true)
				fastSet(C, true)
				fastSet(D, true)
			end
		end)
	end

	do
		BENCH("Swap archetype 1 component", function()
			local reg, ids = setup()
			local A = reg:component()
			for i = 1, START(N) do
				reg:addArchetype(ids[i], A)
			end
		end)
	end

	do
		BENCH("Swap archetype 2 components", function()
			local reg, ids = setup()
			local A, B = reg:component(), reg:component()
			for i = 1, START(N) do
				reg:addArchetype(ids[i], A, B)
			end
		end)
	end

	do
		BENCH("Swap archetype 4 components", function()
			local reg, ids = setup()
			local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
			for i = 1, START(N) do
				reg:addArchetype(ids[i], A, B, C, D)
			end
		end)
	end

	do
		BENCH("Adding 1 component", function()
			local reg, ids = setup()
			local A = reg:component()
			for i = 1, START(N) do
				local e = ids[i]
				local fastSet = reg:addArchetype(e, A)
				fastSet(A, true)
			end
		end)
	end

	do
		local reg, ids = setup()
		local A, B = reg:component(), reg:component()

		BENCH("Adding 2 component", function()
			for i = 1, START(N) do
				local e = ids[i]
				local fastSet = reg:addArchetype(e, A, B)
				fastSet(A, true)
				fastSet(B, true)
			end
		end)
	end

	do
		local reg, ids = setup()
		local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()

		BENCH("Adding 4 component", function()
			for i = 1, START(N) do
				local e = ids[i]
				local fastSet = reg:addArchetype(e, A, B, C, D)
				fastSet(A, true)
				fastSet(B, true)
				fastSet(C, true)
				fastSet(D, true)
			end
		end)
	end
end

--[[do TITLE "Patching components"
    local function setup()
        local reg = arch.World()
        local ids = table.create(N)
        for i = 1, N do
            local e = reg:create()
            ids[i] = e
            reg:set(e, A, 0)
            reg:set(e, B, 0)
            reg:set(e, C, 0)
            reg:set(e, D, 0)
        end
        return reg, ids
    end
    
    local function patcher(v: number)
        return v + 1
    end
    
    do
        local reg, ids = setup()

        BENCH("Update 1 existing component", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:patch(e, A, patcher)
            end
        end)
    end
    
    do
        local reg, ids = setup()
        
        BENCH("Update 2 existing components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:patch(e, A, patcher)
                reg:patch(e, B, patcher)
            end
        end)
    end
    
    do
        local reg, ids = setup()
        
        BENCH("Update 4 existing components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:patch(e, A, patcher)
                reg:patch(e, B, patcher)
                reg:patch(e, C, patcher)
                reg:patch(e, D, patcher)
            end
        end)
    end
end]]

do
	TITLE("Has components")
	local reg = arch.World()
	local ids = table.create(N)
	local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

	for i = 1, N do
		ids[i] = reg:create()
		reg:set(ids[i], A, true)
		reg:set(ids[i], B, true)
		reg:set(ids[i], C, true)
		reg:set(ids[i], D, true)
	end

	BENCH("Has 1 component", function()
		for i = 1, START(N) do
			reg:has(ids[i], A)
		end
	end)

	BENCH("Has 2 component", function()
		for i = 1, START(N) do
			local e = ids[i]
			reg:has(e, A, B)
		end
	end)

	BENCH("Has 4 component", function()
		for i = 1, START(N) do
			local e = ids[i]
			reg:has(e, A, B, C, D)
		end
	end)
end

do
	TITLE("Getting components")
	local reg = arch.World()
	local ids = table.create(N)
	local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
	local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

	for i = 1, N do
		local e = reg:create()
		ids[i] = e
		reg:set(e, A, true)
		reg:set(e, B, true)
		reg:set(e, C, true)
		reg:set(e, D, true)

		reg:set(e, E, true)
		reg:set(e, F, true)
		reg:set(e, G, true)
		reg:set(e, H, true)
	end

	BENCH("Get 1 component", function()
		for i = 1, START(N) do
			reg:get(ids[i], A)
		end
	end)

	BENCH("Get 2 components", function()
		for i = 1, START(N) do
			local e = ids[i]
			reg:get(e, A, B)
		end
	end)

	BENCH("Get 4 components", function()
		for i = 1, START(N) do
			local e = ids[i]
			reg:get(e, A, B, C, D)
		end
	end)

	BENCH("Get 8 components", function()
		for i = 1, START(N) do
			reg:get(ids[i], A, B, C, D, E, F, G, H)
		end
	end)

	BENCH("Try get component", function()
		for i = 1, START(N) do
			reg:tryGet(ids[i], A)
		end
	end)
end

do
	TITLE("Removing components")
	local function setup()
		local reg = arch.World()
		local ids = table.create(N)
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		for i = 1, N do
			local e = reg:create()
			ids[i] = e
			reg:set(e, A, true)
			reg:set(e, B, true)
			reg:set(e, C, true)
			reg:set(e, D, true)
			reg:set(e, E, true)
			reg:set(e, F, true)
			reg:set(e, G, true)
			reg:set(e, H, true)
		end
		return reg, ids
	end

	BENCH("Attempt remove of non-existant component", function()
		local reg, ids = setup()
		local A = reg:component()
		for i = 1, N do
			reg:remove(ids[i], A)
		end

		for i = 1, START(N) do
			reg:remove(ids[i], A)
		end
	end)

	BENCH("Remove 1 component", function()
		local reg, ids = setup()
		local A = reg:component()
		for i = 1, START(N) do
			reg:remove(ids[i], A)
		end
	end)

	BENCH("Remove 2 components", function()
		local reg, ids = setup()
		local A, B = reg:component(), reg:component()
		for i = 1, START(N) do
			local e = ids[i]
			reg:remove(e, A, B)
		end
	end)

	BENCH("Remove 4 components", function()
		local reg, ids = setup()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		for i = 1, START(N) do
			local e = ids[i]
			reg:remove(e, A, B, C, D)
		end
	end)

	BENCH("Remove 8 components", function()
		local reg, ids = setup()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		for i = 1, START(N) do
			local e = ids[i]
			reg:remove(e, A, B, C, D, E, F, G, H)
		end
	end)
end

do
	TITLE("Getting Archetypes")

	BENCH("Get new archetype 1 component", function()
		local reg = arch.World()
		local A = reg:component()
		START()

		reg:_getArchetype(A)
	end)

	BENCH("Get new archetype 2 components", function()
		local reg = arch.World()
		local A, B = reg:component(), reg:component()
		START()

		reg:_getArchetype(A, B)
	end)

	BENCH("Get new archetype 4 components", function()
		local reg = arch.World()
		local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
		START()

		reg:_getArchetype(A, B, C, D)
	end)

	BENCH("Get new archetype 8 components", function()
		local reg = arch.World()
		local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
		local E, F, G, H = reg:component(), reg:component(), reg:component(), reg:component()
		START()

		reg:_getArchetype(A, B, C, D, E, F, G, H)
	end)

	BENCH("Get new archetype 32 components", function()
		local reg = arch.World()
		local tuple = table.create(32)
		for i = 1, 32 do
			tuple[i] = reg:component()
		end
		START()

		reg:_getArchetype(unpack(tuple))
	end)

	BENCH("Get existing archetype 1 component", function()
		local reg = arch.World()
		local A = reg:component()
		reg:_getArchetype(A)
		START()

		reg:_getArchetype(A)
	end)

	BENCH("Get existing archetype 2 components", function()
		local reg = arch.World()
		local A, B = reg:component(), reg:component()
		reg:_getArchetype(A, B)
		START()

		reg:_getArchetype(A, B)
	end)

	BENCH("Get existing archetype 4 components", function()
		local reg = arch.World()
		local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
		reg:_getArchetype(A, B, C, D)
		START()

		reg:_getArchetype(A, B, C, D)
	end)

	BENCH("Get existing archetype 8 components", function()
		local reg = arch.World()
		local A, B, C, D = reg:component(), reg:component(), reg:component(), reg:component()
		local E, F, G, H = reg:component(), reg:component(), reg:component(), reg:component()
		reg:_getArchetype(A, B, C, D, E, F, G, H)
		START()

		reg:_getArchetype(A, B, C, D, E, F, G, H)
	end)

	BENCH("Get existing archetype 32 components", function()
		local reg = arch.World()
		local tuple = table.create(32)
		for i = 1, 32 do
			tuple[i] = reg:component()
		end
		reg:_getArchetype(unpack(tuple))
		START()

		reg:_getArchetype(unpack(tuple))
	end)
end

--]]

--[[do TITLE ("Handles")
    local N2 = N/32

    local reg = arch.World()
    local ids = table.create(N2)

    for i = 1, N2 do
        ids[i] = reg:create()
    end

    BENCH("Create new handles", function()
        for i = 1, START(N2) do
            reg:handle(ids[i])
        end
    end)

    -- cache to prevent gc when starting next benchmark
    local cache = table.create(N2)
    for i = 1, N2 do
        cache[i] = reg:handle(ids[i])
    end

    BENCH("Reuse cached handles", function()
        for i = 1, START(N2) do
            reg:handle(ids[i])
        end
    end)
end]]

--[[do TITLE "Registry group"
    do
        local reg = arch.World()

        local group = reg:group(A, B)

        local ids = {}

        for i = 1, N do
            ids[i] = reg:create()
        end

        BENCH("Add 2 components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:set(e, A, 1)
                reg:set(e, B, 2)
            end
        end)

        BENCH("Iterate 2 components", function()
            START(N)
            for entity, a, b in group do end
        end)

        BENCH("Remove 2 components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:set(e, A, nil)
                reg:set(e, B, nil)
            end
        end)
    end

    do
        local reg = arch.World()

        local group2 = reg:group(C, D, E, F)
        
        local ids = {}

        for i = 1, N do
            ids[i] = reg:create()
        end

        BENCH("Add 4 components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:set(e, C, 1)
                reg:set(e, D, 2)
                reg:set(e, E, 3)
                reg:set(e, F, 4)
            end
        end)

        BENCH("Iterate 4 components", function()
            START(N)
            for entity, a, b, c, d in group2 do end
        end)

        BENCH("Remove 4 components", function()
            for i = 1, START(N) do
                local e = ids[i]
                reg:set(e, C, nil)
                reg:set(e, D, nil)
                reg:set(e, E, nil)
                reg:set(e, F, nil)
            end
        end)
    end
end]]

do
	TITLE("Destroying entities")
	BENCH("Destroy entity with 0 components", function()
		local reg = arch.World()
		local ids = table.create(N)

		for i = 1, N do
			ids[i] = reg:create()
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with 1 components", function()
		local reg = arch.World()
		local ids = table.create(N)
		local A = reg:component()

		for i = 1, N do
			local e = reg:create()
			reg:set(e, A, true)
			ids[i] = e
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with 2 components", function()
		local reg = arch.World()
		local ids = table.create(N)
		local A, B = reg:component(), reg:component()

		for i = 1, N do
			local e = reg:create()
			reg:set(e, A, true)
			reg:set(e, B, true)
			ids[i] = e
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with 4 components", function()
		local reg = arch.World()
		local ids = table.create(N)
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		for i = 1, N do
			local e = reg:create()
			reg:set(e, A, true)
			reg:set(e, B, true)
			reg:set(e, C, true)
			reg:set(e, D, true)
			ids[i] = e
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with no components (8 component registered)", function()
		local reg = arch.World()
		local ids = table.create(N)
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		for i = 1, N do
			local e = reg:create()
			ids[i] = e
		end

		do -- register all components
			local e = reg:create()
			reg:set(e, A, true)
			reg:set(e, B, true)
			reg:set(e, C, true)
			reg:set(e, D, true)
			reg:set(e, E, true)
			reg:set(e, F, true)
			reg:set(e, G, true)
			reg:set(e, H, true)
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with no components (128 component registered)", function()
		local reg = arch.World()

		do
			local id = reg:create()
			for i = 1, 128 do
				local component = reg:component()
				reg:set(id, component, true)
			end
		end

		local ids = table.create(N)

		for i = 1, N do
			ids[i] = reg:create()
		end

		for i = 1, START(N) do
			reg:destroy(ids[i])
		end
	end)

	BENCH("Destroy entity with no components (1024 component registered)", function()
		local reg = arch.World()

		do
			local id = reg:create()
			for i = 1, 1024 do
				local component = reg:component()
				reg:set(id, component, true)
			end
		end

		local ids = table.create(N)

		for i = 1, N / 10 do
			ids[i] = reg:create()
		end

		for i = 1, START(N / 10) do
			reg:destroy(ids[i])
		end
	end)
end

do
	TITLE("Clearing Entities")
	BENCH("Clear 2^18 entities", function()
		local reg = arch.World()
		local ids = table.create(N)
		for i = 1, N do
			ids[i] = reg:create()
		end

		START()

		reg:clear()
	end)
end

do
	TITLE("Create view")
	local reg = arch.World()
	local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
	local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

	reg:query(A, B, C, D, E, F, G, H) -- register components

	BENCH("View 1 component", function()
		for i = 1, START(N) do
			reg:query(A)
		end
	end)

	BENCH("View 4 component", function()
		for i = 1, START(N) do
			reg:query(A, B, C, D)
		end
	end)
end

do
	local function viewBench(reg, A, B, C, D, E, F, G, H)
		local function getExactSize(view): number
			local i = 0
			for _ in view do
				i += 1
			end
			return i
		end

		BENCH("Calculate compatible archetypes 1 component", function()
			local view = reg:query(A)

			view._update()
		end)

		BENCH("Calculate compatible archetypes 2 components", function()
			local view = reg:query(A, B)

			view._update()
		end)

		BENCH("Calculate compatible archetypes 4 components", function()
			local view = reg:query(A, B, C, D)

			view._update()
		end)

		BENCH("Calculate compatible archetypes 8 component", function()
			local view = reg:query(A, B, C, D, E, F, G, H)

			view._update()
		end)

		BENCH("View 1 component", function()
			local view = reg:query(A)

			START(getExactSize(view))
			for entity, a in view do
			end
		end)

		BENCH("View 2 components", function()
			local view = reg:query(A, B)

			START(getExactSize(view))
			for entity, a, b in view do
			end
		end)

		BENCH("View 4 components", function()
			local view = reg:query(A, B, C, D)

			START(getExactSize(view))
			for entity, a, b, c, d in view do
			end
		end)

		BENCH("View 8 components", function()
			local view = reg:query(A, B, C, D, E, F, G, H)

			START(getExactSize(view))
			for entity, a, b, c, d, e, f, g, h in view do
			end
		end)
	end

	do
		TITLE("View all entities with ordered components")
		local reg = arch.World()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		for i = 1, N do
			local entity = reg:create()
			reg:set(entity, A, true)
			reg:set(entity, B, true)
			reg:set(entity, C, true)
			reg:set(entity, D, true)
			reg:set(entity, E, true)
			reg:set(entity, F, true)
			reg:set(entity, G, true)
			reg:set(entity, H, true)
		end

		viewBench(reg, A, B, C, D, E, F, G, H)
	end

	do
		TITLE("View all entities with random components (50% distr.)")
		local reg = arch.World()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		local function flip()
			return math.random() > 0.5
		end

		for i = 1, N do
			local entity = reg:create()
			if flip() then reg:set(entity, A, true) end
			if flip() then reg:set(entity, B, true) end
			if flip() then reg:set(entity, C, true) end
			if flip() then reg:set(entity, D, true) end
			if flip() then reg:set(entity, E, true) end
			if flip() then reg:set(entity, F, true) end
			if flip() then reg:set(entity, G, true) end
			if flip() then reg:set(entity, H, true) end
		end

		viewBench(reg, A, B, C, D, E, F, G, H)
	end

	do
		TITLE("View all entities with common component (50% distr.)")
		-- 7 components are randomly assigned to entities,
		-- any entities that receive all 7 will be tagged with an 8th component.
		-- This guarantees that when iterating over this 8th component, all
		-- entities iterated will also contain the other 7.

		local reg = arch.World()
		local A, B, C, D = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)
		local E, F, G, H = reg:component(rtrue), reg:component(rtrue), reg:component(rtrue), reg:component(rtrue)

		local function flip()
			return math.random() > 0.5
		end

		for i = 1, N do
			local entity = reg:create()
			local b, c, d, e, f, g, h
			if flip() then
				b = true
				reg:set(entity, B, true)
			end
			if flip() then
				c = true
				reg:set(entity, C, true)
			end
			if flip() then
				d = true
				reg:set(entity, D, true)
			end
			if flip() then
				e = true
				reg:set(entity, E, true)
			end
			if flip() then
				f = true
				reg:set(entity, F, true)
			end
			if flip() then
				g = true
				reg:set(entity, G, true)
			end
			if flip() then
				h = true
				reg:set(entity, H, true)
			end
			if b and c and d and e and f and g and h then reg:set(entity, A, true) end
		end

		viewBench(reg, A, B, C, D, E, F, G, H)
	end

	--[[do TITLE("View tags")
        local reg = arch.World()

        for i = 1, N do
            local e = reg:handle()
            e:add(TA, TB, TC, TD)
        end

        BENCH("View 1 tag", function()
            START(N)
            for id, a in reg:query(TA) do end
        end)

        BENCH("View 4 tag", function()
            START(N)
            for id, a, b, c, d in reg:query(TA, TB, TC, TD) do end
        end)
    end]]
end

do
	TITLE("Valid id checking")
	BENCH("registry::contains", function()
		local reg = arch.World()
		local ids = table.create(N)
		for i = 1, N do
			ids[i] = reg:create()
		end

		START(N)

		for i = 1, N do
			reg:contains(ids[i])
		end
	end)
end

--[[do TITLE "Registry signals"
    local reg = arch.World()
    local ids = table.create(N)

    for i = 1, N do
        ids[i] = reg:create()
    end

    BENCH("registry::added", function()
        reg:added(A):connect(function() end)

        for i = 1, START(N) do
            reg:set(ids[i], A, true)
        end
    end)

    BENCH("registry::changed", function()
        reg:changed(A):connect(function() end)

        for i = 1, START(N) do
            reg:set(ids[i], A, false)
        end
    end)


    BENCH("registry::removing", function()
        reg:removing(A):connect(function() end)

        for i = 1, START(N) do
            reg:remove(ids[i], A)
        end
    end)
end

do TITLE "Observers"
    local reg = arch.World()
    local observer = reg:track(A)

    local ids = table.create(N)
    for i = 1, N do
        ids[i] = reg:create()
    end

    BENCH("Add component", function()
        for i = 1, START(N) do
            reg:set(ids[i], A, true)
        end
    end)

    BENCH("Change component", function()
        for i = 1, START(N) do
            reg:set(ids[i], A, false)
        end
    end)

    BENCH("Iterate", function()
        START(N)
        for id, v in observer do end
    end)

    BENCH("Remove component", function()
        for i = 1, START(N) do
            reg:set(ids[i], A, nil)
        end
    end)

    BENCH("Clear", function()
        START(N)
        observer:clear()
    end)
end

do TITLE "Queues"
    do
        local q = ecr.queue()

        BENCH("Add 1", function()
            for i = 1, START(N) do
                q:add(i)
            end
        end)

        BENCH("Iter 1", function()
            START(N)
            for i in q do end
        end)
    end

    do
        local q = ecr.queue()

        BENCH("Add 4", function()
            for i = 1, START(N) do
                q:add(i, i, i, i)
            end
        end)

        BENCH("Iter 4", function()
            START(N)
            for a, b, c, d in q do end
        end)
    end
end]]

do
	TITLE("Practical tests")
	local world = arch.World()

	local Position = world:component() :: number
	local Velocity = world:component() :: number
	local Health = world:component() :: number

	local Dead = world:component(rtrue)

	--world:group(Position, Velocity)

	local function init()
		for i = 1, 2 ^ 12 do -- ~4k
			local id = world:create()
			local fastSet = world:addArchetype(id, Position, Velocity, Health)
			fastSet(Position, i)
			fastSet(Velocity, i)
			fastSet(Health, 0)
		end
	end

	BENCH("Create ~4k entities with 3 components", function()
		init()
	end)

	BENCH("Update position ~4k entities", function()
		for id, pos, vel in world:query(Position, Velocity) do
			world:set(id, Position, pos + vel * 1 / 60)
		end
	end)

	--[[BENCH("Raw update position ~4k entities", function()
		local n = #world:group(Position, Velocity)
		local positions = world:storage(Position).values
		local velocities = world:storage(Velocity).values

		for i = 1, n do
			positions[i] = positions[i] + velocities[i] * 1 / 60
		end
	end)]]

	BENCH("Add tag ~4k entities", function()
		for id, health in world:query(Health) do
			if health <= 0 then world:set(id, Dead, true) end
		end
	end)

	BENCH("Destroy ~4k entities", function()
		for id in world:query(Dead) do
			world:destroy(id)
		end
	end)
end

-- attempt to repeat the same test above but with regular OOP instead of ECS
-- this is just curiosity to see how ECS really fares against OOP in Luau
do
	TITLE("Practical test OOP")
	local world = {}

	local cache = {}

	type Obj = {
		Position: number,
		Velocity: number,
		Health: number,
		Dead: boolean,
	}

	-- luaus table allocator is really good and allocates tables in linear
	-- pages in memory, causing sequential access to tables to hit cache.
	-- i dont think this would occur in complex real games unless you
	-- specifically design for it so attempt to randomize here to try
	-- eliminate cache hits (this reduces performance by around ~5x)
	do
		for i = 1, 2 ^ 15 do
			cache[i] = {
				Position = 0,
				Velocity = 0,
				Health = 0,
				-- dummy fields
				A = 0,
				B = 0,
				C = 0,
				D = 0,
			}
		end

		for i = 1, 2 ^ 12 do
			world[i] = cache[math.random(1, #cache)]
			table.clear(world[i])
		end
	end

	BENCH("Create ~4k entities with 3 components", function()
		for i = 1, 2 ^ 12 do
			world[i].Position = i
			world[i].Velocity = i
			world[i].Health = 0
		end
	end)

	BENCH("Update position ~4k entities", function()
		for _, obj in world do
			obj.Position = obj.Position + obj.Velocity * 1 / 60
		end
	end)

	BENCH("Add tag ~4k entities", function()
		for _, obj in world do
			if obj.Health <= 0 then obj.Dead = true end
		end
	end)

	BENCH("Destroy ~4k entities", function()
		table.clear(world)
		collectgarbage("collect" :: any) -- this probably isnt a fair test
	end)
end
