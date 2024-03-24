-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local lEdits = require("lsp-preview.buffer_edits")
local M = {}

------------------
--- Rename ------
------------------

---@class Rename
---@field change RenameFile
---@field offset_encoding string
---@field old_path string
---@field new_path string
local Rename = {}

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
	return "Rename: " .. self.change.oldUri
end

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Rename:preview(opts)
	---@type string
	local diff = ""

	diff = diff .. string.format("diff --git a/%s b/%s\n", self.old_path, self.new_path)
	diff = diff .. string.format("rename from %s\n", self.old_path)
	diff = diff .. string.format("rename to %s\n", self.new_path)
	diff = diff .. "\n"

	return { text = diff, syntax = "diff" }
end

------------------
--- Create ------
------------------

---@class Create
---@field change CreateFile
---@field offset_encoding string
---@field path string
local Create = {}

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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Create:preview(opts)
	---@type string
	local diff = ""

	diff = diff .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	-- delta needs file mode
	diff = diff .. "new file mode 100644\n"
	-- diff-so-fancy needs index
	diff = diff .. "index 0000000..fffffff\n"
	diff = diff .. "\n"

	return { text = diff, syntax = "diff" }
end

------------------
--- Delete ------
------------------

---@class Delete
---@field change DeleteFile
---@field offset_encoding string
---@field path string
local Delete = {}

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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Delete:preview(opts)
	---@type string
	local diff = ""

	diff = diff .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	diff = diff .. string.format("--- a/%s\n", self.path)
	diff = diff .. "+++ /dev/null\n"
	diff = diff .. "\n"

	return { text = diff, syntax = "diff" }
end

------------------
--- Edit ------
------------------

---@class Edit
---@field change TextDocumentEdit
---@field uri string
---@field edits table
---@field path string
---@field old_text string
---@field new_text string
---@field offset_encoding string
local Edit = {}

---@param change TextDocumentEdit
---@param uri string
---@param edits TextEdit[]
---@param offset_encoding string
---@return Edit
function Edit.new(change, uri, edits, offset_encoding)
	local path = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":.")
	local bufnr = vim.uri_to_bufnr(uri)
	local old_text, new_text = lEdits.edit_buffer_text(edits, bufnr, offset_encoding)

	return setmetatable({
		change = change,
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

---@return { text: string, syntax: string } previewObject # the preview object used for backends
function Edit:preview(opts)
	opts = opts or {}

	---@type string
	local diff = ""

	---@type string
	local text_diff = vim.diff(self.old_text, self.new_text, opts.diff or {}) or ""

	diff = diff .. string.format("diff --git a/%s b/%s\n", self.path, self.path)
	diff = diff .. string.format("--- a/%s\n", self.path)
	diff = diff .. string.format("+++ b/%s\n", self.path)
	diff = diff .. vim.trim(text_diff) .. "\n"
	diff = diff .. "\n"

	return { text = diff, syntax = "diff" }
end

------------------------------------------------------------


---@param workspace_edit WorkspaceEdit
---@return table
function M.get_diffs(workspace_edit, offset_encoding)
	local changes = {}

	if workspace_edit.documentChanges then
		for _, change in ipairs(workspace_edit.documentChanges) do
			if change.kind == "rename" then
				table.insert(changes, Rename.new(change, offset_encoding))
			elseif change.kind == "create" then
				table.insert(changes, Create.new(change, offset_encoding))
			elseif change.kind == "delete" then
				table.insert(changes, Delete.new(change, offset_encoding))
			elseif change.kind then
				-- do nothing
			else
				table.insert(changes, Edit.new(change, change.textDocument.uri, change.edits, offset_encoding))
			end
		end
	elseif workspace_edit.changes and not vim.tbl_isempty(workspace_edit.changes) then
		for uri, edits in pairs(workspace_edit.changes) do
			table.insert(changes, Edit.new({}, uri, edits, offset_encoding))
		end
	end

	return changes
end

return M
