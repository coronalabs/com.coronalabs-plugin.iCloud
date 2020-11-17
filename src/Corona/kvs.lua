local composer = require( "composer" )
local widget = require( "widget" )
local iCloud = require "plugin.iCloud"
local json = require "json"

local scene = composer.newScene()

local text = nil

local function setText()
    text.text = tostring( iCloud.get("touches") )
end

local function listener( event )
	print( "KVS SYNC EVENT ", json.prettify( event ) )
    setText()
end

local function touched( event )
    local t = 1 + (iCloud.get("touches") or 0)
    iCloud.set("touches", t)
    iCloud.synchronize()
    setText()
end

local function onKey( event )
	if event.keyName == "buttonA" and event.phase == "up" then
		touched()
	end
end

function scene:create( event )

	local sceneGroup = self.view

	CreateBackButton(sceneGroup)


	text = display.newText( sceneGroup, "iCloud", display.contentCenterX, display.contentCenterY, nil, 20 )

	iCloud.setKVSListener( listener )
	iCloud.synchronize()
	setText()

end


function scene:show( event )
	
	local sceneGroup = self.view
	
	if ( event.phase == "will" ) then

	
	elseif ( event.phase == "did" ) then
		Runtime:addEventListener( "tap", touched )
		Runtime:addEventListener( "key", onKey )
	end
end

function scene:hide( event )

    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        Runtime:removeEventListener( "tap", touched )
        Runtime:removeEventListener( "key", onKey )
    elseif ( phase == "did" ) then
        
    end
end



scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )


return scene
