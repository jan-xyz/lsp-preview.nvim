local M = {}

---@alias DocumentUri string
--- An identifier referring to a change annotation managed by a workspace
--- edit.
---
--- @since 3.16.0.
---@alias ChangeAnnotationIdentifier string

---@class TextEdit
--- The range of the text document to be manipulated. To insert
--- text into a document create a range where start === end.
---@field range lsp.Range
--- The string to be inserted. For delete operations use an
--- empty string.
---@field newText string

---@class ChangeAnnotation
--- A human-readable string describing the actual change. The string
--- is rendered prominent in the user interface.
---@field label string
--- A flag which indicates that user confirmation is needed
--- before applying the change.
---@field needsConfirmation? boolean
--- A human-readable string which is rendered less prominent in
--- the user interface.
---@field description? string

---@class TextDocumentIdentifier
--- The text document's URI.
---@field uri DocumentUri

---@class VersionedTextDocumentIdentifier: TextDocumentIdentifier
--- The version number of this document.
---
--- The version number of a document will increase after each change,
--- including undo/redo. The number doesn't need to be consecutive.
---@field version? integer

---@class TextDocumentEdit
--- The text document to change.
---@field textDocument VersionedTextDocumentIdentifier
--- The edits to be applied.
---
--- @since 3.16.0 - support for AnnotatedTextEdit. This is guarded by the
--- client capability `workspace.workspaceEdit.changeAnnotationSupport`
---@field edits (TextEdit | AnnotatedTextEdit)[]

--- A special text edit with an additional change annotation.
---
--- @since 3.16.0.
---@class AnnotatedTextEdit: TextEdit
--- The actual annotation identifier.
---@field annotationId ChangeAnnotationIdentifier

--- Create file operation
---@class CreateFile
--- A create.
---@field kind "create"
--- The resource to create.
---@field uri DocumentUri
--- Additional options
---@field options? {overwrite: boolean?, ignoreIfExists: boolean?}
--- An optional annotation identifier describing the operation.
---
--- @since 3.16.0
---@field annotationId? ChangeAnnotationIdentifier

--- Rename file operation
---@class RenameFile
--- A rename
---@field kind "rename"
--- The old (existing) location.
---@field oldUri DocumentUri
--- The new location.
---@field newUri DocumentUri
--- Additional options
---@field options? {overwrite: boolean?, ignoreIfExists: boolean?}
--- An optional annotation identifier describing the operation.
---
--- @since 3.16.0
---@field annotationId? ChangeAnnotationIdentifier

--- Delete file operation
---@class DeleteFile
--- A delete
---@field kind "delete"
--- The file to delete.
---@field uri DocumentUri
--- Delete options
---@field options? {recursive: boolean?, ignoreIfNotExists: boolean?}
--- An optional annotation identifier describing the operation.
---
--- @since 3.16.0
---@field annotationId? ChangeAnnotationIdentifier

---@class WorkspaceEdit
--- Holds changes to existing resources.
---@field changes? table<DocumentUri, TextEdit[]>
--- Depending on the client capability
--- `workspace.workspaceEdit.resourceOperations` document changes are either
--- an array of `TextDocumentEdit`s to express changes to n different text
--- documents where each text document edit addresses a specific version of
--- a text document. Or it can contain above `TextDocumentEdit`s mixed with
--- create, rename and delete file / folder operations.
---
--- Whether a client supports versioned document edits is expressed via
--- `workspace.workspaceEdit.documentChanges` client capability.
---
--- If a client neither supports `documentChanges` nor
--- `workspace.workspaceEdit.resourceOperations` then only plain `TextEdit`s
--- using the `changes` property are supported.
---@field documentChanges?
---|TextDocumentEdit[]
---|(TextDocumentEdit | CreateFile | RenameFile | DeleteFile)[]
--- A map of change annotations that can be referenced in
--- `AnnotatedTextEdit`s or create, rename and delete file / folder
--- operations.
---
--- Whether clients honor this property depends on the client capability
--- `workspace.changeAnnotationSupport`.
---
--- @since 3.16.0
---@field changeAnnotations? table<ChangeAnnotationIdentifier, ChangeAnnotation>

---@class Command
--- Title of the command, like `save`.
---@field title string
--- The identifier of the actual command handler.
---@field command string
--- Arguments that the command handler should be
--- invoked with.
---@field arguments? any[]

---@enum CodeActionKind
M.CodeActionKind = {
	--- Empty kind.
	Empty = "",
	--- Base kind for quickfix actions: 'quickfix'.
	QuickFix = "quickfix",
	--- Base kind for refactoring actions: 'refactor'.
	Refactor = "refactor",
	--- Base kind for refactoring extraction actions: 'refactor.extract'.
	---
	--- Example extract actions:
	---
	--- - Extract method
	--- - Extract function
	--- - Extract variable
	--- - Extract interface from class
	--- - ...
	RefactorExtract = "refactor.extract",
	--- Base kind for refactoring inline actions: 'refactor.inline'.
	---
	--- Example inline actions:
	---
	--- - Inline function
	--- - Inline variable
	--- - Inline constant
	--- - ...
	RefactorInline = "refactor.inline",
	--- Base kind for refactoring rewrite actions: 'refactor.rewrite'.
	---
	---  Example rewrite actions:
	---
	---  - Convert JavaScript function to class
	---  - Add or remove parameter
	---  - Encapsulate field
	---  - Make method static
	---  - Move method to base class
	---  - ...
	RefactorRewrite = "refactor.rewrite",
	--- Base kind for source actions: `source`.
	---
	--- Source code actions apply to the entire file.
	Source = "source",
	--- Base kind for an organize imports source action:
	---  `source.organizeImports`.
	SourceOrganizeImports = "source.organizeImports",
	--- Base kind for a 'fix all' source action: `source.fixAll`.
	---
	--- 'Fix all' actions automatically fix errors that have a clear fix that
	--- do not require user input. They should not suppress errors or perform
	--- unsafe fixes such as generating new types or classes.
	---
	--- @since 3.17.0
	SourceFixAll = "source.fixAll",
}

---@class disabled
---Human readable description of why the code action is currently
---disabled.
---
---This is displayed in the code actions UI.
---@field reason string

---@class CodeAction
--- A short, human-readable, title for this code action.
---@field title string
--- The kind of the code action. Used to filter code actions.
---@field kind? CodeActionKind
--- The diagnostics that this code action resolves.
---@field diagnostics? lsp.Diagnostic[]
--- Marks this as a preferred action. Preferred actions are used by the
--- `auto fix` command and can be targeted by keybindings.
---
--- A quick fix should be marked preferred if it properly addresses the
--- underlying error. A refactoring should be marked preferred if it is the
--- most reasonable choice of actions to take.
---
--- @since 3.15.0
---@field isPreferred? boolean
--- Marks that the code action cannot currently be applied.
---
--- Clients should follow the following guidelines regarding disabled code
--- actions:
---
--- - Disabled code actions are not shown in automatic lightbulbs code
---   action menus.
---
--- - Disabled actions are shown as faded out in the code action menu when
---   the user request a more specific type of code action, such as
---   refactorings.
---
--- - If the user has a keybinding that auto applies a code action and only
---   a disabled code actions are returned, the client should show the user
---   an error message with `reason` in the editor.
---
--- @since 3.16.0
---@field disabled? disabled
---The workspace edit this code action performs.
---@field edit? WorkspaceEdit;
--- A command this code action executes. If a code action
--- provides an edit and a command, first the edit is
--- executed and then the command.
---@field command? Command;
--- A data entry field that is preserved on a code action between
--- a `textDocument/codeAction` and a `codeAction/resolve` request.
---
--- @since 3.16.0
---@field data? any;
M.CodeAction = {}

----------------------PLAYGROUND
---@type CodeAction
local foo = { title = "foo" }

local _ = foo.edit.documentChanges[1].edits[1].newText

return M
