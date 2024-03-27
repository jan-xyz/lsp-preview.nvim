local lBuf = require("lsp-preview.buf")
local lDiff = require("lsp-preview.diff")
local lTelescope = require("lsp-preview.telescope")

local util = require("vim.lsp.util")

local M = {}

function M.setup(_)

end

--- A function that creates a apply_function for the telescope picker.
--- The picker can call this function with the selected changes from the picker
--- which in turn filters the list of changes and applies them.
---@param action CodeAction
---@return fun(selected_indices: integer[])
local function make_apply_action(ctx, action, client)
	return function(selected_indices)
		if action.edit then
			-- TODO: this currently doesn't work with workspace changes
			-- TODO: indices is brittle because it breaks once the sorting changes
			-- TODO: enable picking individual edits.
			local filteredChanges = {}
			for _, index in ipairs(selected_indices) do
				table.insert(filteredChanges, action.edit.documentChanges[index])
			end
			action.edit.documentChanges = filteredChanges
			util.apply_workspace_edit(action.edit, client.offset_encoding)
		end
		if action.command then
			local command = type(action.command) == "table" and action.command or action
			local fn = client.commands[command.command] or vim.lsp.commands[command.command]
			if fn then
				local enriched_ctx = vim.deepcopy(ctx)
				enriched_ctx.client_id = client.id
				fn(command, enriched_ctx)
			else
				-- Not using command directly to exclude extra properties,
				-- see https://github.com/python-lsp/python-lsp-server/issues/146
				local params = {
					command = command.command,
					arguments = command.arguments,
					workDoneToken = command.workDoneToken,
				}
				client.request("workspace/executeCommand", params, nil, ctx.bufnr)
			end
		end
	end
end


---@param action CodeAction
local function apply_action(ctx, action, client)
	local changes = lDiff.get_diffs(action.edit, client.offset_encoding)
	local opts = {}
	opts.diff = { ctxlen = 20 } -- provide a large diff context view
	lTelescope.apply_action(opts, changes, make_apply_action(ctx, action, client))
end

M.code_action = function(opts)
	opts = opts or {}
	opts.apply_action = apply_action
	opts.apply = true -- skip the vim.ui.select when there is only one action

	lBuf.code_action(opts)
end

return M
