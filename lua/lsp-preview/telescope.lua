-- This module is mostly taken from github.com/aznhe21/actions-preview.nvim
-- The work done by the original author safed me a lot of time, and many thanks to them
-- for their work <3

local action_state = require("telescope.actions.state")

---@class Previewable
---@field title fun(self): string
---@field preview fun(self, opts: table): {text: string, syntax: string}

---@class Value
---@field title string
---@field index string
---@field type string
---@field entry Previewable

local M = {}

---@param entry Previewable
local default_make_value = function(entry)
	return {
		title = entry:title(),
	}
end

---@param values Value[]
local default_make_make_display = function(values)
	local entry_display = require("telescope.pickers.entry_display")
	local strings = require("plenary.strings")

	local index_width = 0
	local title_width = 0
	for _, value in ipairs(values) do
		index_width = math.max(index_width, strings.strdisplaywidth(value.index))
		title_width = math.max(title_width, strings.strdisplaywidth(value.title))
	end

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{ width = index_width + 1 },
			{ width = title_width },
		},
	})
	return function(entry)
		return displayer({
			{ entry.value.index .. ":", "TelescopePromptPrefix" },
			{ entry.value.title },
		})
	end
end

---@param job_id string
---@return boolean
local job_is_running = function(job_id)
	return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

---@param prompt_bufnr integer
---@return integer[]
local get_selected_diffs = function(prompt_bufnr)
	local selected = {}
	local current_picker = action_state.get_current_picker(prompt_bufnr)
	---@type Value[]
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

---@param documentChanges Previewable[]
---@param changes Previewable[]
---@param apply_selection fun(selected_indices: integer[])
function M.apply_action(opts, documentChanges, changes, apply_selection)
	local actions = require("telescope.actions")
	local pickers = require("telescope.pickers")
	local Previewer = require("telescope.previewers.previewer")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local utils = require("telescope.utils")
	local putils = require("telescope.previewers.utils")

	local make_value = default_make_value
	---@type Value[]
	local values = {}
	for index, entry in ipairs(documentChanges) do
		local value = make_value(entry)
		if type(value) ~= "table" then
			error("'make_value' must return a table")
		end
		if value.title == nil then
			error("'make_value' must return a table containing a field 'title'")
		end

		value.index = index
		value.entry = entry
		value.type = "documentChanges"

		table.insert(values, value)
	end
	for index, entry in ipairs(changes) do
		local value = make_value(entry)
		if type(value) ~= "table" then
			error("'make_value' must return a table")
		end
		if value.title == nil then
			error("'make_value' must return a table containing a field 'title'")
		end

		value.index = index
		value.entry = entry
		value.type = "changes"

		table.insert(values, value)
	end

	local make_display = default_make_make_display(values)

	local buffers = {}
	local term_ids = {}

	local previewer = Previewer:new({
		title = "Code Action Preview",
		setup = function(_self)
			-- pre-select all changes on picker creation
			local prompt_bufnr = vim.api.nvim_get_current_buf()
			actions.select_all(prompt_bufnr)
			return {}
		end,
		teardown = function(self)
			if not self.state then
				return
			end

			self.state.winid = nil
			self.state.bufnr = nil

			for _, bufnr in ipairs(buffers) do
				local term_id = term_ids[bufnr]
				if term_id and job_is_running(term_id) then
					vim.fn.jobstop(term_id)
				end
				utils.buf_delete(bufnr)
			end

			buffers = {}
			term_ids = {}
		end,
		---@param entry {value: Value}
		preview_fn = function(self, entry, status)
			local preview_winid = status.layout and status.layout.preview and status.layout.preview.winid or
					status.preview_win

			local do_preview = false
			local bufnr = buffers[entry.value.index]
			if not bufnr then
				bufnr = vim.api.nvim_create_buf(false, true)
				buffers[entry.value.index] = bufnr
				do_preview = true

				vim.api.nvim_win_set_option(preview_winid, "winhl", "Normal:TelescopePreviewNormal")
				vim.api.nvim_win_set_option(preview_winid, "signcolumn", "no")
				vim.api.nvim_win_set_option(preview_winid, "foldlevel", 100)
				vim.api.nvim_win_set_option(preview_winid, "wrap", false)
				vim.api.nvim_win_set_option(preview_winid, "scrollbind", false)
			end

			utils.win_set_buf_noautocmd(preview_winid, bufnr)
			self.state.winid = preview_winid
			self.state.bufnr = bufnr

			if do_preview then
				local preview = entry.value.entry:preview(opts)
				preview = preview or { syntax = "", text = "preview not available" }

				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(preview.text, "\n", { plain = true }))
				putils.highlighter(bufnr, preview.syntax, opts)
			end
		end,
		scroll_fn = function(self, direction)
			if not self.state then
				return
			end

			local count = math.abs(direction)
			local term_id = term_ids[self.state.bufnr]
			if term_id and job_is_running(term_id) then
				local input = direction > 0 and "d" or "u"

				local termcode = vim.api.nvim_replace_termcodes(count .. input, true, false, true)
				vim.fn.chansend(term_id, termcode)
			else
				local input = direction > 0 and [[]] or [[]]

				vim.api.nvim_win_call(self.state.winid, function()
					vim.cmd([[normal! ]] .. count .. input)
				end)
			end
		end,
	})

	local finder = finders.new_table({
		results = values,
		entry_maker = function(value)
			return {
				display = make_display,
				ordinal = value.index .. value.title,
				value = value,
			}
		end,
	})

	pickers.new(opts, {
		prompt_title = "Code Actions",
		previewer = previewer,
		finder = finder,
		sorter = conf.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			map("i", "<c-a>", actions.toggle_all)

			actions.select_default:replace(function()
				local selections = get_selected_diffs(prompt_bufnr)

				actions.close(prompt_bufnr)

				apply_selection(selections)
			end)

			return true
		end,
	}):find()
end

return M
