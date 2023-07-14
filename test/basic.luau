local arch = require("src/init")
local testkit = require("test/testkit")
local BENCH, START = testkit.benchmark()

local reg = arch.World()
local A, B, C = reg:component(), reg:component(), reg:component()

local id = reg:create()

print("created id", id)
reg:set(id, A, true)
print(reg:get(id, A))
reg:set(id, B, true)
reg:set(id, C, true)
