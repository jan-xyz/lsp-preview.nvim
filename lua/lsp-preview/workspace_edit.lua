local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")
local config = require("lsp-preview.config")

local M = {}

---Used as injection for the telescope picker to apply the selection.
---Filters the workspace edit for the selected hunks and applies it.
---@param workspace_edit WorkspaceEdit
---@param offset_encoding string
---@return fun(selected_indices: Entry[])
local make_apply_func = function(workspace_edit, offset_encoding, orig_apply_workspace_edits)
	-- TODO: this whole function should move to diff.lua as part of the internal model conversion.
	return function(selected_indices)
		local documentChanges = {}
		local changes = {}
		for _, selection in ipairs(selected_indices) do
			if selection.value.type == "documentChanges" then
				local index = selection.value.index
				local edit = workspace_edit.documentChanges[index]
				table.insert(documentChanges, edit)
			elseif selection.value.type == "changes" then
				local entry = selection.value.payload
				---@cast entry Edit
				local edit = workspace_edit.changes[entry.uri]
				changes[entry.uri] = edit
			end
		end

		if not vim.tbl_isempty(documentChanges) then
			workspace_edit.documentChanges = documentChanges
		end
		if not vim.tbl_isempty(changes) then
			workspace_edit.changes = changes
		end
		orig_apply_workspace_edits(workspace_edit, offset_encoding)
	end
end

---Overwriting the built-in function with the selection and preview capabilities
---@param orig_apply_workspace_edits fun(workspace_edit: WorkspaceEdit, offset_encoding: string)
---@return fun(workspace_edit: WorkspaceEdit, offset_encoding: string)
M.make_apply_workspace_edit = function(orig_apply_workspace_edits)
	return function(workspace_edit, offset_encoding)
		local documentChanges, changes = lDiff.get_changes(workspace_edit, offset_encoding)

		local opts = config

		lTelescope.apply_action(
			opts,
			documentChanges,
			changes,
			make_apply_func(workspace_edit, offset_encoding, orig_apply_workspace_edits)
		)
	end
end

return M
