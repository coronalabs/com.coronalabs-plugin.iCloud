local iCloud = require "plugin.iCloud"
local json = require "json"
local composer = require( "composer" )
local widget = require( "widget" )

local scene = composer.newScene()


local FocusEngine = require( "FocusEngine" )
local focusEngineObjects = {}



local function WriteTestRecord( )
	local recordData = {
		name  = {type="string", string="Basil S."},
		when  = {type="date", time=-1449201382},
		where = {type="location", latitude=37.453139, longitude=122.113451 },
		amount = {type="number", number=1987},
	}

	local record = iCloud.recordCreate{
		recordName = "Basil 3",
		type = "people",
		table = recordData,
	}
	if record then

		record:save{
			onComplete=function( event )
				print("New record saved?!")
				print(json.prettify(event))
				if event.record then
					print(json.prettify(event.record:table()))
				end
				timer.performWithDelay( 1, function (  )
					collectgarbage(  )
				end)
			end
		}
	end

end

local function TestRecordAccessebility( )
	iCloud.recordGetAccountStatus{
		onComplete = function( event )
			print("Account status!")
			print(json.prettify(event))
			print("---")
		end,
	}
end

local function DeleteTestRecord( )
	iCloud.recordDelete{
		onComplete = function( event )
			print("Record is deleted!")
			print(json.prettify(event))
			print("---")
		end,
		recordName = "Boris 2",
	}
end


local function FetchTestRecord( )
	iCloud.recordFetch{
		onComplete = function( event )
			print("Record is fetched!")
			print(json.prettify(event))
			if event.record then
				print("Record is: ", json.prettify(event.record:table()))
			else
				print("Record is nil")
			end
			print("---")
		end,
		recordName = "Basil 3",
	}
end


local function FetchAndSaveTestRecord( )
	iCloud.recordFetch{
		onComplete = function( event )
			print("Record is fetched!")
			print(json.prettify(event))
			print("---")
			local record = event.record
			if record then
				print("Here Is data We Got")
				print(json.prettify(record:table()))
				local num = record:get("amount").number
				print("Num is ", num)
				record:set("amount", num+1)
				record:save{
					onComplete=function( event )
						print("Record saved?!")
						print(json.prettify(event))
						timer.performWithDelay( 1, function (  )
							collectgarbage(  )
						end)
					end
				}
			end

		end,
		recordName = "Vlad 1",
	}
end


local function QueryRecords( )
	iCloud.recordQuery{
		onComplete = function( event )
			print("Records are queries!")
			print(json.prettify(event))
			if event.recordArray and #event.recordArray then
				print("Records are: ", json.prettify(event.recordArray[1]:table()))
			else
				print("Records is nil")
			end
			print("---")
		end,
		type="people",
		query="TRUEPREDICATE",
	}
end

local text = nil

local function FetchAndIncrement( event )
	if ( event and "ended" ~= event.phase ) then
		return
	end
	native.setKeyboardFocus( nil )

	text.text = "Fetching record"
	iCloud.recordFetch{
		onComplete = function( event )
			print("Tapper is fetched!")
			print(json.prettify(event))
			if event.isError and event.errorCode == 11 then
				text.text = event.error .. "\nAttempting to create new counter"
				print("Attempting to create new record")
				local record = iCloud.recordCreate{
					type="ClickerCounter",
					recordName="Common Tapper",
				}
				record:set("taps", {type="number", number=1})
				record:set("name", "Cloud Stored Text" )
				record:save{
					database="public",
					onComplete=function(event)
						print("Attempted to create tapper!")
						print(json.prettify(event))
						if not event.isError then
							text.text = tostring(event.record:get("taps").number)
						else
							text.text = event.error
						end
					end
				}
			elseif event.isError then
				text.text = event.error .. "errorCode " .. tostring(event.errorCode) .."\nTry tapping again..."
			else
				local record = event.record
				if record then
					print("Here Is data We Got")
					print(json.prettify(record:table()))
					local num = record:get("taps").number
					print("Num is ", num)
					text.text = "Received: " .. tostring(num)
					if record:get("name") then
						text.text = text.text .. '\n' .. record:get('name').string
					else
						text.text = text.text .. '\n' .. '<no message>'
					end
					
					record:set("taps", num+1)

					record:save{
						database="public",
						onComplete=function( event )
							print("Record saved?!")
							print(json.prettify(event))
							if not event.isError and event.record then
								text.text = "Saved: " .. record:get("taps").number
								if record:get("name") then
									text.text = text.text .. '\n' .. record:get('name').string
								else
									text.text = text.text .. '\n' .. '<no message>'
								end
							else
								text.text = "Error saving increment\n"..event.error
							end
							timer.performWithDelay( 1, function (  )
								collectgarbage(  )
							end)
						end
					}
				end
			end
		end,
		database = "public",
		recordName = "Common Tapper",
	}
end


local function FetchOnly( event )
	if ( event and "ended" ~= event.phase ) then
		return
	end
	native.setKeyboardFocus( nil )

	text.text = "Fetching record"
	iCloud.recordFetch{
		onComplete = function( event )
			print("Tapper is fetched!")
			print(json.prettify(event))
			if event.isError then
				text.text = event.error .. "errorCode " .. tostring(event.errorCode) .."\nTry tapping again..."
			else
				local record = event.record
				if record then
					print("Here Is data We Got")
					print(json.prettify(record:table()))
					local num = record:get("taps").number
					print("Num is ", num)
					text.text = "Received: " .. tostring(num)
					if record:get("name") then
						text.text = text.text .. '\n' .. record:get('name').string
					else
						text.text = text.text .. '\n' .. '<no message>'
					end
					print("metadata ", json.prettify(record:metadata()))
				end
			end
		end,
		database = "public",
		recordName = "Common Tapper",
	}
end

local function FetchFile( event )
	if ( event and "ended" ~= event.phase ) then
		return
	end
	native.setKeyboardFocus( nil )

	text.text = "Fetching File"
	iCloud.recordFetchFile{
		listener = function( event )
			print("File event")
			print(json.prettify(event))
			
		end,
		fieldKey = "asset",
		database = "public",
		recordName = "testFile123",
		pathForFile = system.pathForFile( "testFile123.png", system.DocumentsDirectory ),
	}
end

function scene:create( event )

	local sceneGroup = self.view

	CreateBackButton(sceneGroup)

	local btn = widget.newButton
	{
		x = display.contentCenterX,
		y = display.contentHeight*0.15,
		label = "Increment Counter",
		onEvent = FetchAndIncrement,
	}
	sceneGroup:insert(btn)
	focusEngineObjects[#focusEngineObjects+1] = btn

	btn = widget.newButton
	{
		parent = sceneGroup,
		x = display.contentCenterX,
		y = display.contentHeight*0.25,
		label = "Fetch Only",
		onEvent = FetchOnly,
	}
	sceneGroup:insert(btn)
	focusEngineObjects[#focusEngineObjects+1] = btn

	btn = widget.newButton
	{
		parent = sceneGroup,
		x = display.contentCenterX,
		y = display.contentHeight*0.35,
		label = "Get Image",
		onEvent = FetchFile,
	}
	sceneGroup:insert(btn)
	focusEngineObjects[#focusEngineObjects+1] = btn
	
	text = display.newText{
	    parent = sceneGroup,
	    text = "Tap button to participate.",     
	    x = display.contentCenterX,
	    y = display.contentCenterY,
	    width = display.contentWidth,
	    fontSize = 18,
	    align = "center"
	}
	
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
