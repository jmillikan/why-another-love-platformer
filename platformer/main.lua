HC = require 'hardoncollider'
_ = require 'underscore.underscore'
require 'json.json'

function copy(orig)
   local c = {}
   _.extend(c, orig)
   return c
end

function collide_rect(rect)
   rect.collider = collider:addRectangle(rect.x, rect.y, rect.width, rect.height)
   if rect.angle then
      rect.collider:rotate(rect.angle)
   end
end

function load_level(level)
   collider = HC(100, on_collision, collision_stop)

   character = copy(level.character)
   collide_rect(character)
   
   end_door = copy(level.end_door)
   collide_rect(end_door)

   platforms = _.map(level.platforms, copy)
   _.each(platforms, collide_rect)
   
   playfield = copy(level.playfield)
   collide_rect(playfield)
   playfield.screenx = love.graphics.getWidth() / 2 - playfield.width / 2
   playfield.screeny = love.graphics.getHeight() / 2 - playfield.height / 2
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
	 -- TODO: More better
	 if mtv_y ~= 0 then
	    local dy
	    if mtv_x ~= 0 then
	       -- print("Angle collision")
	       dy = mtv_y - mtv_x / math.atan2(mtv_y, mtv_x)
	    else
	       dy = mtv_y
	    end
	    
	    --character.x = character.x + mtv_x
	    character.y = character.y + dy
	    character.yv = 0
	    
	    character.collider:move(0, dy)
	    
	    -- prevents "clining" to platforms form the bottom...
	    if character.jumping and mtv_y < 0 then
	       character.yv = -300
	    end
	 elseif math.abs(mtv_x) > 0 then
	    character.x = character.x + mtv_x
	    character.y = character.y + mtv_y
	    --	    character.xv = 0

	    character.collider:move(mtv_x, mtv_y)
	 end
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

function love.update(delta)
   x = x + 1
   
   if game_state ~= "running" and game_state ~= "ending" then return end

   if game_state == "running" or game_state == "ending" then
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

      if character.xv > 100 then
	 character.xv = 100
      elseif character.xv < -100 then
	 character.xv = -100
      end


      character.yv = character.yv + delta * 500
      character.y = character.y + character.yv * delta
      character.x = character.x + character.xv * delta
      character.collider:move(character.xv * delta, character.yv * delta)

      for platform in _.iter(platforms) do
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

	    platform.x = (startx * (1 - ratio_done) + endx * ratio_done)
	    platform.y = (starty * (1 - ratio_done) + endy * ratio_done)

	    update_rect_collider(platform)
	 end
      end

      -- TODO: Collect collision events and resolve in a manner consistent with character movement to prevent platform penetration...
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

function update_rect_collider(platform)
   platform.collider:moveTo(
      platform.x + (platform.width / 2),
      platform.y + (platform.height / 2))
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
      draw_level()
      draw_character()
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

function draw_character()
   love.graphics.push()
   love.graphics.translate(playfield.screenx + character.x + character.width / 2, playfield.screeny + character.y + character.height / 2)

   --   love.graphics.rotate(math.pi / 4)

   love.graphics.draw(character_graphic, - character.width / 2, - character.height / 2)
   love.graphics.pop()
end

function draw_level()
   love.graphics.setColor(50, 50, 200)
   draw_game_rect(playfield)

   love.graphics.setColor(40, 230, 100, 100)
   _.each(platforms, draw_game_rect)

   love.graphics.setColor(230,230,230)
   draw_game_rect(end_door)
end

function draw_game_rect(r)
   love.graphics.push()
   love.graphics.translate(playfield.screenx + r.x + r.width / 2, playfield.screeny + r.y + r.height / 2)

   if r.angle then
      love.graphics.rotate(r.angle)
   end

   love.graphics.rectangle("fill", - r.width / 2,  - r.height / 2, r.width, r.height)
   love.graphics.pop()
end