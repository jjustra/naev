local lg = require 'love.graphics'
local lf = require 'love.filesystem'
--local audio = require 'love.audio'
local love_shaders = require 'love_shaders'
local explosion = require 'luaspfx.explosion'

local spacemine_bg_shader_frag = lf.read( "scripts/luaspfx/shaders/pulse.frag" )
local spacemine_shader

local function explode( s, d )
   local damage = 1000
   explosion( s:pos(), s:vel(), d.explosion, damage, d.pilot )
   s:rm() -- Remove
end

local function update( s, dt )
   local d = s:data()
   d.timer = d.timer + dt

   local sp = s:pos()
   local mod, angle = s:vel():polar()
   if mod > 1e-3 then
      s:setVel( vec2.newP( math.max(0,mod-100*dt), angle ) )
   end

   -- Not primed yet
   if d.timer < d.primed then
      return
   end

   -- See what can trigger it
   local triggers
   if d.fct then
      triggers = pilot.getHostiles( d.fct, d.range, sp, false, true )
   else
      triggers = pilot.getInrange( sp, d.range )
   end

   -- Detect nearby enemies
   for k,p in ipairs(triggers) do
      local ew = p:evasion()
      -- if perfectly tracked, we don't have to do fancy computations
      if ew <= d.track then
         explode( s, d )
         return
      end
      -- Have to see if it triggers now
      local dst = p:pos():dist( sp )
      if d.range * d.track < dst * ew then
         explode( s, d )
         return
      end
   end
end

local function render( sp, x, y, z )
   local d = sp:data()
   spacemine_shader:send( "u_time", d.timer )

   -- TODO render something nice that blinks
   local s = d.size * z
   local old_shader = lg.getShader()
   --lg.setShader( spacemine_shader )
   lg.setColor( d.col )
   love_shaders.img:draw( x-s*0.5, y-s*0.5, 0, s )
   lg.setShader( old_shader )
end

local function spacemine( pos, vel, fct, params )
   params = params or {}
   -- Lazy loading shader / sound
   if not spacemine_shader then
      spacemine_shader = lg.newShader( spacemine_bg_shader_frag )
   end

   -- Sound is handled separately in outfit
   local s  = spfx.new( 90, update, nil, nil, render, pos, vel )
   local d  = s:data()
   d.timer  = 0
   d.size   = 100 -- TODO replace with sprite
   d.range  = 300
   d.explosion = 500
   d.fct    = fct
   d.track  = params.track or 3000
   d.pilot  = params.pilot
   d.primed = params.primed or 0
   return s
end

return spacemine
