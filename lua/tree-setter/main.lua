-- =================
-- Requirements
-- =================
local queries = require("vim.treesitter.query")
-- all functions, which can modify the buffer, like adding the semicolons and
-- commas
local ts_utils = require("nvim-treesitter.ts_utils")
local helpers = require("tree-setter.helpers")

-- =====================
-- Global variables
-- =====================
-- this variable is also known as `local M = {}` which includes the stuff of the
-- module
local TreeSetter = {}

-- includes the queries of the current filetype
local query

-- this variable stores the last line num where the cursor was.
-- It's mainly used as a control variable since we are mainly adding the
-- semicolons, commas and double points when the user presses the enter key,
-- which will change the line number of the cursor
local last_line_num = 0

-- ==============
-- Functions
-- ==============
function TreeSetter.add_character()
    -- get the current node from the cursor
    local curr_node = ts_utils.get_node_at_cursor(0)
    if not curr_node then
        return
    end

    local parent_node = curr_node:parent()
    if not parent_node then
        return
    end

    -- Reduce the searching-place on the size of the parent node
    local start_row, _, end_row, _ = parent_node:range()
    -- since the end row is end-*exclusive*, we have to increase the end row by
    -- one
    end_row = end_row + 1

    -- now look if some queries fit with the current filetype
    for _, match, _ in query:iter_matches(parent_node, 0, start_row, end_row) do
        for id, node in pairs(match) do

            -- get the "coordinations" of our current line, where we have to
            -- lookup if we should add a semicolon or not.
            local char_start_row, _, char_end_row, _ = node:range()
            char_end_row = char_end_row + 1

            -- get the type of character which we should add
            -- So for example if we have "@semicolon" in our query, than
            -- "character_type" will be "semicolon", so we know that there
            -- should be a semicolon at the end of the line
            local character_type = query.captures[id]

            -- so look first, if we reached an "exception" which have the
            -- "@skip" predicate. 
            if character_type == "skip" then
                return
            end

            -- get the last character to know if there's already the needed
            -- character or not
            local line = vim.api.nvim_buf_get_lines(0, char_start_row,
                                                    char_end_row, false)[1]
            local wanted_character = line:sub(-1)

            -- since we're changing the previous line (after hitting enter) vim
            -- will move the indentation of the current line as well. This
            -- variable stores the indent of the previous line which will be
            -- added after adding the given line with the semicolon/comma/double
            -- point.
            local indent_fix = (' '):rep(vim.fn.indent(char_start_row + 1))

            if (character_type == "semicolon") and (wanted_character ~= ';') then
                vim.api.nvim_buf_set_lines(0, char_start_row, char_end_row,
                                           true, {line .. ';', indent_fix})

            elseif (character_type == "comma") and (wanted_character ~= ',') then
                vim.api.nvim_buf_set_lines(0, char_start_row, char_end_row,
                                           false, {line .. ',', indent_fix})

            elseif (character_type == "double_points")
                and (wanted_character ~= ':') then
                -- the indentation has an exception here. Suppose you write
                -- something like this ("|" represents the cursor):
                --  
                --      case 5:|
                --
                -- If you hit enter now, than your cursor would land like this:
                --
                --      case 5:
                --          |
                -- 
                -- so we have to add the indent given by the `shiftwidth` option
                -- as well!
                indent_fix = indent_fix .. (' '):rep(vim.o.shiftwidth)
                vim.api.nvim_buf_set_lines(0, char_start_row, char_end_row,
                                           false, {line .. ':', indent_fix})
            end
        end
    end
end

function TreeSetter.main()
    local line_num = vim.api.nvim_win_get_cursor(0)[1]

    -- look if the cursor has changed his line position, if yes, than this
    -- means (normally) that the user pressed the <CR> key => Look which
    -- character we have to add
    if last_line_num ~= line_num then
        TreeSetter.add_character()
    end

    -- refresh the old cursor position
    last_line_num = line_num
end

function TreeSetter.attach(bufnr, lang)
    query = queries.get_query(lang, 'tsetter')

    -- if there's no query for the current filetype -> Don't do anything
    if not query then
        return
    end

    vim.cmd([[
        augroup TreeSetter
        autocmd!
        autocmd TextChangedI * lua require("tree-setter.main").main()
        augroup END
    ]])
end

function TreeSetter.detach(bufnr) end

return TreeSetter
