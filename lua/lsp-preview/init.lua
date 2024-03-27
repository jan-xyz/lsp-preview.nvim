local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")

local util = require("vim.lsp.util")

local orig_apply_workspace_edits = util.apply_workspace_edit

---Used as injection for the telescope picker to apply the selection.
---Filters the workspace edit for the selected hunks.
---@param workspace_edit WorkspaceEdit
---@param offset_encoding string
local make_apply_func = function(workspace_edit, offset_encoding)
	return function(selected_indices)
		local selected_edits = {}
		for _, index in ipairs(selected_indices) do
			local edit = workspace_edit.documentChanges[index]
			table.insert(selected_edits, edit)
		end
		workspace_edit.documentChanges = selected_edits
		orig_apply_workspace_edits(workspace_edit, offset_encoding)
	end
end


---Overwriting the built-in function with the selection and preview capabilities
---@param workspace_edit WorkspaceEdit
---@param offset_encoding string
---@diagnostic disable-next-line: duplicate-set-field
util.apply_workspace_edit = function(workspace_edit, offset_encoding)
	local changes = lDiff.get_changes(workspace_edit, offset_encoding)
	local opts = {}
	opts.diff = { ctxlen = 20 } -- provide a large diff context view


	-- TODO: doesn't work with workspaceChanges
	-- TODO: brittle when the indices get out of order
	lTelescope.apply_action(opts, changes, make_apply_func(workspace_edit, offset_encoding))
end


local M = {}

function M.setup(_)

end

return M
