local lBuf = require("lsp-preview.buf")
local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")

local M = {}

function M.setup(_)

end

---@param action CodeAction
local function apply_action(action, client)
	local changes = lDiff.get_diffs(action.edit, client.offset_encoding)
	local opts = {}
	opts.diff = { ctxlen = 20 } -- provide a large diff context view
	lTelescope.apply_action(opts, changes)
end

M.code_action = function(opts)
	opts = opts or {}
	opts.apply_action = apply_action
	opts.apply = true -- skip the vim.ui.select when there is only one action

	lBuf.code_action(opts)
end

return M
