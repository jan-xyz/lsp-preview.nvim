local describe = require("plenary.busted").describe
local it = require("plenary.busted").it
local before_each = require("plenary.busted").before_each
local assert = require("luassert.assert")

local config = require("lsp-preview.config")

describe("the config", function()
	before_each(function()
		config.__reset()
	end)

	it("uses the default values", function()
		config.setup({})
		assert.equals(false, config.preview)
	end)

	it("sets the user config", function()
		config.setup({ preview = true })
		assert.equals(true, config.preview)
	end)
end)
