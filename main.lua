function _init()
	-- state machine as function pointers
	_update_func = update_game
	_draw_func = draw_game

  -- init player with default position, spawn will find right location
	player = {
		x = 8,
		y = 8,
		sprite = 240,
		flip_x = false,
		alive = true,
	}
  enemies_timer=0
  enemies = {}
	bombs_limit = 2
	bombs = {}

  spawn()

end

function spawn()
  for i = 0, 15 do
    for j = 0, 15 do
      -- Found player
      if mget(i, j) == 240 then
        player.x = i * 8
        player.y = j * 8
        mset(i,j,0)
      end
      if mget(i, j) == 208 then
        add(enemies, {
          x= i*8,
          y = j *8,
          sprite =208,
          flip_x = false,
          alive = true,
          dir_x = 1, -- moving to the right
          dir_y = 0,
        })
        mset(i,j,0)
      end
      if mget(i, j) == 209 then
        add(enemies, {
          x= i*8,
          y = j *8,
          sprite =209,
          flip_x = false,
          alive = true,
          dir_x = 0,
          dir_y = 1, -- moving up
        })
        mset(i,j,0)
      end
    end
  end
end

function _update60()
	_update_func()
end

function _draw()
	_draw_func()
end

function state_dead()
	printh("dead")
end

function update_game()
	-- Make character move one tile at a time, each tile is 8x8 pixels
	local move_x, move_y = 0, 0
	-- left
	if btnp(0) and player.x > 0 then
		move_x = -8
		player.flip_x = true
	end
	-- right
	if btnp(1) and player.x < 120 then
		move_x = 8
		player.flip_x = false
	end
	-- up
	if btnp(2) and player.y > 0 then
		move_y = -8
	end
	-- down
	if btnp(3) and player.y < 120 then
		move_y = 8
	end

	-- Apply movement
	local final_x, final_y = player.x + move_x, player.y + move_y
	local tile_x, tile_y = final_x / 8, final_y / 8

	local tile = mget(tile_x, tile_y)

	-- Collision
	if fget(tile, 0) then
		return
	end
	player.x = final_x
	player.y = final_y

	-- Add bomb
	if btnp(5) and #bombs < bombs_limit then
		add_bomb(final_x, final_y)
	end

	for bomb in all(bombs) do
		-- Coutdown for bomb
		bomb.time_left -= 1

		-- removing bomb from memory
		if bomb.time_left <= 0 then
			printh("deleting bomb")
			del(bombs, bomb)
		end

		if bomb.time_left <= 30 then
			for blast in all(bomb.blasts) do
				local blast_rect, player_rect = to_rect(blast), to_rect(player)
				if collide_rect(player_rect, blast_rect) then
					player.alive = false
					_update_func = state_dead
				end
			end
		end
	end

  enemies_timer += 1
  for enemy in all(enemies) do
    if enemies_timer % 60 != 0 then
      break
    end
    enemies_timer = 0

    local new_x = enemy.x +  enemy.dir_x * 8

    if fget(mget(new_x/8, enemy.y /8), 0) then
      enemy.dir_x *= -1
      break
    end
    enemy.x = enemy.x +  enemy.dir_x * 8

    local new_y = enemy.y +  enemy.dir_y * 8

    if fget(mget(enemy.x/8, new_y /8), 0) then
      enemy.dir_y *= -1
      break
    end
    enemy.y = enemy.y +  enemy.dir_y * 8

  end
end

function draw_game()
	-- Game drawing logic goes here
	cls()
	map()

	if not player.alive then
		print("DEAD", 0, 118, 7)
	end

	-- print("player pos:" .. player.x .. "," .. player.y, 0, 118, 8)
	-- Draw a grid for debugging
	-- for i = 0, 16 do
	--     for j = 0, 16 do
	--         spr(1, i * 8, j * 8)
	--     end
	-- end

	-- render bombs if any
	for bomb in all(bombs) do
		printh("bomb " .. bomb.x .. "," .. bomb.y .. " | " .. bomb.time_left)
		local b_tile_x, b_tile_y = bomb.x / 8, bomb.y / 8
		mset(b_tile_x, b_tile_y, 224)

		-- blasts
		if bomb.time_left <= 30 then
			for blast in all(bomb.blasts) do
				local blast_tile_x, blast_tile_y = blast.x / 8, blast.y / 8

        -- Only draw blast if it's not the brick tile
        if mget(blast_tile_x, blast_tile_y) != 2 then
				  spr(blast.spr, blast.x, blast.y, 1, 1, blast.flip_x, blast.flip_y)
        end


				local tile = mget(blast_tile_x, blast_tile_y)
				-- Remove elements from map when under blast radious, if tile has flag 1
				if fget(tile, 1) then
					mset(blast_tile_x, blast_tile_y, 0)
				end
			end
		end
		-- This removes the bomb from the map,
		-- if we used spr we wouldn't have to do that, but we would
		-- loose the collision system
		if bomb.time_left <= 1 then
			printh("deleting bomb")
			mset(bomb.x / 8, bomb.y / 8, 0)
		end
	end
	spr(player.sprite, player.x, player.y, 1, 1, player.flip_x)

  -- render enemies
  for enemy in all(enemies) do
	  spr(enemy.sprite, enemy.x, enemy.y, 1, 1, enemy.flip_x)
  end
end

function add_bomb(x, y)
	add(bombs, {
		x = x,
		y = y,
		time_left = 120,
		blasts = {
			{
				x = x,
				y = y + 8,
				flip_x = false,
				flip_y = true,
				spr = 225,
			},
			{
				x = x + 8,
				y = y,
				flip_x = false,
				flip_y = false,
				spr = 226,
			},
			{
				x = x - 8,
				y = y,
				flip_x = true,
				flip_y = false,
				spr = 226,
			},
			{
				x = x,
				y = y - 8,
				flip_x = false,
				flip_y = false,
				spr = 225,
			},
		},
	})
end

-- simple box collision:
-- takes rectangle coords for
-- two sprites.
-- return true if bounding
-- rectangles overlap, false
-- otherwise
function collide_rect(r1, r2)
	if (r1.x1 > r2.x2) or (r2.x1 > r1.x2) or (r1.y1 > r2.y2) or (r2.y1 > r1.y2) then
		return false
	end
	return true
end
-- return a rectangle structure
-- based on a sprite, with
-- start and end x/y screen
-- coordinates
function to_rect(sp)
	local r = {}
	r.x1 = sp.x
	r.y1 = sp.y
	-- r.x2 = sp.x + sp.w - 1
	r.x2 = sp.x + 8 - 1
	-- r.y2 = sp.y + sp.h - 1
	r.y2 = sp.y + 8 - 1
	return r
end
