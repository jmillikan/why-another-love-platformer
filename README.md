why-another-love-platformer
===========================

Basic parts of a vector platformer with an undocumented level editor, written as a lua & Love2D exercise.

Editor
======

Despite being an unplayable mess, the game has a working level editor that handles all current game features.

To invoke the editor, run e.g. "edit.sh platformer/levels/test.json" on your favorite unix-like system. Copy a level file to make a new level.

When first invoked, the editor will read a level on stdin and parse it. (This is handled by edit.sh.)

Within the editor, the user controls four bits of interface state, given on the info line in the top middle of the screen in the format "<state> (<x>,<y>) block <block> x <step>":
- A cursor, with screen position given in the info line. The cursor is used by multiple commands.
- A selected level block - Blocks -2, -1 and 0 are the playfield, end door and character start
- An "interface state" - this is relevant only for changing the step and relocating the cursor
- A "step" size, which is a number used by several different commands

The user edits the level using these four pieces of information in conjunction with a large number of one-character keyboard commands. To see all commands, you may need to inspect the dispatch table in level-editor/main.lua. Here are the basics:

- t: Set step - After pressing t, enter digits, then press enter. (Press escape to cancel.)
- h,j,k,l/left,down,up,right: Move cursor by "step"
- r: Use this then click anywhere to move the cursor to the pixel clicked
- n,p: Switch block that is being edited

- m: Move top left of current block to cursor. (For rotated blocks, this will be where the top-left would be with no rotation.)
- i: Add a new normal block at cursor
- u: Delete current block
- q/e: Rotate current block by "step" degrees
- a/d and s/w: Grow/shrink block vertically or horizontally by "step" pixels
- ".": Set the movement "period" of a block to "step" seconds. If the platform does not have a move endpoint, this sets it to the cursor
- ",": Set the movement endpoint of a block to the cursor

- z: Write level on stdout. If invoked through edit.sh, this will save back to the file.
- escape: Quit without writing - edit.sh will recognize this and not write anything.


