local lAction = require("lsp-preview.action")
local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")

local M = {}

function M.setup(_)

end

local function apply_action(action, client)
	vim.notify(vim.inspect(action))
	local changes = action.edit and lDiff.get_changes(action.edit, client.offset_encoding)
	lTelescope.apply_action({}, changes)
end

M.code_action = function(opts)
	opts = opts or {}
	opts.apply_action = apply_action
	opts.apply = true -- skip the vim.ui.select when there is only one action
	opts.diff = { ctxlen = 20 }

	lAction.code_action(opts)
end

return M
