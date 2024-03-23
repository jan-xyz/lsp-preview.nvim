-- BELOW IS A COPY OF THE NEOVIM IMPLEMENTATION
-- THE ONLY MODIFICATION IS TO PASS IN A CUSTOM FUNCTION TO HANDLE ACTIONS
-- PLEASE DO NOT MODIFY APART FROM KEEPING IT UP-TO-DATE WITH UPSTREAM
-- https://github.com/neovim/neovim/blob/v0.9.5/runtime/lua/vim/lsp/buf.lua
local api = vim.api
local validate = vim.validate
local util = require("vim.lsp.util")

local M = {}

---@private
--
--- This is not public because the main extension point is
--- vim.ui.select which can be overridden independently.
---
--- Can't call/use vim.lsp.handlers['textDocument/codeAction'] because it expects
--- `(err, CodeAction[] | Command[], ctx)`, but we want to aggregate the results
--- from multiple clients to have 1 single UI prompt for the user, yet we still
--- need to be able to link a `CodeAction|Command` to the right client for
--- `codeAction/resolve`
local function on_code_action_results(results, ctx, options)
	local action_tuples = {}

	---@private
	local function action_filter(a)
		-- filter by specified action kind
		if options and options.context and options.context.only then
			if not a.kind then
				return false
			end
			local found = false
			for _, o in ipairs(options.context.only) do
				-- action kinds are hierarchical with . as a separator: when requesting only
				-- 'quickfix' this filter allows both 'quickfix' and 'quickfix.foo', for example
				if a.kind:find("^" .. o .. "$") or a.kind:find("^" .. o .. "%.") then
					found = true
					break
				end
			end
			if not found then
				return false
			end
		end
		-- filter by user function
		if options and options.filter and not options.filter(a) then
			return false
		end
		-- no filter removed this action
		return true
	end

	for client_id, result in pairs(results) do
		for _, action in pairs(result.result or {}) do
			if action_filter(action) then
				table.insert(action_tuples, { client_id, action })
			end
		end
	end
	if #action_tuples == 0 then
		vim.notify("No code actions available", vim.log.levels.INFO)
		return
	end

	---@private
	-- TODO: Make this handle multiple selected edits
	local function apply_action(action, client)
		if action.edit then
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

	---@private
	local function on_user_choice(action_tuple)
		if not action_tuple then
			return
		end
		-- textDocument/codeAction can return either Command[] or CodeAction[]
		--
		-- CodeAction
		--  ...
		--  edit?: WorkspaceEdit    -- <- must be applied before command
		--  command?: Command
		--
		-- Command:
		--  title: string
		--  command: string
		--  arguments?: any[]
		--
		local client = assert(vim.lsp.get_client_by_id(action_tuple[1]))
		local action = action_tuple[2]
		-- CUSTOM MODIFICATION
		local local_apply_action = options.apply_action or apply_action
		if not action.edit and client and vim.tbl_get(client.server_capabilities, "codeActionProvider", "resolveProvider")
		then
			client.request("codeAction/resolve", action, function(err, resolved_action)
				if err then
					if action.command then
						local_apply_action(action, client)
					else
						vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
					end
				else
					local_apply_action(resolved_action, client)
				end
			end)
		else
			local_apply_action(action, client)
		end
	end

	-- If options.apply is given, and there are just one remaining code action,
	-- apply it directly without querying the user.
	if options and options.apply and #action_tuples == 1 then
		on_user_choice(action_tuples[1])
		return
	end

	vim.ui.select(action_tuples, {
		prompt = "Code actions:",
		kind = "codeaction",
		format_item = function(action_tuple)
			local title = action_tuple[2].title:gsub("\r\n", "\\r\\n")
			return title:gsub("\n", "\\n")
		end,
	}, on_user_choice)
end



--- Requests code actions from all clients and calls the handler exactly once
--- with all aggregated results
---@private
local function code_action_request(params, options)
	local bufnr = api.nvim_get_current_buf()
	local method = "textDocument/codeAction"
	vim.lsp.buf_request_all(bufnr, method, params, function(results)
		local ctx = { bufnr = bufnr, method = method, params = params }
		on_code_action_results(results, ctx, options)
	end)
end

---@private
---@param bufnr integer
---@param mode "v"|"V"
---@return table {start={row, col}, end={row, col}} using (1, 0) indexing
local function range_from_selection(bufnr, mode)
	-- TODO: Use `vim.region()` instead https://github.com/neovim/neovim/pull/13896

	-- [bufnum, lnum, col, off]; both row and column 1-indexed
	local start = vim.fn.getpos("v")
	local end_ = vim.fn.getpos(".")
	local start_row = start[2]
	local start_col = start[3]
	local end_row = end_[2]
	local end_col = end_[3]

	-- A user can start visual selection at the end and move backwards
	-- Normalize the range to start < end
	if start_row == end_row and end_col < start_col then
		end_col, start_col = start_col, end_col
	elseif end_row < start_row then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end
	if mode == "V" then
		start_col = 1
		local lines = api.nvim_buf_get_lines(bufnr, end_row - 1, end_row, true)
		end_col = #lines[1]
	end
	return {
		["start"] = { start_row, start_col - 1 },
		["end"] = { end_row, end_col - 1 },
	}
end

--- Selects a code action available at the current
--- cursor position.
---
---@param options table|nil Optional table which holds the following optional fields:
---  - context: (table|nil)
---      Corresponds to `CodeActionContext` of the LSP specification:
---        - diagnostics (table|nil):
---                      LSP `Diagnostic[]`. Inferred from the current
---                      position if not provided.
---        - only (table|nil):
---               List of LSP `CodeActionKind`s used to filter the code actions.
---               Most language servers support values like `refactor`
---               or `quickfix`.
---        - triggerKind (number|nil): The reason why code actions were requested.
---  - filter: (function|nil)
---           Predicate taking an `CodeAction` and returning a boolean.
---  - apply: (boolean|nil)
---           When set to `true`, and there is just one remaining action
---          (after filtering), the action is applied without user query.
---
---  - range: (table|nil)
---           Range for which code actions should be requested.
---           If in visual mode this defaults to the active selection.
---           Table must contain `start` and `end` keys with {row, col} tuples
---           using mark-like indexing. See |api-indexing|
---
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_codeAction
---@see vim.lsp.protocol.constants.CodeActionTriggerKind
function M.code_action(options)
	validate({ options = { options, "t", true } })
	options = options or {}
	-- Detect old API call code_action(context) which should now be
	-- code_action({ context = context} )
	if options.diagnostics or options.only then
		options = { options = options }
	end
	local context = options.context or {}
	if not context.triggerKind then
		context.triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked
	end
	if not context.diagnostics then
		local bufnr = api.nvim_get_current_buf()
		context.diagnostics = vim.lsp.diagnostic.get_line_diagnostics(bufnr)
	end
	local params
	local mode = api.nvim_get_mode().mode
	if options.range then
		assert(type(options.range) == "table", "code_action range must be a table")
		local start = assert(options.range.start, "range must have a `start` property")
		local end_ = assert(options.range["end"], "range must have a `end` property")
		params = util.make_given_range_params(start, end_)
	elseif mode == "v" or mode == "V" then
		local range = range_from_selection(0, mode)
		params = util.make_given_range_params(range.start, range["end"])
	else
		params = util.make_range_params()
	end
	params.context = context
	code_action_request(params, options)
end

return M
