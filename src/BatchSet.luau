--[[

	BatchSet is used to quickly create a list of components

]]

local BatchSet = {}

function BatchSet.new<T>(component: T, value: T)
	return { component, value }
end

return BatchSet
