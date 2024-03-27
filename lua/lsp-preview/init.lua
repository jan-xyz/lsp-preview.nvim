local lWorkspaceEdit = require("lsp-preview.workspace_edit")

local util = require("vim.lsp.util")

local M = {}

local apply_workspace_edit = util.apply_workspace_edit

function M.setup(_)

end

M.rename = function(new_name, opts)
	opts = opts or {}

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

M.code_action = function(opts)
	opts = opts or {}

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

	-- automatically trigger Telescope when there is only one action
	opts.apply = true
	vim.lsp.buf.code_action(opts)
end

return M
