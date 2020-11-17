local iCloud = require "plugin.iCloud"
local json = require "json"
local composer = require( "composer" )
local widget = require( "widget" )

local scene = composer.newScene()

local text 

local function ListFiles(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	json.prettify(iCloud.docList{
		onComplete = function(event)
			print(json.prettify(event));
			if event.files then
				text.text = "Files: " .. json.prettify(event.files)
			elseif event.isError then
				text.text = "List failed, error: " .. tostring(event.error)
			else
				text.text = "No files"
			end
		end
	})
end

local function WriteFile(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	iCloud.docWrite{
		filename = "test.txt",
		contents = "1",
		onComplete = function(event)
			print(json.prettify(event));
			if event.isError then
				text.text = "Write failed, error: " .. tostring(event.error)
			else
				text.text = "Wrote 1."
			end
		end
	}
end


local function ReadFile(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	iCloud.docRead{
		filename = "test.txt",
		onComplete = function(event)
			print(json.prettify(event));
			if event.isError then
				text.text = "Read failed, error: " .. tostring(event.error)
			else
				text.text = "Read file:" .. tostring(event.contents)
			end
		end
	}
end

local function ReadAndIncrementFile(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	iCloud.docRead{
		filename = "test.txt",
		onComplete = function(event)
			print(json.prettify(event));

			if event.isError then
				text.text = "Read failed, error: " .. tostring(event.error)
			else
				text.text = "Read file:" .. tostring(event.contents)
			end

			if not event.isError and event.contents then
					iCloud.docWrite{
						filename = "test.txt",
						contents = tostring( tonumber( event.contents ) + 1 ),
						onComplete = function(event)
							print(json.prettify(event));
								if event.isError then
									text.text = text.text .. "\nError incrementing: " .. tostring(event.error)
								else
									text.text = text.text .. "\nAnd incremented"
								end

						end
					}
			end
		end
	}
end

local function DeleteFile(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	iCloud.docDelete{
		filename = "test.txt",
		onComplete = function(event)
			print(json.prettify(event));
			if event.isError then
				text.text = "Delete failed, error: " .. tostring(event.error)
			else
				text.text = "File deleted"
			end
		end
	}
end

local function EvictFile(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	local evicted, err = iCloud.docEvict{
		filename = "test.txt",
	}

	print("Evict File results: ", evicted, err)
	if evicted then
		text.text = "Evicted"
	else
		text.text = "Eviciton error: " .. tostring(err)
	end
end

local function DocConflicts(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	local conflicts = iCloud.docConflicts{
		filename = "test.txt",
	}

	print("Conflicts: ", json.prettify(conflicts or {"<no conflicts>"}))
	text.text = "#Conflicts: " .. tostring(#(conflicts or {}))
end

local function DocResolve(event)
	if ( "ended" ~= event.phase ) then
		return
	end

	local resolved, err = iCloud.docResolve{
		filename = "test.txt",
	}

	print("Evict File results: ", resolved, err)
	if resolved then
		text.text = "Reslolved"
	else
		text.text = "Resolve error: " .. tostring(err)
	end
end

function scene:create( event )

	local sceneGroup = self.view
	CreateBackButton(sceneGroup)
	
	if system.getInfo( "platformName" ) == "tvOS" then
		display.newText( sceneGroup, "tvOS does not support Documents", display.contentCenterX, display.contentCenterY, nil, 20 )
		return
	end

	
	local btn = {y=20, height=25}
	
	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "List Files",
		onEvent = ListFiles,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Write 1",
		onEvent = WriteFile,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Read File",
		onEvent = ReadFile,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Read And Increment",
		onEvent = ReadAndIncrementFile,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Delete File",
		onEvent = DeleteFile,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Evict File",
		onEvent = EvictFile,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Conflicts",
		onEvent = DocConflicts,
	}
	sceneGroup:insert(btn)

	btn = widget.newButton
	{
		x = display.contentCenterX,
		y = btn.y+btn.height,
		height = btn.height,
		label = "Resolve",
		onEvent = DocResolve,
	}
	sceneGroup:insert(btn)

	text = display.newText{
	    parent = sceneGroup,
	    text = "Tap a button.",     
	    x = display.contentCenterX,
	    y = (btn.y+btn.height + display.contentHeight)*0.5,
	    width = display.contentWidth,
	    fontSize = 18,
	    align = "center"
	}

end



scene:addEventListener( "create", scene )


return scene
