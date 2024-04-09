-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local lEdits = require("lsp-preview.buffer_edits")

local M = {}

------------------
--- Rename ------
------------------

---@class Rename: Previewable
---@field index integer
---@field oldUri string
---@field newUri string
---@field title string
local Rename = {}

---@param index integer
---@param oldUri string
---@param newUri string
---@return Rename
function Rename.new(index, oldUri, newUri)
	local old_path = vim.fn.fnamemodify(vim.uri_to_fname(oldUri), ":.")
	local new_path = vim.fn.fnamemodify(vim.uri_to_fname(newUri), ":.")
	return setmetatable({
		index = index,
		oldUri = oldUri,
		newUri = newUri,
		title = "Rename: " .. old_path .. " -> " .. new_path,
	}, { __index = Rename })
end

---@return string
function Rename:filename()
	local old_path = vim.fn.fnamemodify(vim.uri_to_fname(self.oldUri), ":.")
	return old_path
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
---@field index integer
---@field uri string
---@field title string
local Create = {}

---@param index integer
---@param uri string
---@return Create
function Create.new(index, uri)
	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	return setmetatable({
		index = index,
		uri = uri,
		title = "Create: " .. path,
	}, { __index = Create })
end

---@return string
function Create:filename()
	local path = vim.fn.fnamemodify(vim.uri_to_fname(self.uri), ":.")
	return path
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
---@field uri string
---@field index integer
---@field title string
local Delete = {}

---@param index integer
---@param uri string
---@return Delete
function Delete.new(index, uri)
	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	return setmetatable({
		index = index,
		uri = uri,
		title = "Delete: " .. path,
	}, { __index = Delete })
end

---@return string
function Delete:filename()
	local path = vim.fn.fnamemodify(vim.uri_to_fname(self.uri), ":.")
	return path
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
---@field uri string
---@field index {primary: integer, secondary: integer}
---@field edit TextEdit
---@field oldText string
---@field newText string
---@field title string
local Edit = {}

---@param index {primary: integer, secondary: integer}
---@param uri string
---@param edit TextEdit
---@return Edit
function Edit.new(index, uri, edit, offset_encoding)
	local bufnr = vim.uri_to_bufnr(uri)
	local oldText, newText = lEdits.edit_buffer_text({ edit }, bufnr, offset_encoding)

	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	return setmetatable({
		index = index,
		uri = uri,
		edit = edit,
		oldText = oldText,
		newText = newText,
		title = "Edit: " .. path .. ":" .. index.secondary,
	}, { __index = Edit })
end

---@return string
function Edit:filename()
	local path = vim.fn.fnamemodify(vim.uri_to_fname(self.uri), ":.")
	return path
end

---@return string filetype
function Edit:preview(bufnr, winid, opts)
	local minidiff = require("mini.diff")
	opts = opts or {}

	-- set lines in buffer to the changed output
	---@type string
	local text = self.newText
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))

	-- setup minidiff
	vim.b[bufnr].minidiff_config = { source = { attach = function() end } }
	minidiff.set_ref_text(bufnr, self.oldText)
	if not minidiff.get_buf_data(bufnr).overlay then
		minidiff.toggle_overlay(bufnr, self.oldText)
	end

	-- scroll change into view
	local lnum = self.edit.range.start.line + 1
	-- calling it with pcall because the window is not set on initial creation.
	pcall(vim.api.nvim_win_set_cursor, winid, { lnum, 0 })

	-- return file type
	local path = vim.fn.fnamemodify(vim.uri_to_fname(self.uri), ":.")
	return vim.filetype.match({ filename = path }) or ""
end

------------------------------------------------------------


---@param workspace_edit WorkspaceEdit
---@return Previewable[]
function M.get_changes(workspace_edit, offset_encoding)
	-- TODO: this function should also keep track of what type of change it is converting in the internal model
	-- and it should keep track of the location in the original workspace_edit.

	---@type Previewable[]
	local changes = {}

	-- as per specification either `documentChanges` or `changes` should be used,
	-- defaulting to `documentChanges`.
	if workspace_edit.documentChanges then
		for index, change in ipairs(workspace_edit.documentChanges) do
			if change.kind == "rename" then
				---@cast change RenameFile
				table.insert(changes, Rename.new(index, change.oldUri, change.newUri))
			elseif change.kind == "create" then
				---@cast change CreateFile
				table.insert(changes, Create.new(index, change.uri))
			elseif change.kind == "delete" then
				---@cast change DeleteFile
				table.insert(changes, Delete.new(index, change.uri))
			elseif not change.kind then
				---@cast change TextDocumentEdit
				for index2, edit in ipairs(change.edits) do
					table.insert(changes,
						Edit.new({ primary = index, secondary = index2 }, change.textDocument.uri, edit, offset_encoding))
				end
			else
				vim.notify("unknown change kind")
			end
		end
	elseif workspace_edit.changes then
		for uri, edits in pairs(workspace_edit.changes) do
			for index, edit in ipairs(edits) do
				table.insert(changes, Edit.new({ primary = 1, secondary = index }, uri, edit, offset_encoding))
			end
		end
	end

	return changes
end

---Compacting workspace_edit.documentChanges to make every index consecutive again.
---This method only exists because of the poor implementation to reconstruct
---the workspace_edit. It can probably be done without and be faster.
---@param x TextDocumentEdit[]
---|(TextDocumentEdit | CreateFile | RenameFile | DeleteFile)[]
---@return TextDocumentEdit[]
---|(TextDocumentEdit | CreateFile | RenameFile | DeleteFile)[]
---@private
local compactDocumentChanges = function(x)
	local ret = {}
	for _, value in pairs(x) do
		if value.edits then
			local edits = {}
			for _, edit in pairs(value.edits) do
				table.insert(edits, edit)
			end
			value.edits = edits
		end
		table.insert(ret, value)
	end
	return ret
end

---Compacting workspace_edit.changes to make every index consecutive again.
---This method only exists because of the poor implementation to reconstruct
---the workspace_edit. It can probably be done without and be faster.
---@param x table<string, TextEdit[]>
---@return table<string, TextEdit[]>
---@private
local compactChanges = function(x)
	local ret = {}
	for key, value in pairs(x) do
		local edits = {}
		for _, edit in pairs(value) do
			table.insert(edits, edit)
		end
		value = edits
		ret[key] = value
	end
	return ret
end

---Used as injection for the telescope picker to apply the selection.
---Filters the workspace edit for the selected hunks and applies it.
---@param workspace_edit WorkspaceEdit
---@param offset_encoding string
---@return fun(selected_indices: Entry[])
function M.make_apply_func(workspace_edit, offset_encoding, orig_apply_workspace_edits)
	return function(selected_entries)
		-- as per specification either `documentChanges` or `changes` should be used,
		-- defaulting to `documentChanges`.
		if workspace_edit.documentChanges then
			local changes = {}
			for _, entry in ipairs(selected_entries) do
				local index = entry.value.index
				if type(index) == "number" then
					---@cast index integer
					local change = workspace_edit.documentChanges[entry.value.index]
					table.insert(changes, index, change)
				elseif type(index) == "table" then
					---@cast index {primary: integer, secondary: integer}
					---@type TextDocumentEdit
					local change = vim.F.if_nil(changes[index.primary], {
						textDocument = workspace_edit.documentChanges[index.primary].textDocument,
						edits = {},
					})
					change.edits[index.secondary] = workspace_edit.documentChanges[index.primary].edits[index.secondary]
					changes = vim.tbl_extend("force", changes, { [index.primary] = change })
				end
			end
			workspace_edit.documentChanges = compactDocumentChanges(changes)
		elseif workspace_edit.changes then
			local changes = {}
			for _, entry in ipairs(selected_entries) do
				local index = entry.value.index
				local uri = entry.value.uri
				---@cast index {primary: integer, secondary: integer}
				---@type TextDocumentEdit
				local change = vim.F.if_nil(changes[uri], {})
				change[index.secondary] = workspace_edit.changes[uri][index.secondary]
				changes = vim.tbl_extend("force", changes, { [uri] = change })
			end
			workspace_edit.changes = compactChanges(changes)
		end
		orig_apply_workspace_edits(workspace_edit, offset_encoding)
	end
end

return M
