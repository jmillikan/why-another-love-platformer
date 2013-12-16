_ = require "underscore/underscore"
require "across_state_lines"
require "json.json"

function dispatch(k,t)
   local a = t[k] or {_.identity}
   return (a[1])(unpack(_.slice(a,2,#a-1))) 
end

local levels

function read_levels()
   levels = json.decode(io.read("*all"))
end

function write_and_exit()
   io.write(json.encode(levels))

   love.event.quit()
end

local pos_x = 0
local pos_y = 0

local step = 5

function base_draw()
   -- ui.current_state_name should probably be internal.
   show_text(ui.current_state_name .. " (" .. pos_x .. ", " .. pos_y .. ") x " .. step, 0)

   love.graphics.line(pos_x, pos_y - 5, pos_x, pos_y + 5)
   love.graphics.line(pos_x - 5, pos_y, pos_x + 5, pos_y)
end

function change_pos_x(offset)
   pos_x = pos_x + offset
end

function change_pos_y(offset)
   pos_y = pos_y + offset
end

function base_keypress(s, k)
   dispatch(k, {
	       h = {change_pos_x, -step},
	       j = {change_pos_y, step}, 
	       k = {change_pos_y, -step},
	       l = {change_pos_x, step},
	       r = {change_ui_state, ui, 'relocate'},
	       s = {change_ui_state, ui, 'change_step'},
	       z = {write_and_exit},
	       q = {love.event.quit},
	       })
end

-- TODO: Get relocate working inside other states by having something like push_ui_state/pop_ui_state?

local command_s

UI_STATES = {
   init = { 
      -- Nothing selected. Crosshairs.
      draw = base_draw,
      keypressed = base_keypress,
      to = {'relocate', 'change_step'}
   },
   relocate = {
      draw = base_draw,
      mousereleased = function(s, x, y, b)
	 if b == "l" then
	    pos_x = x
	    pos_y = y
	    change_ui_state(ui, 'init')
	 end
      end,
      to = {'init'}
   },
   change_step = {
      draw = base_draw,
      from_init = function() 
	 command_s = ''
      end,
      keypressed = function(s, k)
	 if k == 'return' then
	    if not pcall(function() step = tonumber(command_s) end) then
	       print("Bad command string for change_step: " .. command_s)
	    end
	    change_ui_state(ui, 'init')
	 elseif k == 'escape' then
	    change_ui_state(ui, 'init')
	 else
	    command_s = command_s .. k
	 end
      end,
      to = {'init'}
   },
}

function love.load()
   read_levels()

   ui = init_ui_graph(UI_STATES, 'init')
end
