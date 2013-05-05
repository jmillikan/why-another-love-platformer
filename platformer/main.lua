HC = require 'hardoncollider'
_ = require 'underscore.underscore'
require 'json.json'

--[[
Globals: 
_level_state - The current level state - character position, platform positions, dead/finished
_game_state - "front", "running", "ending", "won"
_end_time - A countdown from "ending" to next state while showing level
_levels - Array of loaded level tables
--]]

--[[
game rect (convention): A possibly angled game rectangle that can be drawn, can be moved, and causes collision handling
Functions: load_game_rect, move_game_rect, place_game_rect, draw_game_rect

game rect graphics: One of { color: { r,g,b,a } }, { image: love.graphics image }, {}

level state:
   make_level_state, advance_level_state, draw_level_state
   .dead, .finished
   .character.running_left... (TODO: abstract these into keypressed_level_state etc.)
--]]

function love.load()
   local contents, length = love.filesystem.read("levels.json")

   _levels = json.decode(contents)

   _game_state = "front"
end

-- TODO: Either normalize delta of game updates or (less likely) fix mechanics to correct for size of delta
function love.update(delta)
   if _game_state ~= "running" and _game_state ~= "ending" then return end

   advance_level_state(_level_state, delta)

   if _level_state.dead then
      -- Dead, restart current level
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

   if _game_state == "running" then
      local character = _level_state.character

      if key == "r" then
	 _level_state = make_level_state(_levels[current_level])
	 _game_state = "running"
      else
	 keypress_level_state(_level_state, key)
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
	 keyrelease_level_state(_level_state, key)
      end
   end
end

function love.draw()
   if _game_state == "running" or _game_state == "ending" then
      
      draw_level_state(_level_state)

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

-- JSON rect: A table with .x/.y/.width/.height[/.angle]
-- Produce a level state to initial state of JSON-loaded level
function make_level_state(level)
   local ls = {}
   local collider = HC(100, 
		       function(...) start_collision_level_state(ls, ...) end,
		       function(...) stop_collision_level_state(ls, ...) end)

   local playfield = load_game_rect(level.playfield, collider, { color = {50,50,200,255} })
   
   return _.extend(ls, 
		   { 
		      dead = false,
		      collider = collider,
		      character = load_game_rect(level.character, collider, { image = love.graphics.newImage('char.png') }),
		      end_door = load_game_rect(level.end_door, collider, { color = {255,255,255,255} }),
		      platforms = _.map(level.platforms,
					function(p)
					   return load_game_rect(p, collider, { color = {40,230,100,100} })
					end),
		      playfield = playfield,
		      screenx = love.graphics.getWidth() / 2 - playfield.width / 2,
		      screeny = love.graphics.getHeight() / 2 - playfield.height / 2
		   })
end

-- key: A love2d KeyConstant
function keypress_level_state(ls, key)
   if key == "right" then
      ls.character.running_right = true
   elseif key == "left" then
      ls.character.running_left = true
   elseif key == "up" then
      ls.character.jumping = true
   end
end

-- key: A love2d KeyConstant
function keyrelease_level_state(ls, key)
   if key == "right" then
      ls.character.running_right = false
   elseif key == "left" then
      ls.character.running_left = false
   elseif key == "up" then
      ls.character.jumping = false
   end
end

-- Handle collisions wrt a level state
-- TODO: get _game_state and _level_state out, handle those by a new _game_state or something

-- Take the x/y "shortest" correction given by HC, 
-- and convert it into a pure vertical correction
-- This doesn't give the correct sign.
function verticalize_correction(mtv_x,mtv_y)
   if mtv_x ~= 0 then
      -- print("- x movement (" .. mtv_x .. "): angle collision")
      return mtv_y - mtv_x / math.atan2(mtv_y, mtv_x)
   else
      -- print("- no x movement: non-angle")
      return mtv_y
   end
end

-- Return a with same sign as b
function match_sign(x, sign)
   return sign >= 0 and math.abs(x) or -math.abs(x)
end

function start_collision_level_state(ls, dt, shape_a, shape_b, mtv_x, mtv_y)
   local character = ls.character
   local end_door = ls.end_door
   local playfield = ls.playfield

   if shape_b == character.collider then
      start_collision_level_state(ls, dt, shape_b, shape_a, -mtv_x, -mtv_y)
   elseif shape_a == character.collider then

      if shape_b == end_door.collider then
	 -- May happen multiple times
	 ls.finished = true
	 character.running_left = false
	 character.running_right = false
	 character.jumping = false
      elseif shape_b == playfield.collider then

      else
	 local dy = match_sign(verticalize_correction(mtv_x, mtv_y), mtv_y)
	 
	 move_game_rect(character, 0, dy)
	 
	 -- If attempting to jump on a downward collision (INCORRECT!) give jump velocity.
	 -- TODO: foot collider
	 if character.jumping and mtv_y < 0 then
	    character.yv = -300
	 else
	    character.yv = 0
	 end
      end
   end
end

function stop_collision_level_state(ls, dt, shape_a, shape_b)
   local character = ls.character
   local playfield = ls.playfield

   if shape_b == character.collider then
      stop_collision_level_state(ls, dt, shape_b, shape_a)
   elseif shape_a == character.collider then
      
      -- "Die" if out of the playfield, handles falling...
      if shape_b == playfield.collider then 
	 ls.dead = true
      end
   end
end

function advance_level_state(ls, delta)
   local character = ls.character
   local platforms = ls.platforms
   
   -- Use running bits to modify x velocity
   if character.running_left then
      character.xv = character.xv - 20
   elseif character.running_right then
      character.xv = character.xv + 20
   elseif character.xv > 20 then
      character.xv = character.xv - 20
   elseif character.xv < -20 then
      character.xv = character.xv + 20
   else
      character.xv = 0
   end
   
   -- cap x velocity
   if character.xv > 100 then
      character.xv = 100
   elseif character.xv < -100 then
      character.xv = -100
   end
   
   -- Use constants and delta to modify y velocity
   character.yv = character.yv + delta * 500
   
   -- Move character by x and y
   move_game_rect(character, character.xv * delta, character.yv * delta)

   local platform, startx, starty, endx, endy, ratio_done, t, segment_t
      -- For each platform...
   for platform in _.iter(platforms) do
      -- Move back and forth on a set schedule...
      if platform.movement then
	 platform.t = platform.t + delta
	 
	 t = platform.t % platform.movement.t

	 -- for some stupid reason I'm storing the total back-and-forth time...
	 segment_t = platform.movement.t / 2
	 
	 if t < segment_t then
	    startx, starty = platform.movement.startx, platform.movement.starty
	    endx, endy = platform.movement.endx, platform.movement.endy
	    
	    ratio_done = t / segment_t
	 else
	    startx, starty = platform.movement.endx, platform.movement.endy
	    endx, endy = platform.movement.startx, platform.movement.starty
	    
	    ratio_done = (t - segment_t) / segment_t
	 end
	 
	 place_game_rect(platform, 
			 (startx * (1 - ratio_done) + endx * ratio_done),
			 (starty * (1 - ratio_done) + endy * ratio_done))
      end
   end

   -- TODO: Collect collision events and resolve in a manner consistent with character movement to prevent platform penetration...
   ls.collider:update(delta)
end

function draw_level_state(ls)
   love.graphics.push()
   
   love.graphics.translate(ls.screenx, ls.screeny)
   draw_game_rect(ls.playfield)
   _.each(ls.platforms, draw_game_rect)
   draw_game_rect(ls.end_door)
   draw_game_rect(ls.character)
   
   love.graphics.pop()
end   

function show_text(text, height)
   love.graphics.printf(text, 0, 100 + height, love.graphics.getWidth(), "center")
end

--[[
Game Rect internals: A rectangle with top left .x/.y/.width/.height, a collider instance at .collider corresponding to a specific collider object, a graphics at .graphics and an optional angle in radians at .angle
--]]

-- Produce a game rect from JSON rect, an HC collider and a game rect raphics
function load_game_rect(json, collider, graphics)
   local new_rect = {}
   _.extend(new_rect, json)
   new_rect.collider = collider:addRectangle(new_rect.x, new_rect.y, new_rect.width, new_rect.height)
   if new_rect.angle then
      new_rect.collider:rotate(new_rect.angle)
   end
   new_rect.graphics = graphics
   return new_rect
end

-- Places a game rect *by its center* at the given x and y
function place_game_rect(r, x, y)
   r.x = x
   r.y = y

   r.collider:moveTo(
      r.x + (r.width / 2),
      r.y + (r.height / 2))

   -- TODO: Figure out why this works with angled platforms...
end

function move_game_rect(r, dx, dy)
   r.x = r.x + dx
   r.y = r.y + dy

   r.collider:move(dx, dy)
end

function draw_game_rect(r)
   love.graphics.push()

   love.graphics.translate(r.x + r.width / 2, r.y + r.height / 2)

   if r.angle then
      love.graphics.rotate(r.angle)
   end

   -- See "Graphics"
   local g = r.graphics
   if g.color then
      love.graphics.setColor(unpack(g.color))
      love.graphics.rectangle("fill", - r.width / 2,  - r.height / 2, r.width, r.height)
   elseif g.image then
      love.graphics.draw(g.image, - r.width / 2, - r.height / 2)
   end -- {} - do nothing

   love.graphics.pop()
end