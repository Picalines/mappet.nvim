vim.cmd([[let &rtp.=','.getcwd()]])
vim.cmd('set rtp+=deps/mini.test')

if #vim.api.nvim_list_uis() == 0 then
  local minitest = require 'mini.test'

  minitest.setup()
  minitest.run {
    collect = {
      find_files = function()
        return vim.fn.globpath('tests', '**/test_*.lua', true, true)
      end,
    },
  }
end
