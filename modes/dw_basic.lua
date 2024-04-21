-- STOP! Are you about to edit this file?
-- If you change ANYTHING, please please PLEASE run the following script:
-- https://www.guidgenerator.com/online-guid-generator.aspx
-- and put in a new GUID in the "guid" field.

-- Author: Brian Williams
-- This file is available under Creative Commons CC0

local bit = require("bit")

lastDroppedItem = 0
onchest = 0
items_to_skip = 0
still_running = true

function getItem(slotbyte, top)
  if top then
	return bit.rshift(slotbyte,4)
  end
  return bit.band(slotbyte,0x0F)
end

-- Returns 1 if you're in a place/situation where you may drop/add an item 
-- all in one "transaction"
function onChest()
  local tile = memoryRead(0x00E0)
  if tile == 0x0C then
    return 1
  end
  return 0
end

-- Returns table of {newItemInt, oldItemInt}
function changedItem(newitems, olditems, isTop)
  olditem = getItem(olditems, isTop)
  newitem = getItem(newitems, isTop)
  if olditem - newitem ~= 0 
  then -- if a change in this slot
    if olditem == 0
	then
	  return {newitem, 0}
	elseif newitem == 0 then
	  return {0, olditem}
	else
	  return {newitem, olditem}
	end
  end
  return {0, 0}
end

function changedItemMessage(newitems, olditems, isTop)
  items = {"Torch", "Fairy Water", "Wings", "Dragon's Scale", "Fairy Flute", "Fighter's Ring", "Erdrick's Token",
     "Gwaelin's Love", "Cursed Belt", "Silver Harp", "Death Necklace", "Stones of Sunlight", "Staff of Rain", "Rainbow Drop", "Herb"}
  changedItems = changedItem(newitems, olditems, isTop)
  olditem = changedItems[2]
  newitem = changedItems[1]
  if olditem - newitem ~= 0 
  then -- a change in this slot
    if (newitem == 0 and onchest == 1) then  -- dropped item on chest
	  lastDroppedItem = olditem
	  --return "Partner is dropping ... " .. items[olditem]
	  return nil
	elseif (newitem == 0) then -- dropped item not on chest
	  if (olditem == 7 or olditem == 12 or olditem == 13) then return nil end -- dont message traded items
	  return "Partner used " .. items[olditem]
	elseif (olditem == 0 and onchest == 1 and lastDroppedItem > 0) then  -- gained item on chest with recent dropped item
	  local updatetext = "Partner got " .. items[newitem] .. ", dropped " .. items[lastDroppedItem]
	  lastDroppedItem = 0
	  return updatetext
	elseif (olditem == 0) then -- gained item but not on chest OR didn't drop an item on a chest spot
	  lastDroppedItem = 0
	  return "Partner got " .. items[newitem]
	else
	  return "???? item change error ????"
	end
  end
end

function printChangedItemMessage(value, previousValue)
  text = changedItemMessage(value, previousValue, true)
  if text == nil 
  then
    text = changedItemMessage(value, previousValue, false)
  end
  if text == nil then
	return nil
  end
  message(text)
end

local spec = {
	guid = "45aed033-e9ab-3a25-a5b7-b75735c7876e",
	format = "1.1",
	name = "Dragon Warrior Randomizer",
	match = {"stringtest", addr=0xFFE0, value="DRAGON WARRIOR"},

	sync = {
		[0x00BA] = {}, --exp lower bits
		[0x00BB] = {}, --exp upper bits
        [0x00BC] = {}, --gold lower bits, no message since usually updates with exp
        [0x00BD] = {}, --gold upper bits
        [0x00BE] = {name="new gear"},
        [0x00BF] = {name="keys", kind="delta", verb="changed" },
       -- [0x00C0] = {name="Herbs", kind="delta", verb="changed" },
	},
	tick = function() if items_to_skip > 0 then items_to_skip = items_to_skip - 1 end return end
}

-- stop syncing once you defeated DL2 and are in the throne room
-- kill app before 3.0 stats start rolling
 spec.running =
  function(value, size) 
    if AND(0x04, memoryRead(0x00E4)) == 1 and 4 == memoryRead(0x0045) then
      still_running = false
      return false
    else 
      return still_running
    end
  end

-- Implements the DWR 3.0 sorting routine on the receiving side
function sortItems()
  items = {}
  items[1] = AND(memoryRead(0x00C1),0x0F)
  items[2] = AND(memoryRead(0x00C2),0x0F)
  items[3] = AND(memoryRead(0x00C3),0x0F)
  items[4] = AND(memoryRead(0x00C4),0x0F)
  items[5] = bit.rshift(AND(memoryRead(0x00C1),0xF0), 4)
  items[6] = bit.rshift(AND(memoryRead(0x00C2),0xF0), 4)
  items[7] = bit.rshift(AND(memoryRead(0x00C3),0xF0), 4)
  items[8] = bit.rshift(AND(memoryRead(0x00C4),0xF0), 4)
  table.sort(items, function(a, b) return a > b end)
  memoryWrite(0x00C1, OR(bit.lshift(items[2], 4), items[1]))
  memoryWrite(0x00C2, OR(bit.lshift(items[4], 4), items[3]))
  memoryWrite(0x00C3, OR(bit.lshift(items[6], 4), items[5]))
  memoryWrite(0x00C4, OR(bit.lshift(items[8], 4), items[7]))
end

-- syncing gwaelin state
spec.sync[0x00DF] = {
  kind=function(value, previousValue, receiving)
    prevGBits = AND(previousValue, 0x03)
	newGBits = AND(value, 0x03)
	if prevGBits == newGBits then return end
    if receiving then
	   prevNonGBits = AND(0xFC, previousValue)
	   if newGBits == 0 then message("Gwaelin lost!") end
	   if newGBits == 1 then message("Gwaelin picked up") end
	   --if newGBits == 2 then message("Gwaelin returned") end -- don't need, you get gwaelin's love as well
       return true, OR(prevNonGBits, newGBits) 
	else
	   return true, value
	end
  end
}

-- syncing DN, FR, bridge and charlock stairs
spec.sync[0x00CF] = {
  kind=function(value, previousValue, receiving)
    prevWatchedBits = AND(previousValue, 0x3C)
	newWatchedBits = AND(value, 0x3C)
	if prevWatchedBits == newWatchedBits then return end
    if receiving then
	   previousNotWatchedBits = AND(0xC3, previousValue)
	   updatedBits = bit.bxor(prevWatchedBits, newWatchedBits)
	   if updatedBits == 4 then message("Charlock stairs found") end
	   if updatedBits == 8 then message("Rainbow bridge built") end
	   if updatedBits == 16 then message("Dragon scale equipped") end
	   if updatedBits == 32 then message("Fighter's ring equipped") end
       return true, OR(previousNotWatchedBits, newWatchedBits) 
	else
	   return true, value
	end
  end
}

-- syncing defeated dl2 so both players can get credits
spec.sync[0x00E4] = {
  kind=function(value, previousValue, receiving)
    prevWatchedBits = AND(previousValue, 0x04)
	newWatchedBits = AND(value, 0x04)
	if prevWatchedBits == newWatchedBits then return end
    if receiving then
	   previousNotWatchedBits = AND(0xFB, previousValue)
	   updatedBits = bit.bxor(prevWatchedBits, newWatchedBits)
	   if updatedBits == 4 then message("Dragonlord Defeated!!!") end
       return true, OR(previousNotWatchedBits, newWatchedBits) 
	else
	   return true, value
	end
  end
}

-- syncing items in 3.0 with chest sorting
-- uses onChest to determine if you're standing on a tile
--    where both a drop+add can happen at once, to combine messages
--    not smart enough to know about gwaelin trade
--    drop trade is fine, I just mute messages about "using" the 3 story items
for i = 0x00C1, 0x00C4 do
spec.sync[i] = {
	kind=function(value, previousValue, receiving)
		if receiving then 
			onchest = bit.rshift(value, 8)
			local lowbits = AND(value,0xff)
			memoryWrite(i, lowbits)
			if lowbits > previousValue then sortItems() end -- only sort if adding items
			printChangedItemMessage(lowbits, previousValue)
			return false, lowbits -- don't let script sync, since we just wrote+sorted+messaged ourselves
		else 
			if value == previousValue then
			    return false, previousValue
			else
				local highbits = onChest()
				local lowbits = value
				if items_to_skip > 0 then
				  cache[i] = value -- gnarly, if you have a valid value but don't send, cache won't update
				  -- the above line ensures the cache is right, so previousValue is right on future calls
				  -- we just don't send sorting progress along the wire because we re-implement it receiving side
				  return false, 0
				end
				if value > previousValue then -- if we're adding an item, skip after to avoid sending sort changes
				   items_to_skip = 1
				end
				return true, OR(bit.lshift(highbits, 8), lowbits)
		    end
		end
	end
}
end

return spec
