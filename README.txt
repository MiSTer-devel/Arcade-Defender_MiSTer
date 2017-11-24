---------------------------------------------------------------------------------
-- Arcade: Defender port to MiSTer by Sorgelig
-- 22 October 2017
-- 
---------------------------------------------------------------------------------
-- Defender by Dar (darfpga@aol.fr) (10 October 2017)
-- http://darfpga.blogspot.fr
--
---------------------------------------------------------------------------------
-- gen_ram.vhd
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- cpu09l - Version : 0128
-- Synthesizable 6809 instruction compatible VHDL CPU core
-- Copyright (C) 2003 - 2010 John Kent
---------------------------------------------------------------------------------
-- cpu68 - Version 9th Jan 2004 0.8
-- 6800/01 compatible CPU core 
-- GNU public license - December 2002 : John E. Kent
---------------------------------------------------------------------------------
-- 
-- 
-- Keyboard players inputs :
--
--   F3 : Add coin
--   F2 : Start 2 players
--   F1 : Start 1 player
--   SPACE            : Fire  
--   RIGHT/LEFT arrow : Thrust
--   UP    arrow : Move up 
--   DOWN  arrow : Move down
--   SHIFT       : Reverse ship direction
--   CTRL        : Smart bomb
--   W           : Hyperspace
--
-- Keyboard Service inputs :
--
--   A : advance
--   U : auto/up (!manual/down)
--   H : high score reset
--
-- Joystick support.
-- 
-- 
---------------------------------------------------------------------------------

                                *** Attention ***

ROM is not included. In order to use this arcade, you need to provide a correct ROM file.

1) Put bat and 7za.exe files from releases folder into the same folder on PC.

2) Execute bat file - it will show the name of zip file containing required files.

3) Find this zip file somewhere. You need to find the file exactly as required.
   Do not rename other zip files even if they also replresent the same game - they are not compatible!
   The name of zip is taken from M.A.M.E. project, so you can get more info about
   hashes and contained files there.

4) Put required zip into the same folder and execute the bat again.

5) If everything will go without errors or warnings, then you will get the rom file.

6) Place the rom file into root of SD card.
