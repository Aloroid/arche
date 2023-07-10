local arch = require("src/init")
local testkit = require("test/testkit")

local TEST, CASE, CHECK, FINISH = testkit.test()

local reg = arch.World()
local A1, B2 = arch.component(), arch.component()

local id = reg:create()

print("created id", id)
print("set", reg:set(id, A1, true))
print("get", reg:get(id, A1))
print("set", reg:set(id, B2, true))
print("get", reg:try_get(id, A1))
print("remove", reg:remove(id, A1))
print("get", reg:get(id, A1))
