-- Initialize hero behavior specific to this quest.

require("scripts/multi_events")

local hero_meta = sol.main.get_metatable("hero")

--Not sure where else to deal with spin attacks and avoiding the "sword tapping" state which for some reason loops forever
function hero_meta:on_state_changed(new_state)
  local hero = self
  if new_state == "sword spin attack" then
    require("scripts/action/weapon_manager"):process_spin_attack()
  elseif new_state == "sword tapping" then
    sol.main.get_game():simulate_command_released"attack"
    hero:unfreeze()
  end
end


-- Redefine how to calculate the damage received by the hero.
function hero_meta:on_taking_damage(damage)
  local game = self:get_game()
  local hero = self
  local defense = game:get_value("defense") or 1
  damage = damage - defense
  --Strength stat increases defense a bit
  damage = damage - game:get_max_life() * .05  * ((game:get_value"strength" or 10) - 10)
  if game.take_half_damage then
    damage = damage / 2
  end
  if damage < 1 then
    damage = 1
  end

  --if this attack would kill you in 1 hit at above 40% max life
  -- if damage >= game:get_life() and game:get_life() >= (game:get_max_life() * .4) and damage >= (game:get_max_life() * .6) and not game.guts_save_used then
  --   --leave you with half a heart
  --   damage = game:get_life() - 1
  --   game:get_map():get_camera():shake()
  --   sol.audio.play_sound"ohko"
  --   --set this mechanic on a cooldown
  --   game.guts_save_used = true
  --   sol.timer.start(game, 40 * 1000, function() game.guts_save_used = false end)
  -- elseif damage >= game:get_max_life() * .5 then
  --   sol.audio.play_sound"oh_lotsa_damage"
  -- end

  game:remove_life(damage)

  game:set_suspended(true)
  sol.timer.start(game, 120, function()
    game:set_suspended(false)
    self:get_map():get_camera():shake({count = 4, amplitude = 5, speed = 100})
  end) --end of timer

  self:set_invincible(true, 200)

  --Rally
  hero.max_rally_amount = damage
  if hero.rally_timer then hero.rally_timer:stop() end
  hero.can_rally = true
  hero.rally_timer = sol.timer.start(game, 3000, function()
    hero.can_rally = false
    hero.rally_amount = 0
  end)

end

function hero_meta:rally(damage_done)
  local hero = self
  local game = self:get_game()
  damage_done = damage_done - math.max(damage_done - hero.max_rally_amount, 0)
  rally_health = damage_done
  sol.audio.play_sound"rally"
  game:add_life(rally_health)
  hero.max_rally_amount = hero.max_rally_amount - rally_health

  local rally_sprite = hero:create_sprite("entities/effects/rally_glow")
  rally_sprite:set_animation("glow")
  rally_sprite:set_blend_mode"add"
  sol.timer.start(game, 1000, function()
    hero:remove_sprite(rally_sprite)
  end)
end

local MAX_BUFFER_SIZE = 48
function hero_meta:on_position_changed(x,y,z)
  local hero = self
  if not hero.position_buffer then hero.position_buffer = {} end
  local hero = self
  local dir = hero:get_sprite():get_direction()
  table.insert(hero.position_buffer, 1, {x=x,y=y,layer=l,direction=dir})

  if #hero.position_buffer > MAX_BUFFER_SIZE then
    table.remove(hero.position_buffer)
  end
end

return true