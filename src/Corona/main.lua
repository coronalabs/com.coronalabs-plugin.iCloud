local composer = require( "composer" )

local FocusEngine = require "FocusEngine"

if system.getInfo( "platformName" ) == "tvOS" then
	FocusEngine.initialize(composer)
end

composer.gotoScene( "mainMenu" )
