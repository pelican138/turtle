------------- 
-- CONFIG: -- 
-------------
local config -- Declare first
local debug_write -- Declare debug_write first
local debug_print -- Declare debug_print first

----------------
-- DEBUGGING: --
----------------
-- Debug functions (defined first)
debug_write = function(txt, ...)
  if not config or not config.debug then return end
  io.write(string.format(txt, ...))
end

debug_print = function(txt, ...)
  debug_write(txt.."\n", ...)
end

-- Config table defined AFTER debug functions
----------------
-- CONFIG: --
----------------
local config = {
    sleep = {
        forRefuel = 0.5,
        afterEmptying = 400
    },
    crop = {
        block = "minecraft:potatoes",
        item  = "minecraft:potato",
        ripe  = 7
    },
    blocks = {
        forward   = "minecraft:white_concrete",
        turnRight = "minecraft:green_concrete",
        turnRightWithDelay = "minecraft:magenta_concrete",
        turnLeft  = "minecraft:blue_concrete",
        emptyInventory = "minecraft:hopper",
        refuelTurtle   = "minecraft:yellow_concrete",
        rednetRightTurn = "minecraft:pink_concrete"
    },
    debug = false,
    bypassRefuel = true -- Add this to enable refuel bypass when fuel > 75%
}

----------------
-- REDNET SETUP:
----------------
local USE_REDNET = false -- Assume no Rednet initially
local TURTLE_ID = 7782  -- Predefined Turtle ID

-- Crop Counter Configuration
local cropCount = 0
local countingEnabled = True -- Track if counting is enabled -- Crop counter

-- Initialize Rednet
if peripheral.find("modem") then
    rednet.open(peripheral.getName(peripheral.find("modem")))
    rednet.host("turtle_network", tostring(TURTLE_ID))
    debug_print("Rednet initialized with ID %d", TURTLE_ID)

    -- Connection Test with Ping-Pong
    local attempts = 2
    local timeout = 2

    for i = 1, attempts do
        rednet.broadcast("ping", "turtle_network")
        local id, message = rednet.receive("turtle_network", timeout)
        if message == "pong" then
            USE_REDNET = true
            debug_print("Rednet connection established.")
            break
        end
        debug_print("Rednet ping attempt %d failed.", i)
    end
else
    debug_print("No modem found, skipping Rednet.")
end

if not USE_REDNET then
    debug_print("Proceeding without Rednet connection.")
end

-- Function to update crop counter
local function updateCropCounter()
    if countingEnabled then
        cropCount = cropCount + 1
    end -- <-- Closing for 'if countingEnabled' block
    
    term.setTextColor(colors.red)
    debug_print("Crop count: %d", cropCount)
    term.setTextColor(colors.white)

    if cropCount >= 7 then
        if USE_REDNET then
            rednet.send(9, "WAIT_LONGER")
            debug_print("Sent WAIT_LONGER message to Turtle #9")
        end
        cropCount = 0 -- Reset counter
    end -- <-- Closing for 'if cropCount >= 45'
end -- <-- Closing for function





----------------
-- VARIABLES: --
----------------

--Crop counting
local cropCount = 0 -- Add crop counter

-- GPS Tracking Variables:
local posX, posY, posZ = gps.locate()
local direction = 0 -- 0 = North, 1 = East, 2 = South, 3 = West
local modemSide = "left" -- Change to the side where your modem is attached
local status = "Idle"

-- Function getting called the next step:
local BufferFunction = nil

-- Dictionary of block names and its effects on the turtle:
local BlockList = {}

----------------
-- FUNCTIONS: --
----------------

-- Initialize Rednet
local function initRednet()
    if not rednet.isOpen(modemSide) then
        rednet.open(modemSide)
    end
    debug_print("Rednet initialized on side: " .. modemSide)
end


-- Function to print debug information: (with and without newline)
local function debug_write(txt, ...)
    if not config.debug then return end
    io.write(string.format(txt, ...))
  end
  local function debug_print(txt, ...)
    debug_write(txt.."\n", ...)
  end
  

-- Print out current config at start:
local function printWelcomeMessage()
  -- Clear screen:
  term.clear()
  term.setCursorPos(1, 1)
  -- Print text:
  local text = {
      "Welcome to the farming program!",
      "Current config:",
      "  Crop: " .. config.crop.item,
      "  Idle & Refuel time: " .. config.sleep.afterEmptying .. "s and " .. config.sleep.forRefuel .. "s",
      "  Debug printout: " .. tostring(config.debug)
  }
  print(table.concat(text, "\n"))
  sleep(2)
end

-- Add blocks to check for to BlockList dictionary:
local function newBlock(blockName, blockFunction)
  local temp = {
      block = blockName,
      fn = blockFunction
  }
  BlockList[blockName] = blockFunction
  return temp
end

local function collectItems()
  while turtle.suckDown() do
      debug_print("Collected item from the ground!")
  end
end

--------------------
-- TURTLE BLOCKS: --
--------------------

-- Movement:
newBlock(config.blocks.forward, function(_)
  debug_print("Moving forwards...")
  -- Empty because move forward is called after every step.
end)
newBlock(config.blocks.turnRight, function(_)
  debug_print("Turning right...")
  turtle.turnRight()
end)
newBlock(config.blocks.turnLeft, function(_)
  debug_print("Turning left...")
  turtle.turnLeft()
end)

-- Inventory:
newBlock(config.blocks.emptyInventory, function(_)
  debug_print("Emptying inventory...")
  for i = 16, 1, -1 do
      turtle.select(i)
      turtle.dropDown()
  end
  debug_print(" > Going to sleep for %s seconds!", tostring(config.sleep.afterEmptying))
  for i = config.sleep.afterEmptying, 1, -1 do
      if i % 10 == 0 then
          debug_print("Sleeping... %d seconds remaining", i)
      end
      sleep(1)
      sleep(1)
  end
  debug_print(" > Done sleeping.")
end)

-- Refueling:
newBlock(config.blocks.refuelTurtle, function(_)
  -- Sleep to allow items to get input through a hopper:
  debug_print("Refueling, going to sleep for %s seconds.", config.sleep.forRefuel)
  sleep(config.sleep.forRefuel)

  -- Bypass refuel if enabled and fuel level is above 75%
if config.bypassRefuel and turtle.getFuelLevel() > (turtle.getFuelLimit() * 0.75) then
    debug_print("Bypassing refuel: Fuel level above 75%%.")
    return
end

  -- Cycle through inventory and refuel:
  BufferFunction = function()
      debug_print(" > Done sleeping, refueling...")
      for i = 16, 1, -1 do
          turtle.select(i)
          turtle.refuel()
      end
      debug_print(" > Finished refueling!")
  end
end)

-- Add a second block for right turn with a delay:
newBlock(config.blocks.turnRightWithDelay, function(_)
    turtle.turnRight()  
    debug_print("Turning right with delay...")

  -- Adding a sleep delay before turning
  debug_print("Sleeping for 3 seconds before resuming...")
  sleep(3)  -- Adjust the sleep duration as needed

  -- Now turn right
  
end)

newBlock("rednetRightTurn", function(_)
    debug_print("Turning right and sending Rednet message...")
  
    -- Turn right
    turtle.turnRight()
  
    -- Send Rednet message
    rednet.send(9, "GO")
  end)
  

-- Harvesting and Replanting:
local function attemptReplanting()
  local currentItem = turtle.getItemDetail()
  if currentItem ~= nil then
      -- Place potato from currently held item:
      if currentItem.name == config.crop.item then
          debug_print("Placing down crop!")
          turtle.placeDown()
          return
      end
  end

  -- Find potato in inventory and place it down: (more expensive on computation, please do not happen in praxis)
  debug_print("Locating crop to replant...")
  for i = 1, 16 do
      turtle.select(i)
      local newItem = turtle.getItemDetail()
      if newItem ~= nil then
          if newItem.name == config.crop.item then
              debug_print("Placing down crop!")
              turtle.placeDown()
              return
          end
      end
  end

  -- Failed to replant:
  debug_print("Could not locate crop in inventory to replant... carrying on.")
end
newBlock(config.crop.block, function(block)
  debug_write("Crop found... ")
  if block.state.age >= config.crop.ripe then
      debug_print("ready to harvest!")
      turtle.digDown()
      collectItems()
      attemptReplanting()

      -- Increment crop counter
      cropCount = cropCount + 1
      debug_print("[31mCrop count: %d[0m", cropCount)

      -- Send Rednet message if counter reaches 45
      if cropCount >= 7 then
          if USE_REDNET then
              rednet.send(9, "WAIT_LONGER")
              debug_print("Sent WAIT_LONGER message to Turtle #9")
          end
          cropCount = 0 -- Reset counter after sending
      end
  else
      debug_print("still growing...")
  end
end)

-----------
-- MAIN: --
-----------

local function main()
  -- Execute Buffer function from last step:
  if BufferFunction ~= nil then
      debug_print("Executing buffer function!")
      BufferFunction()
      BufferFunction = nil
  end

  -- Check for the current block underneath turtle:
  local isBlock, block = turtle.inspectDown()
  if isBlock and block ~= nil then
      -- Execute Block function:
      if BlockList[block.name] ~= nil then
          BlockList[block.name](block)
      end
  end

  -- Check if there is space in inventory before collecting items:
  local freeSlots = 0
  for i = 1, 16 do
      if turtle.getItemCount(i) == 0 then
          freeSlots = freeSlots + 1
      end
  end
  if freeSlots > 0 then
      collectItems()
  else
      debug_print("Inventory full, skipping item collection.")
  end

  -- Move forward:
  local hasFuel = turtle.getFuelLevel() > 0
  if not hasFuel then
      debug_print("Out of fuel! Unable to move forward. Sleeping for 30 seconds.")
      sleep(30)
      return -- Stop further processing if no fuel
  end

  local success = turtle.forward()
  if not success then
      -- Check for obstacles in front
      local isBlock, data = turtle.inspect()
      if isBlock then
          debug_print("Obstacle detected: " .. (data.name or "unknown"))
          -- Attempt to dig obstacle and retry
          debug_print("Attempting to dig obstacle...")
          if turtle.dig() then
              success = turtle.forward()
              if success then
                  debug_print("Moved forward after digging.")
              else
                  debug_print("Still unable to move forward after digging.")
              end
          else
              debug_print("Failed to dig the obstacle!")
          end
      else
          debug_print("No obstacle detected. Possible unknown issue.")
      end
  else
      debug_print("Moved forward successfully.")
      -- Update GPS position
      if direction == 0 then
          posZ = posZ - 1
      elseif direction == 1 then
          posX = posX + 1
      elseif direction == 2 then
          posZ = posZ + 1
      elseif direction == 3 then
          posX = posX - 1
      end
  end

end

printWelcomeMessage()
while true do
    main()
  end
