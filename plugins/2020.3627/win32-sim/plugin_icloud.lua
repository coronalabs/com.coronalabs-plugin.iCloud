local Library = require "CoronaLibrary"

-- Create library
local lib = Library:new{ name='plugin.iCloud', publisherId='com.coronalabs' }


local function showWarning()
	print( 'The iCloud plugin would not work in Simulator.' );
end

lib.setKVSListener = showWarning
lib.set = showWarning
lib.get = showWarning
lib.delete = showWarning
lib.identityToken = showWarning
lib.synchronize = showWarning
lib.table = showWarning
lib.docInit = showWarning
lib.docList = showWarning
lib.docWrite = showWarning
lib.docRead = showWarning
lib.docDelete = showWarning
lib.docCheck = showWarning
lib.docDownload = showWarning
lib.docEvict = showWarning
lib.docConflicts = showWarning
lib.docConflictData = showWarning
lib.docResolve = showWarning
lib.recordAccountStatus = showWarning
lib.recordCreate = showWarning
lib.recordFetch = showWarning
lib.recordFetchMultiple = showWarning
lib.recordQuery = showWarning
lib.recordDelete = showWarning
lib.recordCreateZone = showWarning
lib.recordFetchFile = showWarning

-------------------------------------------------------------------------------
-- END
-------------------------------------------------------------------------------

-- Return an instance
return lib
