--[[
   Simple skeleton for your standard faction. This is more or less what the
   standard behaviour can be, but from here you can let your imagination go
   wild.
--]]
local sbase = {}
friendly_at = 70 -- global


function sbase.init( args )
   args = args or {}
   sbase.fct                = args.fct                              -- The faction

   local function param( name, def )
      sbase[name] = args[name] or def
   end

   -- Some general faction parameters
   param( "hit_range",     2 ) -- Range at which it affects
   param( "rep_min",       -100 )
   param( "rep_max",       100 )
   param( "secondary_default", 0.5 )
   param( "rep_max_var",   nil ) -- Mission variable to use for limits if defined

   -- Type of source parameters.
   param( "destroy_max",   30 )
   param( "destroy_mod",   1 )

   --param( "disable_max",   20 )
   --param( "disable_mod",   0.3 )

   param( "board_max",     20 )
   param( "board_mod",     1 )

   param( "capture_max",   30 )
   param( "capture_mod",   1 )

   param( "distress_max",  -20 ) -- Can't get positive  reputation from distress
   param( "distress_mod",  0 )

   param( "scan_max",      -100 ) -- Can't gain reputation scanning by default
   param( "scan_mod",      0 )

   -- Amount of faction lost when the pilot distresses at the player
   -- Should be roughly 1 for a 20 point llama and 4.38 for a 150 point hawking
   --mem.distress_hit = math.max( 0, math.pow( p:ship():points(), 0.37 )-2)

   -- Allows customizing relationships with other factions
   param( "attitude_toward", {} )

   -- Text stuff
   sbase.text = args.text or {
      [100] = _("Legend"),
      [90]  = _("Hero"),
      [70]  = _("Comrade"),
      [50]  = _("Ally"),
      [30]  = _("Partner"),
      [10]  = _("Associate"),
      [0]   = _("Neutral"),
      [-1]  = _("Outlaw"),
      [-30] = _("Criminal"),
      [-50] = _("Enemy"),
   }
   sbase.text_friendly = args.text_friendly or _("Friendly")
   sbase.text_neutral  = args.text_neutral or _("Neutral")
   sbase.text_hostile  = args.text_hostile or _("Hostile")
   sbase.text_bribed   = args.text_bribed or _("Bribed")
   return sbase
end

-- based on GLSL clamp
local function clamp( x, min, max )
   return math.max( min, math.min( max, x ) )
end

-- Applies a local hit to a system
local function hit_local( sys, mod, max )
   -- Case system and no presence, it doesn't actually do anything...
   if sys and sys:presence( sbase.fct )<=0 then
      return
   end
   -- Just simple application based on local reputation
   local r = sys:reputation( sbase.fct )
   max = math.max( r, max ) -- Don't lower under the current value
   local f = math.min( max, r+mod )
   sys:setReputation( sbase.fct, clamp( f, sbase.rep_min, sbase.rep_max ) )
   return f-r
end

-- Determine max and modifier based on type and whether is secondary
local function hit_mod( modin, source, secondary, primary_fct )
   local max, mod

   -- Split by type
   if source=="destroy" then
      max = sbase.destroy_max
      mod = sbase.destroy_mod
   elseif source=="board" then
      max = sbase.board_max
      mod = sbase.board_mod
   elseif source=="caputer" then
      max = sbase.caputer_max
      mod = sbase.caputer_mod
   elseif source=="distress" then
      max = sbase.distress_max
      mod = sbase.distress_mod
   elseif source=="scan" then
      max = sbase.scan_max
      mod = sbase.scan_mod
   else -- "script" type is handled here
      max = sbase.rep_max
      mod = 1
   end

   -- Modify secondaries
   if secondary ~= 0 then
      -- If we have a particular attitude towards a government, expose that
      local at = sbase.attitude_toward[ primary_fct:nameRaw() ]
      if at then
         mod = mod * at
      else
         mod = mod * sbase.secondary_default
      end
   end

   return max, mod * modin
end

--[[
Handles a faction hit for a faction.

Possible sources:
   - "destroy": Pilot death.
   - "disable": Pilot ship was disabled.
   - "board": Pilot ship was boarded.
   - "capture": Pilot ship was captured.
   - "distress": Pilot distress signal.
   - "scan": when scanned by pilots and illegal content is found
   - "script": Either a mission or an event.

   @param sys System (or nil for global) that is having the hit
   @param mod Amount of faction being changed.
   @param source Source of the faction hit.
   @param secondary Flag that indicates whether this is a secondary hit. If 0 it is primary, if +1 it is secondary hit from ally, if -1 it is a secondary hit from an enemy.
   @param primary_fct In the case of a secondary hit, the faction that caused the primary hit.
   @return The faction amount to set to.
--]]
function hit( sys, mod, source, secondary, primary_fct )
   local  max
   max, mod = hit_mod( mod, source, secondary, primary_fct )

   -- No system, so just do the global hit
   if not sys then
      local changed
      if mod < 0 then
         changed = math.huge
      else
         changed = -math.huge
      end
      -- Apply change to all systems
      local minsys, maxsys
      local minval, maxval = math.huge, -math.huge
      for k,s in ipairs(system.getAll()) do
         local r = s:reputation( sbase.fct )
         if r < minval then
            minsys = s
            minval = r
         end
         if r > maxval then
            maxsys = s
            maxval = r
         end
         local f = math.min( max, r+mod )
         if mod < 0 then
            changed = math.min( changed, f-r )
         else
            changed = math.max( changed, f-r )
         end
         s:setReputation( sbase.fct, clamp( f, sbase.rep_min, sbase.rep_max ) )
      end

      -- Now propagate the thresholding from the max or min depending on sign of mod
      if mod >= 0 then
         sys = maxsys
      else
         sys = minsys
      end
      sbase.fct:applyLocalThreshold( sys )
      return changed
   end

   -- Center hit on sys and have to expand out
   local val = hit_local( sys, mod, max )
   if sbase.hit_range > 0 then
      local done = { sys }
      local todo = { sys }
      for dist=1,sbase.hit_range do
         local dosys = {}
         for i,s in ipairs(todo) do
            for j,n in ipairs(s:adjacentSystems()) do
               if not inlist( done, n ) then
                  local v = hit_local( n, mod / (dist+1), max )
                  if not val then
                     val = v
                  end
                  table.insert( done, n )
                  table.insert( dosys, n )
               end
            end
         end
         todo = dosys
      end
   end

   -- Update frcom system that did hit and return change at that system
   sbase.fct:applyLocalThreshold( sys )
   return val or 0
end

--[[
Highly simplified version that doesn't take into account maximum standings and the likes.
--]]
function hit_test( _sys, mod, source )
   local  _max
   _max, mod = hit_mod( mod, source, 0 )
   return mod
end

--[[
Returns a text representation of the player's standing.

   @param value Current standing value of the player.
   @return The text representation of the current standing.
--]]
function text_rank( value )
   for i = math.floor( value ), 0, ( value < 0 and 1 or -1 ) do
      if sbase.text[i] ~= nil then
         return sbase.text[i]
      end
   end
   return sbase.text[0]
end

--[[
Returns a text representation of the player's broad standing.

   @param value Current standing value of the player.
   @param bribed Whether or not the respective pilot is bribed.
   @param override If positive it should be set to ally, if negative it should be set to hostile.
   @return The text representation of the current broad standing.
--]]
function text_broad( value, bribed, override )
   if override == nil then override = 0 end

   if bribed then
      return sbase.text_bribed
   elseif override > 0 or value >= friendly_at then
      return sbase.text_friendly
   elseif override < 0 or value < 0 then
      return sbase.text_hostile
   else
      return sbase.text_neutral
   end
end

--[[
   Returns the maximum reputation limit of the player.
--]]
function reputation_max ()
   if sbase.rep_max_var == nil then
      return sbase.rep_max
   end

   local cap   = var.peek( sbase.cap_misn_var )
   if cap == nil then
      cap = sbase.cap_misn_def
      var.push( sbase.cap_misn_var, cap )
   end
   return cap
end

return sbase
