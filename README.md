# LSP-Preview.nvim

A plugin that allows previewing of all changes done to a workspace before
applying.

## Note

This plugin affects all workspace edits coming from the language server.
Not all are currently supported, if you run into problems with other methods,
please let me know.

## Acknoweldgement

The implementation of the diffs and the telescope picker
are heavily inspired by [azsnhe21/actions-preview.nvim](github.com/aznhe21/actions-preview.nvim).
Without the prework done there, I would not have been able to build this.

## Installation

lazy.nvim:

```lua
{
  'jan-xyz/lsp-preview.nvim',
  version = "*",
  opts = {},
}
```

## Configuration

If you're fine with the defaults, you're good to go after installation. If you
want to tweak, call this function:

```lua
require("dressing").setup({
 --Automatically apply code-actions if there is only 1 available.
 apply = true,
 --Configuration provided to vim.diff (see `:h vim.diff()`)
 diff = {
  ctxlen = 5,
 },
})
```

## TODO

* [x] implement selection
* [x] auto-select all changes
* [x] implement rename
* [x] make it work with normal workspace edits
* [x] don't rely on picker order selection
* [x] allow disabling the preview
* [x] provide configuration options
* [ ] break-down by edit and not by file, one buffer for all changes in a file,
  view-port shifts on selection, buffer contents updates based on selected
  changes
* [ ] Allow sorting list by token type that changes (e.g. var, class, comment)

## Inspired by

* github.com/aznhe21/actions-preview.nvim
* github.com/stevearc/dressing.nvim
