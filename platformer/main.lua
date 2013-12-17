require 'game'

--[[
Globals: 
_level_state - The current level state - character position, platform positions, dead/finished
_game_state - "front", "running", "ending", "won"
_end_time - A countdown from "ending" to next state while showing level
_levels - Array of loaded level tables
--]]

function love.load()
   _levels = load_levels()

   _game_state = "front"
end

_debug = false
debug_info = _.identity

local update_skip = 20

-- TODO: Either normalize delta of game updates or (less likely) fix mechanics to correct for size of delta
function love.update(delta)
   if _game_state ~= "running" and _game_state ~= "ending" then return end

   if _debug then
      update_skip = update_skip - 1

      if update_skip <= 0 then
	 _level_state:advance(delta)      
	 update_skip = 20
      end
   else
      _level_state:advance(delta)      
   end

   if _level_state.dead then
      -- Dead, restart current level
      -- This can happen during "ending". Level still advances.
      _level_state = make_level_state(_levels[current_level])
   elseif _level_state.finished then
      if _game_state ~= "ending" then
	 _game_state = "ending"
	 _ending_time = 2
      end
   end

   -- game state update may end game
   if _game_state == "ending" then
      _ending_time = _ending_time - delta
      if _ending_time < 0 then
	 current_level = current_level + 1
	 if current_level > #_levels then
	    _game_state = "won"
	 else
	    _level_state = make_level_state(_levels[current_level])
	    _game_state = "running"
	 end
      end
   end
end

function love.keypressed(key, unicode)
   -- Note: After _level_state is modified, character will be old
   if key == "d" then
      _debug = not _debug
      
      debug_info = _debug and print or _.identity
   end

   if _game_state == "running" then
      if key == "r" then
	 _level_state = make_level_state(_levels[current_level])
	 _game_state = "running"
      else
	 _level_state:keypress(key)
      end
   end

   if _game_state == "front" or _game_state == "won" then
      if key == "n" then
	 current_level = 1
	 _level_state = make_level_state(_levels[current_level])
	 _game_state = "running"
      end
   end
end

function love.keyreleased(key, unicode)
   if _game_state == "running" then
      -- Note: After _level_state is modified, character will be old
      local character = _level_state.character
      
      if _game_state == "running" then
	 _level_state:keyrelease(key)
      end
   end
end

function love.draw()
   if _game_state == "running" or _game_state == "ending" then
      
      _level_state:draw()

      if _game_state == "ending" then
	 show_text("Moving on...", 200)
      end
   elseif _game_state == "won" then
      show_text("You won! Another game?", 0)
      show_text("Press n to start", 100)
   elseif _game_state == "front" then
      show_text("Why Another Love Platformer", 0)
      show_text("Press n to start", 100)
   end
end

