local Components = {}

Components.count = 0

function Components.new()
	Components.count += 1
	return Components.count
end

return Components
