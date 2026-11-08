local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua

describe('NFA regexp engine', function()
  before_each(clear)

  local lines = {
    'KELVIN \u{212A} kelvin \u{17F}tra\u{DF}e STRASSE strasse Stra\u{DF}e \ttab\t ',
    'foo bar baz FOO BAR BAZ fOo bAr x1 X2 ax bx cx dx AX BX',
    '12px 3.5em 0x1F 0777 _ident Ident ident123 \u{C9}COLE \u{E9}cole \u{FC}ber \u{DC}BER',
    'if else IF ELSE ifelse elseif ix  trailing   ',
    '日本語 テスト 漢字abc αβγ ΑΒΓ ǅǆǄ ﬀ ﬃ İstanbul ıi',
    '\t   [x] {y} <z> "str" \'c\' /* comment */ // line',
  }

  local patterns = {
    [[\(foo\|bar\)]],
    [[\%(if\|else\)\>]],
    [[\<\(if\|else\)\>]],
    [[[a-c]x]],
    [[[A-C]X]],
    [[\d\+px]],
    [[\x\+]],
    [[\o\+]],
    [[\h\w*\d]],
    [[\s\+$]],
    [[\a\l\u]],
    [[\l\+]],
    [[\u\+]],
    [[[a-z]\+]],
    [[[A-Z]\+]],
    [=[[[:digit:][:blank:]]\+]=],
    [=[[[:xdigit:]_]\+]=],
    [=[[[:space:][:punct:]]\+]=],
    '\\(kelvin\\|stra\u{DF}e\\)',
    '\\(k\\|\u{212A}\\)elvin',
    '[\u{1C5}k]',
    '\\(\u{212A}el\\|\u{17F}tr\\)',
    '\\(\u{131}\\|i\\)stanbul',
    '\\(\u{FB00}\\|\u{FB03}\\)',
    '\\%(\u{E9}\\|\u{FC}\\)\\+',
    '[\u{E9}-\u{FC}]\\+',
    '[\u{2100}-\u{2200}]',
    '\\(日本\\|テスト\\)',
    '[αβ]γ',
    [[\(x\|y\)\zsz]],
    [[\(a\|\)b]],
    [[\%(a\|b\)\@<=c]],
    [[\%5c\(a\|b\)]],
    [[\(\[\|{\|<\)\a]],
    [[\("\|'\)\a\+\1]],
    [[\(\/\*\|\/\/\)]],
    [[\(s\|t\)\_s*\(r\|t\)]],
  }

  it('first byte skipping matches like the backtracking engine', function()
    local results = exec_lua(function(lines_, patterns_)
      local function matches(s, pat)
        local res = {}
        local start = 0
        while true do
          local m = vim.fn.matchstrpos(s, pat, start)
          if m[2] < 0 then
            break
          end
          res[#res + 1] = m[2] .. ':' .. m[3]
          start = m[3] > m[2] and m[3] or m[2] + 1
        end
        return table.concat(res, ' ')
      end
      local function searches(pat)
        local res = {}
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        local flags = 'cW'
        while true do
          local pos = vim.fn.searchpos(pat, flags)
          if pos[1] == 0 then
            break
          end
          res[#res + 1] = pos[1] .. ':' .. pos[2]
          flags = 'W'
        end
        return table.concat(res, ' ')
      end
      vim.api.nvim_buf_set_lines(0, 0, -1, true, lines_)
      local diffs = {}
      for _, pat in ipairs(patterns_) do
        for _, case in ipairs({ '\\c', '\\C' }) do
          for _, s in ipairs(lines_) do
            local bt = matches(s, '\\%#=1' .. case .. pat)
            local nfa = matches(s, '\\%#=2' .. case .. pat)
            if bt ~= nfa then
              diffs[#diffs + 1] = { pat = case .. pat, s = s, bt = bt, nfa = nfa }
            end
          end
          local bt = searches('\\%#=1' .. case .. pat)
          local nfa = searches('\\%#=2' .. case .. pat)
          if bt ~= nfa then
            diffs[#diffs + 1] = { pat = case .. pat, bt = bt, nfa = nfa }
          end
        end
      end
      return diffs
    end, lines, patterns)
    eq({}, results)
  end)
end)
