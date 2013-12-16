_ = require "underscore/underscore"
require "across_state_lines"
require "json.json"

function dispatch(k,t)
   local a = t[k] or {_.identity}
   return (a[1])(unpack(_.slice(a,2,#a-1))) 
end

local pos_x = 0
local pos_y = 0

local step = 5

local current_block_i = 0

-- JSON object representing level
local level

function read_level()
   level = json.decode(io.read("*all"))
   -- You'll need an existing level for boilerplate...
   level.more_magic = "More magic"
end

function write_and_exit()
   io.write(json.encode(level))

   love.event.quit()
end

-- TODO: Figure out how to share more of this between level editor and platformer
function draw_level()
   love.graphics.push()
   
   draw_rect(level.playfield, {255, 255, 255, 50})
   
   for i = 1, #level.platforms do 
      if i == current_block_i then
	 draw_rect(level.platforms[i], {100, 255, 100, 150})
      else
	 draw_rect(level.platforms[i], {255, 255, 255, 100})
      end
   end
   
   draw_rect(level.end_door, {255, 0, 0, 200})
   draw_rect(level.character, {0, 0, 255, 200})
   
   love.graphics.pop()
end   

function draw_rect(r, color)
   love.graphics.push()

   love.graphics.translate(r.x + r.width / 2, r.y + r.height / 2)

   if r.angle then
      love.graphics.rotate(r.angle)
   end

   -- See "Graphics"
   love.graphics.setColor(unpack(color))

   love.graphics.rectangle("fill", - r.width / 2,  - r.height / 2, r.width, r.height)

   love.graphics.pop()
end

function base_draw()
   draw_level()

   -- ui.current_state_name should probably be internal.
   show_text(ui.current_state_name .. " (" .. pos_x .. ", " .. pos_y .. ") x " .. step .. " block " .. current_block_i, 0)

   love.graphics.line(pos_x, pos_y - 5, pos_x, pos_y + 5)
   love.graphics.line(pos_x - 5, pos_y, pos_x + 5, pos_y)
end

function change_pos_x(offset)
   pos_x = pos_x + offset
end

function change_pos_y(offset)
   pos_y = pos_y + offset
end

function next_block()
   if #level.platforms > current_block_i then
      current_block_i = current_block_i + 1
   end
end

function previous_block()
   if current_block_i > 1 then
      current_block_i = current_block_i - 1
   end
end

function move_block()
   if current_block_i > 0 and current_block_i <= #level.platforms then
      level.platforms[current_block_i].x = pos_x
      level.platforms[current_block_i].y = pos_y
   end
end

function rotate_block(dir)
   if current_block_i > 0 and current_block_i <= #level.platforms then
      level.platforms[current_block_i].angle = (level.platforms[current_block_i].angle or 0) + (step * 2 * math.pi / 360) * dir
   end
end

function insert_block()
   table.insert(level.platforms,
		{ x = pos_x, y = pos_y, width = 200, height = 20 })
   current_block_i = #level.platforms
end

function b() 
   return level.platforms[current_block_i]
end

function change_width(dir)
   b().width = b().width + step * dir
end

function change_height(dir)
   b().height = b().height + step * dir
end

function base_keypress(s, k)
   dispatch(k, {
	       h = {change_pos_x, -step},
	       j = {change_pos_y, step}, 
	       k = {change_pos_y, -step},
	       l = {change_pos_x, step},
	       left = {change_pos_x, -step},
	       down = {change_pos_y, step}, 
	       up = {change_pos_y, -step},
	       right = {change_pos_x, step},
	       r = {change_ui_state, ui, 'relocate'},
	       t = {change_ui_state, ui, 'change_step'},
	       z = {write_and_exit},
	       escape = {love.event.quit},
	       n = {next_block},
	       p = {previous_block},
	       m = {move_block},
	       q = {rotate_block, -1},
	       e = {rotate_block, 1},
	       a = {change_width, -1},
	       d = {change_width, 1},
	       w = {change_height, -1},
	       s = {change_height, 1},
	       i = {insert_block},
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
   read_level()

   ui = init_ui_graph(UI_STATES, 'init')
end
