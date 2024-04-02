-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local lEdits = require("lsp-preview.buffer_edits")
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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Rename:preview(opts)
	---@type string
	local text = ""

	text = text .. string.format("diff --git a/%s b/%s\n", self.old_path, self.new_path)
	text = text .. string.format("rename from %s\n", self.old_path)
	text = text .. string.format("rename to %s\n", self.new_path)
	text = text .. "\n"

	return { text = text, syntax = "diff" }
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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Create:preview(opts)
	---@type string
	local text = ""

	text = text .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	-- delta needs file mode
	text = text .. "new file mode 100644\n"
	-- diff-so-fancy needs index
	text = text .. "index 0000000..fffffff\n"
	text = text .. "\n"

	return { text = text, syntax = "diff" }
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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Delete:preview(opts)
	---@type string
	local text = ""

	text = text .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	text = text .. string.format("--- a/%s\n", self.path)
	text = text .. "+++ /dev/null\n"
	text = text .. "\n"

	return { text = text, syntax = "diff" }
end

------------------
--- Edit ------
------------------

---@class Edit: Previewable
---@field change TextDocumentEdit
---@field uri string
---@field edits table
---@field path string
---@field old_text string
---@field new_text string
---@field offset_encoding string
local Edit = {}

---@param uri string
---@param edits TextEdit[]
---@param offset_encoding string
---@return Edit
function Edit.new(uri, edits, offset_encoding)
	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	local bufnr = vim.uri_to_bufnr(uri)
	local old_text, new_text = lEdits.edit_buffer_text(edits, bufnr, offset_encoding)

	return setmetatable({
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
	return "Edit: " .. self.path
end

---@return string
function Edit:filename()
	return self.path
end

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Edit:preview(opts)
	opts = opts or {}

	---@type string
	local text = ""

	---@type string
	local text_diff = vim.diff(self.old_text, self.new_text, opts.diff or {}) or ""

	text = text .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	text = text .. string.format("--- a/%s\n", self.path)
	text = text .. string.format("+++ b/%s\n", self.path)
	text = text .. vim.trim(text_diff) .. "\n"
	text = text .. "\n"

	return { text = text, syntax = "diff" }
end

------------------------------------------------------------


---@param workspace_edit WorkspaceEdit
---@return Previewable[], Previewable[]
function M.get_changes(workspace_edit, offset_encoding)
	---@type Previewable[]
	local documentChanges = {}
	local changes = {}

	if workspace_edit.documentChanges then
		for index, change in ipairs(workspace_edit.documentChanges) do
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
				table.insert(documentChanges, Edit.new(change.textDocument.uri, change.edits, offset_encoding))
				for index2, edit in ipairs(change.edits) do
					table.insert(documentChanges, Edit.new(change.textDocument.uri, { edit }, offset_encoding))
				end
			else
				vim.notify("unknown change kind")
			end
		end
	elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
		for uri, edits in pairs(workspace_edit.changes) do
			table.insert(changes, Edit.new(uri, edits, offset_encoding))
		end
	end

	return documentChanges, changes
end

return M
