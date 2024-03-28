local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local after_each = require("plenary.busted").after_each
local before_each = require("plenary.busted").before_each
local assert = require("luassert.assert")

local buffer_edits = require("lsp-preview.buffer_edits")

describe("the buffer editor", function()
	local temp_buf

	before_each(function()
		temp_buf = vim.api.nvim_create_buf(false, true)
	end)

	after_each(function()
		vim.api.nvim_buf_delete(temp_buf, { force = true })
	end)

	it("caluclates the diff correctly", function()
		vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, { "bar" })

		---@type TextEdit[]
		local input = {
			{
				range = {
					start = { line = 0, character = 0 },
					["end"] = { line = 0, character = 3 },
				},
				newText = "foo",
			},
		}

		local old, new = buffer_edits.edit_buffer_text(input, temp_buf, "utf-16")

		assert.equal("bar\n", old)
		assert.equal("foo\n", new)
	end)
end)
