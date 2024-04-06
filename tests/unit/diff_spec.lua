local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local before_each = require("plenary.busted").before_each
local assert = require("luassert.assert")

local diff = require("lsp-preview.diff")

describe("make_apply_func", function()
	it("filters the workspace_edit documentChanges correctly", function()
		-- Given
		---@type WorkspaceEdit
		local input_workspace_edit = {
			documentChanges = {
				{ kind = "create", uri = "create-some-uri" },
				{ kind = "rename", uri = "rename-some-uri" },
				{ kind = "delete", uri = "delete-some-uri" },
				{
					textDocument = { uri = "edit-some-uri" },
					edits = {
						{ range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 10 } }, newText = "foo" },
						{ range = { start = { line = 2, character = 3 }, ["end"] = { line = 2, character = 11 } }, newText = "bar" },
						{ range = { start = { line = 3, character = 4 }, ["end"] = { line = 3, character = 12 } }, newText = "baz" },
					},
				},
			},
		}
		local input_selected_entries = {
			{ value = { index = 1 } },
			{ value = { index = 3 } },
			{ value = { index = { primary = 4, secondary = 1 } } },
			{ value = { index = { primary = 4, secondary = 3 } } },
		}

		-- When
		---@type WorkspaceEdit
		local got_workspace_edit = {}
		local got_offset_encoding = ""

		local capture_fn = function(captured_workspace_edit, captured_offset_encoding)
			got_workspace_edit = captured_workspace_edit
			got_offset_encoding = captured_offset_encoding
		end
		local fn = diff.make_apply_func(input_workspace_edit, "utf16", capture_fn)
		fn(input_selected_entries)

		-- Then
		local want = {
			documentChanges = {
				{ kind = "create", uri = "create-some-uri" },
				{ kind = "delete", uri = "delete-some-uri" },
				{
					textDocument = { uri = "edit-some-uri" },
					edits = {
						{ range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 10 } }, newText = "foo" },
						{ range = { start = { line = 3, character = 4 }, ["end"] = { line = 3, character = 12 } }, newText = "baz" },
					},
				},
			},
		}
		assert.same(want, got_workspace_edit)
		assert.equals("utf16", got_offset_encoding)
	end)

	it("filters the workspace_edit changes correctly", function()
		-- Given
		---@type WorkspaceEdit
		local input_workspace_edit = {
			changes = {
				["edit-some-uri"] = {
					{ range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 10 } }, newText = "foo" },
					{ range = { start = { line = 2, character = 3 }, ["end"] = { line = 2, character = 11 } }, newText = "bar" },
					{ range = { start = { line = 3, character = 4 }, ["end"] = { line = 3, character = 12 } }, newText = "baz" },
				},
			},
		}
		local input_selected_entries = {
			{ value = { index = { primary = 1, secondary = 1 }, uri = "edit-some-uri" } },
			{ value = { index = { primary = 1, secondary = 3 }, uri = "edit-some-uri" } },
		}

		-- When
		---@type WorkspaceEdit
		local got_workspace_edit = {}
		local got_offset_encoding = ""

		local capture_fn = function(captured_workspace_edit, captured_offset_encoding)
			got_workspace_edit = captured_workspace_edit
			got_offset_encoding = captured_offset_encoding
		end
		local fn = diff.make_apply_func(input_workspace_edit, "utf16", capture_fn)
		fn(input_selected_entries)

		-- Then
		local want = {
			changes = {
				["edit-some-uri"] = {
					{ range = { start = { line = 1, character = 2 }, ["end"] = { line = 1, character = 10 } }, newText = "foo" },
					{ range = { start = { line = 3, character = 4 }, ["end"] = { line = 3, character = 12 } }, newText = "baz" },
				},
			},
		}
		assert.same(want, got_workspace_edit)
		assert.equals("utf16", got_offset_encoding)
	end)
end)
