local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")
local config = require("lsp-preview.config")

local M = {}


---Overwriting the built-in function with the selection and preview capabilities
---@param orig_apply_workspace_edits fun(workspace_edit: WorkspaceEdit, offset_encoding: string)
---@return fun(workspace_edit: WorkspaceEdit, offset_encoding: string)
M.make_apply_workspace_edit = function(orig_apply_workspace_edits)
	return function(workspace_edit, offset_encoding)
		local changes = lDiff.get_changes(workspace_edit, offset_encoding)

		local opts = config

		lTelescope.apply_action(
			opts,
			changes,
			lDiff.make_apply_func(workspace_edit, offset_encoding, orig_apply_workspace_edits)
		)
	end
end

return M
