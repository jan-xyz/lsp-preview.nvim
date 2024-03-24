local M = {}

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


---@ return string old
---@ return string new
function M.edit_buffer_text(text_edits, bufnr, offset_encoding)
	local eol = get_eol(bufnr)

	local lines = get_lines(bufnr)
	local new_lines = apply_text_edits(text_edits, lines, offset_encoding)
	return table.concat(lines, eol) .. eol, table.concat(new_lines, eol) .. eol
end

return M
