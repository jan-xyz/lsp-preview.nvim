local lWorkspaceEdit = require("lsp-preview.workspace_edit")
local config = require("lsp-preview.config")

local util = require("vim.lsp.util")

local M = {}

-- The original workspace_edit from the std library of vim for backup and resets.
local apply_workspace_edit = util.apply_workspace_edit

---Setup the default behaviour of the plugin
---@param opts Options
function M.setup(opts)
	config.setup(opts)
end

---A drop-in replacement for vim.lsp.buf.rename which can preview the chanes.
---@param new_name string
---@param opts table See M.setup for more information
function M.rename(new_name, opts)
	opts = config.adhoc_merge(opts or {})

	-- Reset it to the original before every operation in case of a failure.
	---@diagnostic disable-next-line: duplicate-set-field
	util.apply_workspace_edit = apply_workspace_edit

	-- built-in behaviour if preview is disabled
	if not opts.preview then
		vim.lsp.buf.rename(new_name, opts)
		return
	end

	---@diagnostic disable-next-line: duplicate-set-field
	util.apply_workspace_edit = lWorkspaceEdit.make_apply_workspace_edit(apply_workspace_edit)

	vim.lsp.buf.rename(new_name, opts)
end

function M.rename_preview(new_name, opts)
	opts = opts or {}
	opts.preview = true
	M.rename(new_name, opts)
end

---A drop-in replacement for vim.lsp.buf.code_action which can preview
---the changes.
---@param opts table See M.setup for more information
function M.code_action(opts)
	opts = config.adhoc_merge(opts or {})

	-- Reset it to the original before every operation in case of a failure.
	---@diagnostic disable-next-line: duplicate-set-field
	util.apply_workspace_edit = apply_workspace_edit

	-- built-in behaviour if preview is disabled
	if not opts.preview then
		vim.lsp.buf.code_action(opts)
		return
	end

	---@diagnostic disable-next-line: duplicate-set-field
	util.apply_workspace_edit = lWorkspaceEdit.make_apply_workspace_edit(apply_workspace_edit)

	vim.lsp.buf.code_action(opts)
end

function M.code_action_preview(opts)
	opts = opts or {}
	opts.preview = true
	M.code_action(opts)
end

return M
