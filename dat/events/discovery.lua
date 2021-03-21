--[[
<?xml version='1.0' encoding='utf8'?>
<event name="Discovery">
  <trigger>enter</trigger>
  <chance>100</chance>
 </event>
 --]]
--[[
-- Shows the player fancy messages as they discover things. Meant to be flavourful.
--]]

local love = require 'love'
local lg = require 'love.graphics'
local audio = require 'love.audio'
local love_math = require 'love.math'
local love_shaders = require 'love_shaders'

-- Since we don't actually activate the Love framework we have to fake the
-- the dimensions and width, and set up the origins.
local nw, nh = naev.gfx.dim()
love.x = 0
love.y = 0
love.w = nw
love.h = nh
lg.origin()

event_list = {
   Taiomi = {
      type = "enter",
      name = "disc_taiomi",
      text = "Taiomi, Ship Graveyard",
   },
   Limbo = {
      -- Discover will not work if the planet is found through maps
      --type = "discover",
      --asset = planet.get("Minerva Station"),
      type = "distance",
      dist = 5000,
      pos  = planet.get("Minerva Station"):pos(),
      name = "disc_minerva",
      text = "Minerva Station, Gambler's Paradise",
   },
}

function sfxDiscovery()
   --sfx = audio.newSource( 'snd/sounds/jingles/success.ogg' )
   sfx = audio.newSource( 'snd/sounds/jingles/victory.ogg' )
   sfx:play()
end

function create()
   local event = event_list[ system.cur():nameRaw() ]
   if event == nil then endevent() end

   if event.type=="enter" then
      discover_trigger( event )
   elseif event.type=="discover" then
      hook.discover( "discovered", event )
   elseif event.type=="distance" then
      hook.timer( 500, "heartbeat", event )
   end

   -- Ends when player lands or leaves either way
   hook.enter("endevent")
   hook.land("endevent")
end
function endevent () evt.finish() end
function discovered( type, discovery, event )
   if event.asset and type=="asset" and discovery==event.asset then
      discover_trigger( event )
   end
end
function heartbeat( event )
   local dist = player.pilot():pos():dist( event.pos )
   if dist < event.dist then
      discover_trigger( event )
   else
      hook.timer( 500, "heartbeat", event )
   end
end


function discover_trigger( event )
   -- Break autonav
   player.autonavAbort(string.format(_("You found #o%s#0!"),event.text))

   -- Do event
   if var.peek( event.name ) then
      endevent()
   end
   --var.push( event.name, true )

   -- Play sound and show message
   sfxDiscovery()
   textinit( event.text )
end

text_fadein = 1.5
text_fadeout = 3
function textinit( text )
   textshow    = text
   textsize    = 48
   textfont    = lg.newFont(textsize)
   --textfont    = lg.newFont(_("fonts/CormorantUnicase-Regular.ttf"), textsize)
   textfont:setOutline(1)
   texttimer   = 0
   textlength  = 8
   textwidth   = textfont:getWidth( text )

   -- Render to canvas
   local pixelcode = string.format([[
precision highp float;

#include "lib/simplex.glsl"

const float u_r = %f;
const float u_sharp = %f;

float vignette( vec2 uv )
{
   uv *= 1.0 - uv.yx;
   float vig = uv.x*uv.y * 15.0; // multiply with sth for intensity
   vig = pow(vig, 0.5); // change pow for modifying the extend of the  vignette
   return vig;
}

vec4 effect( vec4 color, Image tex, vec2 uv, vec2 px )
{
   vec4 texcolor = color * texture2D( tex, uv );

   float n = 0.0;
   for (float i=1.0; i<8.0; i=i+1.0) {
      float m = pow( 2.0, i );
      n += snoise( px * u_sharp * 0.003 * m + 1000.0 * u_r ) * (1.0 / m);
   }

   texcolor *= 0.4*n+0.8;
   texcolor.a *= vignette( uv );
   texcolor.rgb *= 0.3;

   return texcolor;
}
]], love_math.random(), 3 )
   local shader = lg.newShader( pixelcode, love_shaders.vertexcode )
   textcanvas = love_shaders.shader2canvas( shader, textwidth*1.5, textsize*2 )

   lg.setCanvas( textcanvas )
   lg.print( textshow, textfont, textwidth*0.25, textsize*0.3 )
   lg.setCanvas()

   hook.renderfg( "textfg" )
   hook.update( "textupdate" )
   hook.timer( textlength*1000, "endevent")
end
function textfg ()
   local alpha = 1
   if texttimer < text_fadein then
      alpha = texttimer / text_fadein
   elseif texttimer > textlength-text_fadeout then
      alpha = (textlength-texttimer) / text_fadeout
   end

   lg.setColor( 1, 1, 1, alpha )

   local x = (love.w-textcanvas.w)*0.5
   local y = (love.h-textcanvas.h)*0.35
   lg.draw( textcanvas, x, y )

   -- Horrible hack, but since the canvas is being scaled by Naev's scale stuff,
   -- we actually draw pretty text ontop using the signed distance transform shader
   -- when it is at full alpha
   if alpha == 1 then
      lg.print( textshow, textfont, x+textwidth*0.25, y+textsize*0.3 )
   end
end
function textupdate( dt )
   texttimer = texttimer + dt
end
