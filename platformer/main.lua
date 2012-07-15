HC = require 'hardoncollider'

-- setup stuff and hardcoded level...

function reset_character()
   collider:remove(character.collider)

   character = { x = 0, y = 100, xv = 0, yv = 0, drawable = character_graphic, width = 20, height = 40, state = "falling" }
   character.collider = collider:addRectangle(character.x, character.y, character.width, character.height)
end

function load_level(level)
   character = { x = 0, y = 100, xv = 0, yv = 0, drawable = character_graphic, width = 20, height = 40, state = "falling" }
   character.collider = collider:addRectangle(character.x, character.y, character.width, character.height)

   end_door = { x = 360, y = 240, width = 30, height = 60 }
   end_door.collider = collider:addRectangle(end_door.x, end_door.y, end_door.width, end_door.height)

   platforms = {
      { x = 0, y = 300, width = 100, height = 100 },
      { x = 140, y = 250, t = 0, movement = { startx = 140, starty = 250, endx = 260, endy = 250, t = 4 }, width = 50, height = 20,  },
      { x = 300, y = 300, width = 100, height = 100 }
   }

   for i,platform in ipairs(platforms) do
      platform.collider = collider:addRectangle(platform.x, platform.y, platform.width, platform.height)
   end
end

function love.load()
   collider = HC(100, on_collision, collision_stop)

   character_graphic = love.graphics.newImage('char.png')

   playfield = { width = 400, height = 400 }
   playfield.collider = collider:addRectangle(0,0,playfield.width,playfield.height)
   playfield.screenx = 400 - playfield.width / 2
   playfield.screeny = 300 - playfield.height / 2

   load_level()
   game_state = "running"
end

-- Game mechanics...

function on_collision(dt, shape_a, shape_b, mtv_x, mtv_y)
   if shape_b == character.collider then
      on_collision(dt, shape_b, shape_a, -mtv_x, -mtv_y)
   elseif shape_a == character.collider then

      if shape_b == end_door.collider then
	 game_state = "ending"
      elseif shape_b == playfield.collider then

      else

	 -- TODO: More better
	 if math.abs(mtv_y) > 0 then
	    character.x = character.x + mtv_x
	    character.y = character.y + mtv_y
	    character.yv = 0
	    
	    character.collider:move(mtv_x, mtv_y)

	    if character.jumping then
	       character.yv = -400
	    end
	 elseif math.abs(mtv_x) > 0 then
	    character.x = character.x + mtv_x
	    character.y = character.y + mtv_y
	    character.xv = 0

	    character.collider:move(mtv_x, mtv_y)
	 end

	 if math.abs(mtv_x) > 0 and math.abs(mtv_y) > 0 then
	    print("Diagonal collision")
	 end

      end
   end
end

function collision_stop(dt, shape_a, shape_b)
   if shape_b == character.collider then
      collision_stop(dt, shape_b, shape_a)
   elseif shape_a == character.collider then
      if shape_b == playfield.collider then 
	 reset_character()
      end
   end
end


function love.update(delta)
   if game_state ~= "running" and game_state ~= "ending" then return end

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

   for i,platform in ipairs(platforms) do
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

   collider:update(delta)
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
   end

   if key == "n" then
      reset_character()
      game_state = "running"
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
   draw_level()
   draw_character()
end

function draw_character()
   love.graphics.draw(character.drawable, playfield.screenx + character.x, playfield.screeny + character.y)
end

function draw_level()
   love.graphics.setColor(50, 50, 200)
   love.graphics.rectangle("fill", playfield.screenx, playfield.screeny, playfield.width, playfield.height)

   for i,platform in ipairs(platforms) do
      love.graphics.setColor(40, 230, 100, 100)
      draw_game_rect(platform)
   end

   love.graphics.setColor(230,230,230)
   draw_game_rect(end_door)
end

function draw_game_rect(r)
   love.graphics.rectangle("fill", playfield.screenx + r.x, playfield.screeny + r.y, r.width, r.height)
end