HC = require 'hardoncollider'
_ = require 'underscore.underscore'
require 'json.json'

--[[
Units of motion are in pixels, pixels/s, and pixels/s/s right now.

Types:
level state: The state of a level currently being played
Functions: make_level_state(level) -> level state
Methods: :advance(delta), :draw(), :keypress(key), :keyrelease(key)
Properties: .dead -> bool, .finished -> bool

game rect (rough): A possibly angled game rectangle that can be drawn, can be moved, and causes collision handling
functions: load_game_rect, move_game_rect, place_game_rect, draw_game_rect
(Game rects may have extra non-abstract properties loaded from levels.json (platform info) and used directly, and collision is a bit of a mess.)

game rect graphics: One of { color: { r,g,b,a } }, { image: love.graphics image }, {}

rect description: A table describing a game rectangle as (top-left corner) .x/.y/.width/.height/[.angle]

level: A table of rect descriptions called character (must not have an angle), end_door, playfield, and a list of "platforms" with optional extra data for movement. See "levels.json".
--]]

function show_text(text, height)
   love.graphics.printf(text, 0, 100 + height, love.graphics.getWidth(), "center")
end

function load_levels(filename)
   local contents, length = love.filesystem.read("levels.json")

   return json.decode(contents)
end

-- level -> level state
function make_level_state(level)
   local ls = {}
   local collider = HC(100, 
		       function(...) start_collision_level_state(ls, ...) end,
		       function(...) stop_collision_level_state(ls, ...) end)

   local playfield = load_game_rect(level.playfield, collider, { color = {50,50,200,255} })
   
   return _.extend(ls, 
		   { 
		      advance = advance_level_state,
		      keypress = keypress_level_state,
		      keyrelease = keyrelease_level_state,
		      draw = draw_level_state,
		      dead = false,
		      finished = false,
		      -- internal
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

-- Return 0 if mtv_y is 0
-- Otherwise, take the x/y "shortest" correction given by HC, 
-- and convert it into a pure vertical correction
-- This doesn't give the correct sign.
function verticalize_correction(mtv_x, mtv_y)
   if mtv_y == 0 then
      print("mtv_y is 0! Shouldn't be here!")
      return 0
   elseif mtv_x == 0 then
      return math.abs(mtv_y)
   else
      return math.abs(mtv_y) + math.abs(mtv_x * mtv_x / mtv_y)
   end
end

-- Return x with sign of sign
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

      else -- platform
	 if mtv_y == 0 then
	    move_game_rect(character, mtv_x, 0)
	 else
	    -- Mess with the current first level to get an idea of how broken this is.

	    -- This works, but it's braindamaged
	    -- Someday I'll math so good I only have to use abs once or twice to do this
	    local dy = match_sign(verticalize_correction(mtv_x, mtv_y), mtv_y)

	    move_game_rect(character, 0, dy)
	    
	    -- If attempting to jump on a downward collision (INCORRECT!) give jump velocity.
	    -- TODO: foot collider instead of this nonsense
	    if character.jumping and mtv_y <= 0 then
	       character.yv = -300
	    elseif mtv_y <= 0 then -- Feet touched - stop falling.
	       -- "Zero"
	       -- Actually, slight fall for next tick - Smooth walking on slight inclines and sufficiently slow falling platforms.
	       character.yv = 50
	       -- TODO: Extract platform dx and modify character.xy
	    else --  mtv_y > 0 (hitting head) - stop upward motion without halting fall
	       character.yv = math.max(character.yv, 0)
	    end

	    -- TODO: Limit "climbing" speed, or maximum climbing angle, or both
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
   -- TODO: Normalize delta using loop here.

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
   --_.each(ls.platforms, function(p) p.collider:draw() end)
   draw_game_rect(ls.end_door)
   draw_game_rect(ls.character)
   --ls.character.collider:draw()
   
   love.graphics.pop()
end   

--[[
Game Rect internals: A rectangle with top left .x/.y/.width/.height, a collider instance at .collider corresponding to a specific collider object, a graphics at .graphics and an optional angle in radians at .angle
--]]

-- Produce a game rect from JSON rect, an HC collider and a game rect graphics
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

-- Place a game rect at the given x and y
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
