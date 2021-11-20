local atk = require "ai.core.attack.util"

--[[
-- Main control function for corvette behavior.
--]]
local function atk_corvette( target, dokill )
   target = atk.com_think( target, dokill )
   if target == nil then return end

   -- Targeting stuff
   ai.hostile(target) -- Mark as hostile
   ai.settarget(target)

   -- See if the enemy is still seeable
   if not atk.check_seeable( target ) then return end

   -- Get stats about enemy
   local dist  = ai.dist( target ) -- get distance
   local range = ai.getweaprange(3, 0)
   local range2 = ai.getweaprange(3, 1)

   if range2 > range then
      range = range2
   end

   -- We first bias towards range
   if dist > range * mem.atk_approach and mem.ranged_ammo > mem.atk_minammo then
      atk.ranged( target, dist )

   -- Close enough to melee
   -- TODO: Corvette-specific attack functions.
   else
      if target:stats().mass < 500 then
        atk.space_sup( target, dist )
      else
        mem.aggressive = true
        atk.flyby( target, dist )
      end
   end
end


function atk_corvette_init ()
   mem.atk_think  = atk.heuristic_big_game_think
   mem.atk        = atk_corvette
end
