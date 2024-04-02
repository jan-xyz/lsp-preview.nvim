-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local lEdits = require("lsp-preview.buffer_edits")
local minidiff = require("mini.diff")

local M = {}

------------------
--- Rename ------
------------------

---@class Rename: Previewable
---@field change RenameFile
---@field offset_encoding string
---@field old_path string
---@field new_path string
local Rename = {}

---@param change RenameFile
---@param offset_encoding string
---@return Rename
function Rename.new(change, offset_encoding)
	return setmetatable({
		change = change,
		old_path = vim.fn.fnamemodify(vim.uri_to_fname(change.oldUri), ":."),
		new_path = vim.fn.fnamemodify(vim.uri_to_fname(change.newUri), ":."),
		offset_encoding = offset_encoding,
	}, { __index = Rename })
end

---@return string
function Rename:title()
	return "Rename: " .. self.old_path .. " -> " .. self.new_path
end

---@return string
function Rename:filename()
	return self.old_path
end

---@return string filetype
function Rename:preview(bufnr, _, _)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "no preview" })
	return ""
end

------------------
--- Create ------
------------------

---@class Create: Previewable
---@field change CreateFile
---@field offset_encoding string
---@field path string
local Create = {}

---@param change CreateFile
---@param offset_encoding string
---@return Create
function Create.new(change, offset_encoding)
	return setmetatable({
		change = change,
		path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":."),
		offset_encoding = offset_encoding,
	}, { __index = Create })
end

---@return string
function Create:title()
	return "Create: " .. self.change.uri
end

---@return string
function Create:filename()
	return self.path
end

---@return string filetype
function Create:preview(bufnr, _, _)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "no preview" })
	return ""
end

------------------
--- Delete ------
------------------

---@class Delete: Previewable
---@field change DeleteFile
---@field offset_encoding string
---@field path string
local Delete = {}

---@param change DeleteFile
---@param offset_encoding string
---@return Delete
function Delete.new(change, offset_encoding)
	return setmetatable({
		change = change,
		path = vim.fn.fnamemodify(vim.uri_to_fname(change.uri), ":."),
		offset_encoding = offset_encoding,
	}, { __index = Delete })
end

---@return string
function Delete:title()
	return "Delete: " .. self.change.uri
end

---@return string
function Delete:filename()
	return self.path
end

---@return string filetype
function Delete:preview(bufnr, _, _)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "no preview" })
	return ""
end

------------------
--- Edit ------
------------------

---@class Edit: Previewable
---@field change TextDocumentEdit
---@field index "all" | number
---@field uri string
---@field edits table
---@field path string
---@field old_text string
---@field new_text string
---@field offset_encoding string
local Edit = {}

---@param index "all" | number
---@param uri string
---@param edits TextEdit[]
---@param offset_encoding string
---@return Edit
function Edit.new(index, uri, edits, offset_encoding)
	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	local bufnr = vim.uri_to_bufnr(uri)
	local old_text, new_text = lEdits.edit_buffer_text(edits, bufnr, offset_encoding)

	return setmetatable({
		index = index,
		uri = uri,
		edits = edits,
		path = path,
		old_text = old_text,
		new_text = new_text,
		offset_encoding = offset_encoding,
	}, { __index = Edit })
end

---@return string
function Edit:title()
	return "Edit: " .. self.path .. ":" .. self.index
end

---@return string
function Edit:filename()
	return self.path
end

---@return string filetype
function Edit:preview(bufnr, winid, opts)
	opts = opts or {}

	-- set lines in buffer to the changed output
	---@type string
	local text = self.new_text
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))

	-- setup minidiff
	vim.b[bufnr].minidiff_config = { source = { attach = function() end } }
	minidiff.set_ref_text(bufnr, self.old_text)
	if not minidiff.get_buf_data(bufnr).overlay then
		minidiff.toggle_overlay(bufnr, self.old_text)
	end

	-- scroll change into view
	local lnum = self.edits[1].range.start.line + 1
	-- calling it with pcall because the window is not set on initial creation.
	pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })

	-- return file type
	return vim.filetype.match({ filename = self.path }) or ""
end

------------------------------------------------------------


---@param workspace_edit WorkspaceEdit
---@return Previewable[], Previewable[]
function M.get_changes(workspace_edit, offset_encoding)
	---@type Previewable[]
	local documentChanges = {}
	local changes = {}

	if workspace_edit.documentChanges then
		for _, change in ipairs(workspace_edit.documentChanges) do
			if change.kind == "rename" then
				---@cast change RenameFile
				table.insert(documentChanges, Rename.new(change, offset_encoding))
			elseif change.kind == "create" then
				---@cast change CreateFile
				table.insert(documentChanges, Create.new(change, offset_encoding))
			elseif change.kind == "delete" then
				---@cast change DeleteFile
				table.insert(documentChanges, Delete.new(change, offset_encoding))
			elseif not change.kind then
				---@cast change TextDocumentEdit
				table.insert(documentChanges, Edit.new("all", change.textDocument.uri, change.edits, offset_encoding))
				for index, edit in ipairs(change.edits) do
					table.insert(documentChanges, Edit.new(index, change.textDocument.uri, { edit }, offset_encoding))
				end
			else
				vim.notify("unknown change kind")
			end
		end
	elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
		for uri, edits in pairs(workspace_edit.changes) do
			table.insert(changes, Edit.new("all", uri, edits, offset_encoding))
			for index, edit in ipairs(edits) do
				table.insert(documentChanges, Edit.new(index, uri, { edit }, offset_encoding))
			end
		end
	end

	return documentChanges, changes
end

return M
