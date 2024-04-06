-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local action_state = require("telescope.actions.state")

---The diff hunk
---@class Previewable
---@field title string
---@field filename fun(self): string
---Return the index in the workspace_edit, sub_index is only provided for
---Edits.
---@field index number | {primary: number, secondary: number}
---@field preview fun(self, bufnr: integer, winid: integer, opts: table): string

---The Entry passed around in Telescope
---@class Entry
---@field value Previewable
---@field display fun(entry: Entry)
---@field ordinal string


local M = {}

---@param values Previewable[]
local make_make_display = function(values)
	local entry_display = require("telescope.pickers.entry_display")
	local strings = require("plenary.strings")

	local title_width = 0
	for _, value in ipairs(values) do
		title_width = math.max(title_width, strings.strdisplaywidth(value.title))
	end

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = title_width },
		},
	})
	return function(entry)
		return displayer({
			{ entry.value.title },
		})
	end
end

---@param prompt_bufnr integer
---@return Entry[]
local get_selected_diffs = function(prompt_bufnr)
	---@type Entry[]
	local selected = {}
	local current_picker = action_state.get_current_picker(prompt_bufnr)
	---@type Previewable[]
	local selections = current_picker:get_multi_selection()
	if vim.tbl_isempty(selections) then
		vim.notify("no change selected")
	else
		for _, selection in ipairs(selections) do
			table.insert(selected, selection)
		end
	end
	return selected
end

---@param changes Previewable[]
---@param apply_selection fun(selected_indices: integer[])
function M.apply_action(opts, changes, apply_selection)
	local actions = require("telescope.actions")
	local pickers = require("telescope.pickers")
	local previewers = require("telescope.previewers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local utils = require("telescope.utils")
	local putils = require("telescope.previewers.utils")

	-- validate the table to have everything we need
	for _, value in ipairs(changes) do
		if type(value) ~= "table" then
			error("'make_value' must return a table")
		end
		if type(value.title) ~= "string" then
			error("'make_value' must return a table containing a field 'title'")
		end
	end

	local make_display = make_make_display(changes)

	local previewer = previewers.new_buffer_previewer({
		setup = function(self)
			-- pre-select all changes on picker creation
			local prompt_bufnr = vim.api.nvim_get_current_buf()
			actions.select_all(prompt_bufnr)
			return {}
		end,
		---@param entry Entry
		define_preview = function(self, entry, status)
			local filetype = entry.value:preview(self.state.bufnr, self.state.winid, opts)
			putils.highlighter(self.state.bufnr, filetype, {})
		end,
		---@param entry Entry
		---@return string
		get_buffer_by_name = function(self, entry)
			-- create a single buffer per file.
			return entry.value:filename()
		end,
	})

	local finder = finders.new_table({
		results = changes,
		entry_maker = function(value)
			return {
				display = make_display,
				ordinal = value.title,
				value = value,
			}
		end,
	})

	pickers.new(opts, {
		prompt_title = "Edits to apply",
		previewer = previewer,
		finder = finder,
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			map("i", "<c-a>", actions.toggle_all)

			actions.select_default:replace(function()
				local selected_entries = get_selected_diffs(prompt_bufnr)

				actions.close(prompt_bufnr)

				apply_selection(selected_entries)
			end)

			return true
		end,
	}):find()
end

return M
