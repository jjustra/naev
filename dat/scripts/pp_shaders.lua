--[[--
   Post-processing shader library for Lua.

   This basically wraps around the shader framework and allows to easily create
   some post-processing shaders with minimal code overhead.
   @module pp_shaders
--]]
local pp_shaders = {}

-- We load the C-side shader for the vertex shader
local f = file.new( 'glsl/postprocess.vert' )
f:open('r')
pp_shaders.vertexcode = "#version 140\n"..f:read()

--[[--
   Creates a new post-processing shader.

   @tparam string fragcode Fragment shader code.
   @return The newly created shader.
--]]
function pp_shaders.newShader( fragcode )
   return shader.new([[
#version 140

uniform sampler2D MainTex;
uniform vec4 love_ScreenSize;
in vec4 VaryingTexCoord;
out vec4 color_out;

vec4 effect( sampler2D tex, vec2 texcoord, vec2 pixcoord );

void main (void)
{
   color_out = effect( MainTex, VaryingTexCoord.st, love_ScreenSize.xy );
}
]] .. fragcode, pp_shaders.vertexcode )
end


--[[
-- A post-processing version of the corruption shader.
--]]
function pp_shaders.corruption( strength )
   strength = strength or 1.0
   local pixelcode = string.format([[
#include "lib/math.glsl"

   uniform float u_time;

   const int    fps     = 15;
   const float strength = %f;

   vec4 effect( sampler2D tex, vec2 uv, vec2 px ) {
      float time = u_time - mod( u_time, 1.0 / float(fps) );
      float glitchStep = mix(4.0, 32.0, random(vec2(time)));
      vec4 screenColor = texture( tex, uv );
      uv.x = round(uv.x * glitchStep ) / glitchStep;
      vec4 glitchColor = texture( tex, uv );
      return mix(screenColor, glitchColor, vec4(0.1*strength));
   }
   ]], strength )
   return pp_shaders.newShader( pixelcode )
end

return pp_shaders
