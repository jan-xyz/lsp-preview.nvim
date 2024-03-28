local M = {}

---Returns the contents of a buffer.
---@param bufnr integer
---@return string[]
local function get_lines(bufnr)
	vim.fn.bufload(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---Returns the eol encoding of a buffer.
---@param bufnr integer
---@return string
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

---Apply text edits to the lines of a file.
---@param text_edits TextEdit[]
---@param lines string[]
---@param offset_encoding string
---@return string[]
local function apply_text_edits(text_edits, lines, offset_encoding)
	local temp_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, lines)
	vim.lsp.util.apply_text_edits(text_edits, temp_buf, offset_encoding)
	local new_lines = vim.api.nvim_buf_get_lines(temp_buf, 0, -1, false)
	vim.api.nvim_buf_delete(temp_buf, { force = true })
	return new_lines
end


---Apply text edits to a buffer.
---@param text_edits TextEdit[]
---@param bufnr integer
---@param offset_encoding string
---@return string old
---@return string new
function M.edit_buffer_text(text_edits, bufnr, offset_encoding)
	local eol = get_eol(bufnr)

	local old_lines = get_lines(bufnr)
	local new_lines = apply_text_edits(text_edits, old_lines, offset_encoding)
	return table.concat(old_lines, eol) .. eol, table.concat(new_lines, eol) .. eol
end

return M
