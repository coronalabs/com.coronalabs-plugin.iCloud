local composer = require( "composer" )
local widget = require( "widget" )
local scene = composer.newScene()

local FocusEngine = require( "FocusEngine" )
local focusEngineObjects = {}

local function handleButtonEvent( event )
	if ( "ended" ~= event.phase ) then
		return
	end
	composer.gotoScene( event.target.id ) 
end

local tvOSHomeButtonBinded = false
function CreateBackButton(sceneGroup)
	if system.getInfo( "platformName" ) == "tvOS" then
		if not tvOSHomeButtonBinded then
			tvOSHomeButtonBinded = true
			Runtime:addEventListener( "key", function( event )
				if event.keyName == "menu" and event.phase == "up" then
					if composer.getSceneName() == "mainMenu" then
						-- TO DO: minimize app.
						-- we're in App's root. Menu button tab should bring to springboard
					else
						composer.gotoScene( "mainMenu" )
					end
				end
			end )
		end
	else
		local btn = widget.newButton
		{
			x = display.contentCenterX,
			y = 20,
			id = "kvs",
			label = "<- back",
			onEvent = function( event ) 
				if ( "ended" ~= event.phase ) then
					return
				end
				composer.gotoScene( "mainMenu" )
			end
		}
		btn.y = btn.height*0.5
		sceneGroup:insert( btn )
	end
end


-- "scene:create()"
function scene:create( event )

	local sceneGroup = self.view


	local btn = widget.newButton
	{
		x = display.contentCenterX,
		y = display.contentHeight*0.25,
		id = "kvs",
		label = "Key-Value Store (KVS)",
		onEvent = handleButtonEvent
	}
	sceneGroup:insert( btn )
	focusEngineObjects[#focusEngineObjects+1] = btn

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = display.contentHeight*0.5,
		id = "Documents",
		label = "Documents",
		onEvent = handleButtonEvent
	}
	sceneGroup:insert( btn )
	focusEngineObjects[#focusEngineObjects+1] = btn

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = display.contentHeight*0.75,
		id = "CloudKit",
		label = "CloudKit",
		onEvent = handleButtonEvent
	}
	sceneGroup:insert( btn )
	focusEngineObjects[#focusEngineObjects+1] = btn

end

function scene:show( event )
	local sceneGroup = self.view	
	if ( event.phase == "will" ) then
		FocusEngine.setObjects(focusEngineObjects)
	elseif ( event.phase == "did" ) then
	end
end


scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )

return scene
