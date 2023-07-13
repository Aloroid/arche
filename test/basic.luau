local arch = require("src/init")
local testkit = require("test/testkit")
local BENCH, START = testkit.benchmark()

local reg = arch.World()
local A, B = arch.component(), arch.component()

local id = reg:create()

print("created id", id)
reg:addArchetype(id, A, B)
reg:set(id, A, true)
reg:set(id, B, true)
