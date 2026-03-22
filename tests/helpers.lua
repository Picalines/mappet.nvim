local H = {}

local name_id = 0

function H.unique_name(prefix)
  name_id = name_id + 1
  return string.format('%s-%d', prefix, name_id)
end

function H.get_global_map(mode, lhs)
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs == lhs then
      return map
    end
  end

  return nil
end

function H.get_buffer_map(bufnr, mode, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if map.lhs == lhs then
      return map
    end
  end

  return nil
end

function H.count_global_maps(mode, lhs)
  local count = 0

  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs == lhs then
      count = count + 1
    end
  end

  return count
end

function H.truthy(value)
  return value and true or false
end

return H
