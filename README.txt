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
-- Mame Keys
--  1 : Start 1 Player
--  2 : Start 2 Player
-- 5,6: Add coin
--
-- Joystick support.
-- 
-- 
---------------------------------------------------------------------------------

                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip
