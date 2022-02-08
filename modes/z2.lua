-- STOP! Are you about to edit this file?
-- If you change ANYTHING, please please PLEASE run the following script:
-- https://www.guidgenerator.com/online-guid-generator.aspx
-- and put in a new GUID in the "guid" field.

-- Author: Brian Williams with help from megmacattack
-- This file is available under Creative Commons CC0

local bit = require("bit")

local spec = {
	guid = "45abb033-e9ab-4a24-a5b7-b32215b787ae",
	format = "1.1",
	name = "Zelda II: The Adventure of Link",
	match = {"stringtest", addr=0xFFE0, value="??ZELDA2??"},
	
	-- This is not a perfect test. It returns to 3 or 0 during game over screens and at other times.
    -- There may be a better test, but mostly we just want to avoid spamming the server with all
    -- the item-taken states we watch getting set high which happens during initialization.
	-- running = {"test", addr = 0x736, gte = 0x4},
	sync = {		
		[0x0777] = {name="Attack Power" },
		[0x0778] = {name="Magic Power" },
		[0x0779] = {name="Life Power" },
	
		[0x077B] = {name="Shield magic" },
		[0x077C] = {name="Jump magic" },
		[0x077D] = {name="Life magic" },
		[0x077E] = {name="Fairy magic" },
		[0x077F] = {name="Fire magic" },
		[0x0780] = {name="Reflect magic" },
		[0x0781] = {name="Spell magic" },
		[0x0782] = {name="Thunder magic" },
		[0x0783] = {name="Magic Container" },
		[0x0784] = {name="Heart Container" },
		[0x0785] = {name="Candle" },
		[0x0786] = {name="Glove" },
		[0x0787] = {name="Raft" },
		[0x0788] = {name="Boots" },
		[0x0789] = {name="Flute" },
		[0x078A] = {name="Cross" },
		[0x078B] = {name="Hammer" },
		[0x078C] = {name="Magic Key" },
		
		[0x078d] = {name="Palace 1 Gem", verb="placed", kind="high"},
        [0x078e] = {name="Palace 2 Gem", verb="placed", kind="high"},
        [0x078f] = {name="Palace 3 Gem", verb="placed", kind="high"},
        [0x0790] = {name="Palace 4 Gem", verb="placed", kind="high"},
        [0x0791] = {name="Palace 5 Gem", verb="placed", kind="high"},
        [0x0792] = {name="Palace 6 Gem", verb="placed", kind="high"},
		
		--[0x0793] = {name="updated keys" },
		[0x0794] = {}, -- crystals remaining countdown
		[0x0796] = {nameBitmap={"","","","Upward Thrust","","Downward Thrust","",""}, kind="bitOr"},
		[0x0798] = {name="the Trophy" },
		[0x0799] = {name="the Mirror" },
		[0x079A] = {name="the note or medicine (sorry)" },
		[0x079B] = {name="some water" },
		[0x079C] = {name="a lost child" },
		[0x079D] = {}, -- enough jars for kasuto lady
	}
}

-- screen item status
-- Is this how the rando keeps track of items as well???
for i = 0x600, 0x6ff do
    spec.sync[i] = {kind="bitAnd", cond={"test", lte = 0xfe}} -- ignore initial setting high
end
		
--EXP to next level: 770 is high bits, 771 is low bits
--game write both to FF FF then writes 770 then 771 to final value
--watch 771 for FF->anything, send both 770 and 771 as final values
spec.sync[0x0771] = {
	kind=function(value, previousValue, receiving)
		if receiving then 
			local highbits = bit.rshift(value, 8)
			local lowbits = AND(value,0xff)
			memoryWrite(0x0770, highbits)
			return true, lowbits
		else 
			if value == 0xFF then
				return false, previousValue
			elseif value == previousValue then
			    return false, previousValue
			else
				local highbits = memoryRead(0x0770)
				local lowbits = value
				return true, OR(bit.lshift(highbits, 8), lowbits)
		    end
		end
	end
}

return spec
