-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3
local M = {}

local Change = {}
M.Changes = Change

function Change.new(change)
	return setmetatable({
		change = change,
	}, { __index = Change })
end

function Change:title(opts)
	return self.change.path
end

function Change:preview(opts)
	opts = vim.tbl_extend("force", {
		pseudo_args = "--git",
	}, opts or {})

	local change = self.change
	local diff = ""
	-- imitate git diff
	if change.kind == "rename" then
		diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.old_path, change.new_path)
		diff = diff .. string.format("rename from %s\n", change.old_path)
		diff = diff .. string.format("rename to %s\n", change.new_path)
		diff = diff .. "\n"
	elseif change.kind == "create" then
		diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
		-- delta needs file mode
		diff = diff .. "new file mode 100644\n"
		-- diff-so-fancy needs index
		diff = diff .. "index 0000000..fffffff\n"
		diff = diff .. "\n"
	elseif change.kind == "delete" then
		diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
		diff = diff .. string.format("--- a/%s\n", change.path)
		diff = diff .. "+++ /dev/null\n"
		diff = diff .. "\n"
	elseif change.kind == "edit" then
		diff = diff .. string.format("diff %s a/%s b/%s\n", opts.pseudo_args, change.path, change.path)
		diff = diff .. string.format("--- a/%s\n", change.path)
		diff = diff .. string.format("+++ b/%s\n", change.path)
		diff = diff .. vim.trim(vim.diff(change.old, change.new, opts.diff or {})) .. "\n"
		diff = diff .. "\n"
	end
	return { text = diff, syntax = "diff" }
end

-- TODO: Should this be the `new` function?
function M.get_changes(workspace_edit, offset_encoding)
	local function get_lines(bufnr)
		vim.fn.bufload(bufnr)
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end

	local function get_eol(bufnr)
		local ff = vim.api.nvim_buf_get_option(bufnr, "fileformat")
		if ff == "dos" then
			return "\r\n"
		elseif ff == "unix" then
			return "\n"
		elseif ff == "mac" then
			return "\r"
		else
			error("invalid fileformat")
		end
	end

	local function apply_text_edits(text_edits, lines, offset_encoding)
		local temp_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
		vim.lsp.util.apply_text_edits(text_edits, temp_buf, offset_encoding)
		local new_lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, false)
		vim.api.nvim_buf_delete(temp_buf, { force = true })
		return new_lines
	end


	local function edit_buffer_text(text_edits, bufnr, offset_encoding)
		local eol = get_eol(bufnr)

		local lines = get_lines(bufnr)
		local new_lines = apply_text_edits(text_edits, lines, offset_encoding)
		return table.concat(lines, eol) .. eol, table.concat(new_lines, eol) .. eol
	end
	local changes = {}

	if workspace_edit.documentChanges then
		for _, change in ipairs(workspace_edit.documentChanges) do
			local changeSet = {}
			if change.kind == "rename" then
				local old_path = vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":.")
				local new_path = vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":.")

				changeSet = {
					kind = "rename",
					old_path = old_path,
					new_path = new_path,
				}
			elseif change.kind == "create" then
				local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

				changeSet = {
					kind = "create",
					path = path,
				}
			elseif change.kind == "delete" then
				local path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":.")

				changeSet = {
					kind = "delete",
					path = path,
				}
			elseif change.kind then
				-- do nothing
			else
				local uri = change.textDocument.uri
				local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
				local bufnr = vim.uri_to_bufnr(uri)
				local old, new = edit_buffer_text(change.edits, bufnr, offset_encoding)

				changeSet = {
					kind = "edit",
					path = path,
					old = old,
					new = new,
				}
			end
			table.insert(changes, Change.new(changeSet))
		end
	elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
		for uri, edits in pairs(workspace_edit.changes) do
			local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
			local bufnr = vim.uri_to_bufnr(uri)
			local old, new = edit_buffer_text(edits, bufnr, offset_encoding)

			table.insert(changes, Change.new({
				kind = "edit",
				path = path,
				old = old,
				new = new,
			}))
		end
	end

	return changes
end

return M
