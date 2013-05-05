HC = require 'hardoncollider'
_ = require 'underscore.underscore'
require 'json.json'

--[[
game rect (convention): A rectangle with top left .x/.y/.width/.height, a collider instance at .collider corresponding to a specific collider object, a graphics at .graphics and an optional angle in radians at .angle
(move_game_rect, place_game_rect, draw_game_rect)

graphics (for a game rect): One of { color: { r,g,b,a } }, { image: love.graphics image }, {}

TODO: Have a defined graphics aspect of GameRect to simplify drawing


--]]

function copy(orig)
   local c = {}
   _.extend(c, orig)
   return c
end


-- Produce a game rect from a JSON object containing x/y/width/height[/angle], a game rect graphics, and an HC collider
function load_game_rect(json, collider, graphics)
   local new_rect = copy(json)
   new_rect.collider = collider:addRectangle(new_rect.x, new_rect.y, new_rect.width, new_rect.height)
   if new_rect.angle then
      new_rect.collider:rotate(new_rect.angle)
   end
   new_rect.graphics = graphics
   return new_rect
end

-- Set global game state to initial state of JSON-loaded level
-- TODO: Load to a defined game state object
function load_level(level)
   -- global
   collider = HC(100, on_collision, collision_stop)

   character = load_game_rect(level.character, collider, { image = love.graphics.newImage('char.png') })
   platforms = _.map(level.platforms,
		     function(p)
			return load_game_rect(p, collider, { color = {40,230,100,100} })
		     end)
   end_door = load_game_rect(level.end_door, collider, { color = {255,255,255,255} })
   playfield = load_game_rect(level.playfield, collider, { color = {50,50,200,255} })

   -- "Camera"
   screenx = love.graphics.getWidth() / 2 - playfield.width / 2
   screeny = love.graphics.getHeight() / 2 - playfield.height / 2
end

function love.load()
   character_graphic = love.graphics.newImage('char.png')
   
   levels = parse_levels()

   game_state = "front"
end

function parse_levels()
   local contents, length = love.filesystem.read("levels.json")

   return json.decode(contents)
end

-- Game mechanics...

-- collider_before_ghosts = {}
-- collider_after_ghosts = {}

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
   if sign >= 0 then
      return math.abs(x)
   else 
      return -math.abs(x)
   end
end

function on_collision(dt, shape_a, shape_b, mtv_x, mtv_y)
   if shape_b == character.collider then
      on_collision(dt, shape_b, shape_a, -mtv_x, -mtv_y)
   elseif shape_a == character.collider then

      if shape_b == end_door.collider then
	 if game_state ~= "ending" then
	    game_state = "ending"
	    ending_time = 2
	    character.running_left = false
	    character.running_right = false
	    character.jumping = false
	 end
      elseif shape_b == playfield.collider then

      else
	 -- table.insert(collider_before_ghosts,copy(character))

	 -- TODO: More better
	 local dy = verticalize_correction(mtv_x, mtv_y)
	 dy = match_sign(dy, mtv_y)
	 
	 move_game_rect(character, 0, dy)
	 
	 -- If attempting to jump on a downward collision (INCORRECT!) give jump velocity.
	 -- TODO: foot collider
	 if character.jumping and mtv_y < 0 then
	    character.yv = -300
	 else
	    character.yv = 0
	 end
	 -- table.insert(collider_after_ghosts,copy(character))
      end
   end
end

function collision_stop(dt, shape_a, shape_b)
   if shape_b == character.collider then
      collision_stop(dt, shape_b, shape_a)
   elseif shape_a == character.collider then
      if shape_b == playfield.collider then 
	 load_level(levels[current_level])
      end
   end
end

x = 0   

-- TODO: Either normalize delta of game updates or (less likely) fix mechanics to correct for size of delta
function love.update(delta)
   x = x + 1
   
   if game_state ~= "running" and game_state ~= "ending" then return end

   if game_state == "running" or game_state == "ending" then

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

      -- For each platform...
      for platform in _.iter(platforms) do
	 -- Move back and forth on a set schedule...
	 if platform.movement then
	    platform.t = platform.t + delta

	    local t = platform.t % platform.movement.t

	    -- for some stupid reason I'm storing the total back-and-forth time...
	    local segment_t = platform.movement.t / 2

	    local ratio_done

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

      -- (COLLISION EVENTS OCCUR)
      -- Try separating x and y movements and collisions!

      collider:update(delta)
   end

   if game_state == "ending" then
      ending_time = ending_time - delta
      if ending_time < 0 then
	 current_level = current_level + 1
	 if current_level > #levels then
	    game_state = "won"
	 else
	    load_level(levels[current_level])
	    game_state = "running"
	 end
      end
   end
end

function love.keypressed(key, unicode)
   if game_state == "running" then
      if key == "right" then
	 character.running_right = true
      end

      if key == "left" then
	 character.running_left = true
      end

      if key == "up" then
	 character.jumping = true
      end

      if key == "r" then
	 load_level(levels[current_level])
	 game_state = "running"
      end
   end

   if game_state == "front" or game_state == "won" then
      if key == "n" then
	 current_level = 1
	 load_level(levels[current_level])
	 game_state = "running"
      end
   end
end

function love.keyreleased(key, unicode)
   if game_state == "running" then
      if key == "right" then
	 character.running_right = false
      end

      if key == "left" then
	 character.running_left = false
      end

      if key == "up" then
	 character.jumping = false
      end
   end
end

-- graphics
function love.draw()
   if game_state == "running" or game_state == "ending" then

      love.graphics.push()

      love.graphics.translate(screenx, screeny)
      draw_game_rect(playfield)
      _.each(platforms, draw_game_rect)
      draw_game_rect(end_door)
      draw_game_rect(character)

      love.graphics.pop()

      if game_state == "ending" then
	 show_text("Moving on...", 200)
      end
   elseif game_state == "won" then
      show_text("You won! Another game?", 0)
      show_text("Press n to start", 100)
   elseif game_state == "front" then
      show_text("Why Another Love Platformer", 0)
      show_text("Press n to start", 100)
   end
end

function show_text(text, height)
   love.graphics.printf(text, 0, 100 + height, love.graphics.getWidth(), "center")
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