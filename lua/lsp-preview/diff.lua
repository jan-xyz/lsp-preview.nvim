---@class Rename: Previewable
---@param change RenameFile
---@param offset_encoding string
---@class Create: Previewable
---@param change CreateFile
---@param offset_encoding string
---@class Delete: Previewable
---@param change DeleteFile
---@param offset_encoding string
---@class Edit: Previewable
---@return Previewable[]
	---@type Previewable[]
				---@cast change RenameFile
				---@cast change CreateFile
				---@cast change DeleteFile
			elseif not change.kind then
				---@cast change TextDocumentEdit
			else
				vim.notify("unknown change kind")
			table.insert(changes, Edit.new({ edits = edits, textDocument = { uri = uri } }, uri, edits, offset_encoding))