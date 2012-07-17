HC = require 'hardoncollider'

-- setup stuff and hardcoded level...
function copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

level_1 = {
   character = { x = 0, y = 100, xv = 0, yv = 0, width = 20, height = 40, state = "falling" },
   end_door = { x = 360, y = 240, width = 30, height = 60 },
   platforms = {
      { x = 0, y = 300, width = 100, height = 100 },
      { x = 140, y = 250, t = 0, movement = { startx = 140, starty = 250, endx = 260, endy = 250, t = 4 }, width = 50, height = 20,  },
      { x = 300, y = 300, width = 100, height = 100 }
   }
}

level_2 = {
   character = { x = 0, y = 260, xv = 0, yv = 0, width = 20, height = 40, state = "falling" },
   end_door = { x = 360, y = 240, width = 30, height = 60 },
   platforms = {
      { x = 0, y = 300, width = 100, height = 100 },
      { x = 200, y=50, t = 0, movement = { startx = 200, starty = 50, endx = 200, endy = 350, t = 6 }, width = 50, height = 20,  },
      { x = 300, y = 300, width = 100, height = 100 }
   }
}

level_3 = {
   character = { x = 40, y = 330, xv = 0, yv = 0, width = 20, height = 40, state = "falling" },
   end_door = { x = 30, y = 90, width = 30, height = 60 },
   platforms = {
      { x = 30, y = 370, width = 100, height = 20 },
      { x = 230, y = 370, width = 100, height = 20 },
      { x = 430, y = 370, width = 100, height = 20 },
      { x = 500, y = 290, width = 100, height = 20 },
      { x = 30, y = 150, width = 100, height = 20 },
      { x = 230, y = 150, width = 100, height = 20 },
      { x = 430, y = 215, width = 100, height = 20 },

   }
}

function load_level(level)
   collider:clear()

   character = copy(level.character)
   character.collider = collider:addRectangle(character.x, character.y, character.width, character.height)
   
   end_door = copy(level.end_door)
   end_door.collider = collider:addRectangle(end_door.x, end_door.y, end_door.width, end_door.height)

   platforms = {}
  
   for i,platform in ipairs(level.platforms) do
      table.insert(platforms,(copy(platform)))
   end

   for i,platform in ipairs(platforms) do
      platform.collider = collider:addRectangle(platform.x, platform.y, platform.width, platform.height)
   end

   -- Mainly because we can just clear out the collider...
   playfield.collider = collider:addRectangle(0,0,playfield.width,playfield.height)
end

function love.load()
   collider = HC(100, on_collision, collision_stop)

   character_graphic = love.graphics.newImage('char.png')

   levels = {level_1, level_2, level_3}

   playfield = { width = 600, height = 400 }
   playfield.screenx = 400 - playfield.width / 2
   playfield.screeny = 300 - playfield.height / 2

   game_state = "front"
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
	 if math.abs(mtv_y) > 0 then
	    character.x = character.x + mtv_x
	    character.y = character.y + mtv_y
	    character.yv = 0
	    
	    character.collider:move(mtv_x, mtv_y)
	    
	    -- prevents "clining" to platforms form the bottom...
	    if character.jumping and mtv_y < 0 then
	       character.yv = -300
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
	 reset_character()
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
      love.graphics.printf(text, playfield.screenx, playfield.screeny + height, playfield.width, "center")
end

function draw_character()
   love.graphics.draw(character_graphic, playfield.screenx + character.x, playfield.screeny + character.y)
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