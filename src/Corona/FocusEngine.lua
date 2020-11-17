

local json = require "json"

local enabled = false

local FocusEngine = {}
local objects = {}
local focusedObject = 0
local rect = nil

function FocusEngine.setObjects( objs )
	if not enabled then 
		return
	end
	for i, obj in pairs(objs) do
		objects[i] = obj
		obj:setEnabled( false )
	end
end

local function createFocusedRect(obj)
	if rect then
		rect:removeSelf( )
	end

	local rectBorder = 4
	rect = display.newRect( obj.x, obj.y, obj.width+rectBorder*2, obj.height+rectBorder*2 )
	rect:setFillColor( 0,0,0,0 )
	rect.stroke = { 1, 0, 0.5 }
	rect.strokeWidth = rectBorder
end

local shiftedThisEvent = false

local function onTouch(event)
	if #objects < 1 then
		return
	end
	
	if not rect then
		focusedObject = 1
		createFocusedRect(objects[focusedObject])
	end

	if event.phase == "ended" then
		shiftedThisEvent = false
		rect.y = objects[focusedObject].y
	else
		if not shiftedThisEvent then
			local dy = (event.y - event.yStart)/display.contentCenterY
			rect.y = objects[focusedObject].y + dy*rect.height*0.3

			if math.abs(dy) > 0.5 then
				if dy > 0 and focusedObject < #objects then
					shiftedThisEvent = true
					focusedObject = focusedObject + 1
					createFocusedRect(objects[focusedObject])
				end
				if dy < 0 and focusedObject > 1 then
					shiftedThisEvent = true
					focusedObject = focusedObject - 1
					createFocusedRect(objects[focusedObject])
				end
			end
		end
	end

end


local resetAt0 = true
local function onAxis(event)
	if #objects < 1 or not event.axis or event.axis.type~='y' then
		return
	end
	
	if resetAt0 and event.normalizedValue ~= 0 then
		return
	end
	resetAt0 = false
	
	if not rect then
		focusedObject = 1
		createFocusedRect(objects[focusedObject])
	end

	local dy = event.normalizedValue
	rect.y = objects[focusedObject].y + dy*rect.height*0.3

	if math.abs(dy) > 0.5 then
		if dy > 0 and focusedObject < #objects then
			shiftedThisEvent = true
			focusedObject = focusedObject + 1
			createFocusedRect(objects[focusedObject])
		end
		if dy < 0 and focusedObject > 1 then
			shiftedThisEvent = true
			focusedObject = focusedObject - 1
			createFocusedRect(objects[focusedObject])
		end
		resetAt0 = true
	end

end


local function onTap( event )
	local obj = objects[focusedObject]
	if #objects < 1 or not obj or not obj._view._onEvent then
		return
	end
	obj._view._onEvent({phase="ended", target=obj})
end

local function onKey( event )
	if event.keyName == "buttonA" and event.phase == "up" then
		onTap()
	end
end

local initialized = false
function FocusEngine.initialize(composer)
	enabled = true
	if initialized then
		return
	end
	initialized = true


	if composer then
		local oldGoToScene = composer.gotoScene
		composer.gotoScene = function( ... )
			objects = {}
			if rect then
				focusedObject = 0
				rect:removeSelf( )
				rect = nil
			end

			oldGoToScene( ... )
		end
	end

	Runtime:addEventListener( "key", onKey )
	Runtime:addEventListener( "touch", onTouch )
	-- Runtime:addEventListener( "tap", onTap )
	Runtime:addEventListener( "axis", onAxis )
end


return FocusEngine
