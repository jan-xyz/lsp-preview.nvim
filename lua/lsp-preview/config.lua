local M = {}

---@class Options
---Automatically apply code-actions if there is only 1 available.
---@field apply boolean
---Configuration provided to vim.diff (see `:h vim.diff()`)
---@field diff table
local default_config = {
	apply = true,
	diff = {
		ctxlen = 5,
	},
}


local user_config = default_config

function M.setup(config)
	user_config = vim.tbl_deep_extend("force", default_config, config)
end

setmetatable(M, {
	__index = function(_, key)
		return user_config[key]
	end,
})

return M