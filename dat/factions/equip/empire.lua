local equipopt = require 'equipopt'
local mt = require 'merge_tables'
local eoutfits = require 'equipopt.outfits'

local empire_outfits = eoutfits.merge{{
   -- Heavy Weapons
   "Empire Lancelot Fighter Bay",
   "Turbolaser", "Heavy Ripper Turret", "Ragnarok Beam",
   "Heavy Laser Turret", "Railgun",
   -- Medium Weapons
   "Heavy Ripper Cannon", "Laser Turret MK2", "Orion Beam",
   "TeraCom Fury Launcher", "Unicorp Headhunter Launcher",
   "Unicorp Vengeance Launcher", "Enygma Systems Spearhead Launcher",
   "Unicorp Caesar IV Launcher", "Enygma Systems Turreted Fury Launcher",
   -- Small Weapons
   "Unicorp Banshee Launcher", "TeraCom Banshee Launcher",
   --"Unicorp Mace Launcher", "TeraCom Mace Launcher",
   "Laser Cannon MK1", "Plasma Blaster MK1", "Ion Cannon",
   "Ripper Cannon",
   -- Utility
   "Hunting Combat AI", "Photo-Voltaic Nanobot Coating",
   "Unicorp Scrambler", "Unicorp Light Afterburner",
   "Sensor Array", "Hellburner", "Emergency Shield Booster",
   "Unicorp Medium Afterburner", "Droid Repair Crew",
   -- Heavy Structural
   "Battery IV", "Large Fuel Pod", "Battery III", "Reactor Class III",
   "Shield Capacitor III", "Nanobond Plating",
   -- Medium Structural
   "Medium Fuel Pod", "Battery II", "Shield Capacitor II",
   "Active Plating", "Reactor Class II",
   -- Small Structural
   "Plasteel Plating", "Battery I", "Improved Stabilizer", "Engine Reroute",
   "Reactor Class I", "Small Fuel Pod",
}}
local empire_outfits_collective = false


local empire_params = {
   ["Empire Lancelot"] = function () return {
         type_range = {
            ["Launcher"] = { min = 1 },
         },
      } end,
   ["Empire Peacemaker"] = function () return {
         ["turret"] = 2,
      } end,
}

local function choose_one( t ) return t[ rnd.rnd(1,#t) ] end
local empire_cores = {
   ["Empire Shark"] = function () return {
         "Milspec Orion 2301 Core System",
         "Tricon Zephyr Engine",
         choose_one{ "Nexus Light Stealth Plating", "S&K Ultralight Combat Plating" },
      } end,
   ["Empire Lancelot"] = function () return {
         "Milspec Orion 3701 Core System",
         "Tricon Zephyr II Engine",
         choose_one{ "Nexus Light Stealth Plating", "S&K Light Combat Plating" },
      } end,
   ["Empire Admonisher"] = function () return {
         "Milspec Orion 4801 Core System",
         "Tricon Cyclone Engine",
         choose_one{ "Nexus Medium Stealth Plating", "S&K Medium Combat Plating" },
      } end,
   ["Empire Pacifier"] = function () return {
         "Milspec Orion 5501 Core System",
         "Tricon Cyclone II Engine",
         "S&K Medium-Heavy Combat Plating",
      } end,
   ["Empire Hawking"] = function () return {
         "Milspec Orion 8601 Core System",
         "Tricon Typhoon Engine",
         choose_one{ "Unicorp D-48 Heavy Plating", "Unicorp D-68 Heavy Plating" },
      } end,
   ["Empire Peacemaker"] = function () return {
         "Milspec Orion 9901 Core System",
         "Melendez Mammoth XL Engine",
         "S&K Superheavy Combat Plating",
      } end,
}

--[[
-- @brief Does Dvaered pilot equipping
--
--    @param p Pilot to equip
--]]
function equip( p )
   if diff.isApplied( "collective_dead" ) and not empire_outfits_collective then
      table.insert( empire_outfits, "Drone Fighter Bay" )
      empire_outfits_collective = true
   end

   local sname = p:ship():nameRaw()
   --if empire_skip[sname] then return end

   -- Choose parameters and make Empire-ish
   local params = equipopt.params.choose( p )
   -- Prefer to use the Empire utilities
   params.prefer["Hunting Combat AI"] = 100
   params.prefer["Photo-Voltaic Nanobot Coating"] = 100
   params.type_range["Bolt Weapon"] = { min = 1 }
   params.type_range["Launcher"] = { max = 2 }
   params.max_same_stru = 3
   params.bolt = 1.5
   params.min_energy_regen = 1.0 -- Empire loves energy
   params.max_mass = 0.95 + 0.1*rnd.rnd()
   -- Per ship tweaks
   local sp = empire_params[ sname ]
   if sp then
      params = mt.merge_tables_recursive( params, sp() )
   end

   -- See cores
   local cores = empire_cores[ sname ]()

   -- Try to equip
   equipopt.optimize.optimize( p, cores, empire_outfits, params )
end

