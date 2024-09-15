local utils = require("omnisharp_extended/utils")

local M = {}

M.telescope_list_or_jump = function(title, params, locations, lsp_client, opts)
  local telescope_exists, make_entry = pcall(require, "telescope.make_entry")
  if not telescope_exists then
    print("Telescope is required for this action.")
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  if #locations == 0 then
    vim.notify("No locations found")
  elseif #locations == 1 and opts.jump_type ~= "never" then
    local current_uri = params.fileName
    local target_uri = locations[1].uri or locations[1].targetUri
    if current_uri ~= string.gsub(target_uri, "file://", "") then
      if opts.jump_type == "tab" then
        vim.cmd("tabedit")
      elseif opts.jump_type == "split" then
        vim.cmd("new")
      elseif opts.jump_type == "vsplit" then
        vim.cmd("vnew")
      end
    end

    vim.lsp.util.jump_to_location(locations[1], lsp_client.offset_encoding, opts.reuse_win)
  else
    locations = vim.lsp.util.locations_to_items(locations, lsp_client.offset_encoding)
    pickers
      .new(opts, {
        prompt_title = title,
        finder = finders.new_table({
          results = locations,
          entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
        }),
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(opts),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
      })
      :find()
  end
end

local reference_locations = {}
local file_prefix_length = string.len("file://") + 1

local function get_directory_name(path)
  return path:match("([^/\\]+)$")
end

local function resolve_symlink(path)
  local real_path = vim.loop.fs_realpath(path)
  return real_path or path  -- Return the original path if `fs_realpath` fails
end

local function get_index(selected)
  local index = tonumber(string.match(selected, "%[(%d+)%]"))
  -- local line_number = tonumber(string.match(selected, ":(%d+)$"));
  return index
end

local function reference_sink(selected)
  vim.print(selected)
  if selected == nill then
    return
  end
  local idx = get_index(selected)
  vim.print(string.format("%d, %s", idx, selected))

  if reference_locations == nil then
    vim.notify("No valid reference")
    return
  end
  local location = reference_locations[idx]
  local fp = string.gsub(string.gsub(location.uri, "^file://", ""), "\\", "/")
  vim.cmd(string.format("edit %s", fp))

  local lnum = tonumber(location.range.start.line) + 1
  local cnum = tonumber(location.range.start.character)
  local current_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_cursor(current_win, {lnum, cnum})
end

M.vim_clap_list_or_jump = function (locations, lsp_client)
  reference_locations = locations

  local cwd = resolve_symlink(vim.fn.getcwd())
  local clap_display_data = {}
  for i, item in ipairs(locations) do
    vim.print(item);
    local adjusted_uri = string.gsub(string.sub(item.uri, file_prefix_length), cwd, get_directory_name(cwd))
    clap_display_data[i] = string.format("[%d]: %s:%d", i, adjusted_uri, item.range.start.line)
  end

  local provider = {
    source = clap_display_data,
    sink = reference_sink
  }
  vim.fn["clap#run"](provider)
  vim.api.nvim_input("<ESC>")
end

M.qflist_list = function(locations, lsp_client)
  if #locations > 0 then
    utils.set_qflist_locations(locations, lsp_client.offset_encoding)
    vim.api.nvim_command("copen")
    return true
  else
    vim.notify("No locations found")
  end
end

M.qflist_list_or_jump = function(locations, lsp_client)
  if #locations > 1 then
    vim.print("First clause")
    vim.print(vim.inspect(locations))
    utils.set_qflist_locations(locations, lsp_client.offset_encoding)
    vim.api.nvim_command("copen")
  elseif #locations == 1 then
    vim.print("2nd clause")
    vim.lsp.util.jump_to_location(locations[1], lsp_client.offset_encoding)
  else
    vim.notify("No locations found")
  end
end

return M
