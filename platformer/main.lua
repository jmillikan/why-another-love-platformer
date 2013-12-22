_ = require "underscore.underscore"
require 'across_state_lines'

require 'game'

--[[
Globals: 
_level_state - The current level state - character position, platform positions, dead/finished
_end_time - A countdown from "ending" to next state while showing level
_levels - Array of loaded level objects

debug_info - print debug info if debugging, else nothing.
--]]

local debug = false
debug_info = _.identity

local update_skip = 20
local current_level
local ui

-- TODO: Massage level state into a ui state 
-- (by loading levels into one instead of making a new one)
UI_STATES = {
   front = {
      to = { "running" },
      draw = function() 
	 show_text("Why Another Love Platformer", 200)
	 show_text("Press n to start", 300)
      end,
      keypressed = keymap_method { n = state_thunk("running") } 
   },
   running = {
      from_front = function() 
	 current_level = 1
	 _level_state = make_level_state(_levels[current_level])
      end,
      from_won = function() 
	 current_level = 1
	 _level_state = make_level_state(_levels[current_level])
      end,
      draw = function()
	 _level_state:draw()
      end,
      keypressed = function(s, key, u)
	 if key == "r" then
	    _level_state = make_level_state(_levels[current_level])
	 else
	    _level_state:keypress(key)
	 end
      end,
      keyreleased = function(s, key, u)
	 _level_state:keyrelease(key)
      end,
      to = { "ending" },
      update = function(s, delta)
	 if debug then
	    update_skip = update_skip - 1
	    
	    if update_skip <= 0 then
	       _level_state:advance(delta)      
	       update_skip = 20
	    end
	 else
	    _level_state:advance(delta)      
	 end

	 if _level_state.dead then
	    _level_state = make_level_state(_levels[current_level])
	 elseif _level_state.finished then
	    change_ui_state(ui, "ending")
	 end
      end
   },
   ending = {
      from_running = function()
	 _ending_time = 2
      end,
      draw = function()
	 _level_state:draw()

	 show_text("Moving on...", 400)
      end,
      update = function(s, delta)
	 _level_state:advance(delta)      
	 
	 if _level_state.dead then
	    -- Dead, restart current level
	    -- This can happen during "ending". Level still advances.
	    _level_state = make_level_state(_levels[current_level])
	 end
	 
	 _ending_time = _ending_time - delta
	 if _ending_time < 0 then
	    current_level = current_level + 1
	    if current_level > #_levels then
	       change_ui_state(ui, "won")
	    else
	       _level_state = make_level_state(_levels[current_level])
	       change_ui_state(ui, "running")
	    end
	 end
      end,
      to = { "won", "running" },
   },
   won = {
      draw = function()
	 show_text("Yay, you won.", 200)
	 show_text("Press n to restart", 300)
      end,
      keypressed = keymap_method { n = state_thunk("running") },
      to = { "running" }
   },
}

function love.load()
   _levels = load_levels()

   ui = init_ui_graph(UI_STATES, 'front')
end
