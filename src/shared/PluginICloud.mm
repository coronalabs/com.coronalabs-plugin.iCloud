//
//  PluginICloud.mm
//  TemplateApp
//
//  Copyright (c) 2015 Corona Labs. All rights reserved.
//

#import "PluginICloud.h"

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#include "CoronaLibrary.h"
#include "CoronaRuntime.h"
#include "CoronaAssert.h"

#include "CoronaLuaObjCHelper.h"
#include "CoronaEvent.h"

#include "luna.h"

class PluginICloud;

@interface PluginICloudObserver : NSObject {
	PluginICloud *library;
}
- (instancetype)initWithLibrary:(PluginICloud*)lib;
-(void)kvsChangedWithNote:(NSNotification*)note;
@end


class PluginICloud
{
	public:
		typedef PluginICloud Self;

	public:
		static const char kName[];
		static const char kKVSEvent[];
		static const char kDocEvent[];
		static const char kRecordEvent[];

	protected:
		PluginICloud();
		~PluginICloud();

	public:
		bool Initialize( CoronaLuaRef listener, lua_State *L );

	public:
		CoronaLuaRef GetListener() const { return fListener; }
		lua_State* GetLuaState() const { return fL; }
	

	public:
		static int Open( lua_State *L );

	protected:
		static int Finalizer( lua_State *L );

	public:
		static Self *ToLibrary( lua_State *L );

	public:
		static int simulatorDummy( lua_State *L );
		static int cloudKitDummy( lua_State *L );

	
		static int setKVSListener( lua_State *L );
		static int setValue( lua_State *L );
		static int getValue( lua_State *L );
		static int deleteValue ( lua_State *L );
		static int identityToken( lua_State *L );
		static int synchronize( lua_State *L );
		static int tableRepresentation( lua_State *L );
	
		static int docInit( lua_State *L );
		static int docList( lua_State *L );
		static int docWrite( lua_State *L );
		static int docRead( lua_State *L );
		static int docDelete( lua_State *L );
		
		static int docCheck( lua_State *L );
		static int docDownload( lua_State *L );
		static int docEvict( lua_State *L );
		
		static int docConflicts( lua_State *L );
		static int docConflictData( lua_State *L );
		static int docResolve( lua_State *L );
	
		static int recordGetAccountStatus( lua_State* L );
		static int recordCreate( lua_State *L );
		static int recordFetch( lua_State *L );
		static int recordFetchMultiple( lua_State *L );
		static int recordQuery( lua_State *L );
		static int recordDelete( lua_State *L );
		static int recordCreateZone( lua_State *L );

	
	private:
		static bool InitFiles(NSString* containerId);
		static NSData* ReadFile( NSURL* fileUrl, NSError **error);
		static NSURL* GetURLForFile(NSString *fileName, NSString *containerId);
		static bool WriteFile( NSString *containerId, NSString *filename, NSData *contents, NSError **error );
		static bool DeleteFile( NSString *containerId, NSString *filename, NSError **error );
		static bool CheckFile( NSString *containerId, NSString *filename );
	
	private:
		static void PushMetadataResults(lua_State *L, NSMetadataQuery *query);
		static bool	GetParameters( lua_State *L, NSString **containerId, CoronaLuaRef* listener, NSString **filename=NULL, NSData **data=NULL, NSString **conflict = NULL);
		static int ReadAndPushFile(lua_State *L, NSURL *fileUrl);
		static void CreateDocumentEvent(lua_State *L, const char *type, bool success, NSError *err);
		static void CreateRecordEvent(lua_State *L, const char *type, bool success, NSError *err);
		static void PushErrorOrNil(lua_State *L, BOOL success, NSError *err); // if success is true, ignores error and pushes nil.
	
		static CKRecordZoneID *NewZoneID (lua_State *L, int index );
		static CKRecordID *NewRecordID( lua_State *L, int index );
		static void PushRecordID( lua_State *L, int index, CKRecordID *recId );
		static CKDatabase *GetDatabase( lua_State *L, int index );
		static CKContainer* GetContainer( lua_State *L, int index);

		static id GetRecordValue( lua_State *L, int index, bool allowArrays );
		static int PushRecord(lua_State *L, CKRecord *record);
		static int PushRecordValues(lua_State *L, CKRecord *record);
		static int PushRecordValue(lua_State *L, id v);
		static CoronaLuaRef GetRecordListener( lua_State *L, int index );


	private:
		class PluginCKRecord
		{
		public:
			PluginCKRecord(lua_State *L);
			void SetRecord( CKRecord *_record )
			{
				[record release];
				record = [_record retain];
			}
			
			CKRecord* GetRecord() const
			{
				return record;
			}
			
			int save(lua_State *L);
			
			int get(lua_State *L);
			int set(lua_State *L);
			int tableRepresentation(lua_State *L);
			int metadata(lua_State *L);
			
			~PluginCKRecord();
			
			static const char className[];
			static const Luna<PluginCKRecord>::RegType Register[];
			
		private:
			CKRecord *record;
		};
	
	private:
		lua_State *fL;
		CoronaLuaRef fListener;
		PluginICloudObserver *fObserver;
	
	
};

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
const char PluginICloud::kName[] = "plugin.iCloud";

// This corresponds to the event name, e.g. [Lua] event.name
const char PluginICloud::kKVSEvent[] = "iCloudKVSEvent";
const char PluginICloud::kDocEvent[] = "iCloudDocEvent";
const char PluginICloud::kRecordEvent[] = "iCloudRecordEvent";

PluginICloud::PluginICloud()
: fListener( NULL )
, fL( NULL )
, fObserver( nil )
{
}

PluginICloud::~PluginICloud()
{
	if (fObserver)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:fObserver];
		[fObserver release];
	}
}

int
PluginICloud::simulatorDummy(lua_State *L)
{
	lua_pushnil( L );
	return 1;
}


int
PluginICloud::cloudKitDummy(lua_State *L)
{
	lua_pushnil( L );
	return 1;
}


int
PluginICloud::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	// Functions in library
	
	bool noCloudKit = ([CKContainer class] == nil);
	
	luaL_Reg kVTable[] =
	{
		{ "setKVSListener", setKVSListener },
		{ "set", setValue },
		{ "get", getValue },
		{ "delete", deleteValue },
		{ "identityToken", identityToken },
		{ "synchronize", synchronize },
		{ "table", tableRepresentation },

		{ "docInit", docInit },
		{ "docList", docList },
		{ "docWrite", docWrite },
		{ "docRead", docRead },
		{ "docDelete", docDelete },
		{ "docCheck", docCheck },
		{ "docDownload", docDownload },
		{ "docEvict", docEvict },
		
		{ "docConflicts", docConflicts },
		{ "docConflictData", docConflictData },
		{ "docResolve", docResolve },
		
		{ "recordAccountStatus", recordGetAccountStatus },
		{ "recordCreate", noCloudKit?cloudKitDummy:recordCreate },
		{ "recordFetch", noCloudKit?cloudKitDummy:recordFetch },
		{ "recordFetchMultiple", noCloudKit?cloudKitDummy:recordFetchMultiple },
		{ "recordQuery", noCloudKit?cloudKitDummy:recordQuery },
		{ "recordDelete", noCloudKit?cloudKitDummy:recordDelete },
		{ "recordCreateZone", noCloudKit?cloudKitDummy:recordCreateZone },

		{ NULL, NULL }
	};
	
#ifdef TARGET_OS_MAC
	bool simulator = false;
	lua_getglobal( L, "system" );
	if (lua_istable( L, -1 ))
	{
		lua_getfield( L, -1, "getInfo" );
		if(lua_isfunction( L, -1 ))
		{
			lua_pushstring( L, "environment" );
			if( CoronaLuaDoCall( L, 1, 1 ) == 0 )
			{
				if ( lua_type( L, -1) == LUA_TSTRING )
				{
					simulator = (strcmp("simulator", lua_tostring( L, -1)) == 0);
				}
			}
			lua_pop( L, 1 ); //remove result or error
		}
		else
		{
			lua_pop( L, 1 );
		}
	}
	lua_pop( L, 1);
	if (simulator)
	{
		int i = 0;
		do
		{
			kVTable[i].func = simulatorDummy;
		} while ( kVTable[++i].name );
		CoronaLuaWarning( L, "iCloud plugin would not work in Corona Simulator." );
	}
	
#endif
	
	if(!noCloudKit)
	{
		Luna<PluginCKRecord>::Register( L, false );
	}
	

	// Set library as upvalue for each library function
	Self *library = new Self;
	CoronaLuaPushUserdata( L, library, kMetatableName );
	
	luaL_openlib( L, kName, kVTable, 1 ); // leave "library" on top of stack
	
	return 1;
}


bool
PluginICloud::Initialize( CoronaLuaRef listener, lua_State *L )
{
	// Can only initialize listener once
	bool res = ( NULL == fListener );

	if ( res )
	{
		fListener = listener;
		
		if ( nil == fObserver )
		{
			fObserver = [[PluginICloudObserver alloc] initWithLibrary:this];
			fL = L;
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			
			[nc addObserver:fObserver
				   selector:@selector(kvsChangedWithNote:)
					   name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
					 object:nil];
		}
	}

	return res;
}

int
PluginICloud::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );

	CoronaLuaDeleteRef( L, library->GetListener() );

	delete library;

	return 0;
}

PluginICloud *
PluginICloud::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
	return library;
}



@implementation PluginICloudObserver

- (instancetype)initWithLibrary:(PluginICloud*)lib
{
	self = [super init];
	if (self) {
		library = lib;
	}
	return self;
}

-(void)kvsChangedWithNote:(NSNotification *)note
{
	NSDictionary *userInfo = [note userInfo];
	NSNumber *changeReason = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangeReasonKey];
	if (!userInfo)
	{
		return;
	}
	long reason = [changeReason integerValue];
	
	lua_State *L = library->GetLuaState();
	CoronaLuaRef listener = library->GetListener();
	
	CoronaLuaNewEvent( L, PluginICloud::kKVSEvent );
	
	const char *type;
	bool error = false;
	switch (reason) {
		case NSUbiquitousKeyValueStoreServerChange:
			type = "serverChange";
			break;
		case NSUbiquitousKeyValueStoreInitialSyncChange:
			type = "initialSync";
			break;
		case NSUbiquitousKeyValueStoreQuotaViolationChange:
			type = "quotaViolation";
			error = true;
			break;
		case NSUbiquitousKeyValueStoreAccountChange:
			type = "accountChange";
			error = true;
			break;
		default:
			type = "unknown";
			break;
	}
	
	lua_pushstring( L, type);
	lua_setfield( L, -2, CoronaEventTypeKey() );
	
	lua_pushboolean( L, error );
	lua_setfield( L, -2, CoronaEventIsErrorKey() );
	
	NSArray *changedKeys = [userInfo objectForKey:NSUbiquitousKeyValueStoreChangedKeysKey];
	if ( CoronaLuaPushValue( L, changedKeys ) )
	{
		lua_setfield( L, -2, "keys" );
	}
	
	// Dispatch event to library's listener
	CoronaLuaDispatchEvent( L, listener, 0 );
}

@end


#pragma mark iCloud KVS

int
PluginICloud::setKVSListener( lua_State *L )
{
	int listenerIndex = 1;
	
	Self *library = ToLibrary( L );
	
	if (library->GetListener())
	{
		CoronaLuaDeleteRef( L, library->GetListener());
	}

	CoronaLuaRef listener = NULL;
	if ( CoronaLuaIsListener( L, listenerIndex, kKVSEvent ) )
	{
		listener = CoronaLuaNewRef( L, listenerIndex );
	}
	library->Initialize( listener, L );

	return 0;
}

int
PluginICloud::setValue( lua_State *L )
{
	int result = 0;
	int index = 1;

	if( lua_type(L, index) == LUA_TSTRING )
	{
		NSString *key = [NSString stringWithUTF8String:lua_tostring( L, index )];
		index++;
		
		id value = nil;
		switch ( lua_type(L, index) )
		{
			case LUA_TSTRING:
				value = [NSString stringWithUTF8String:lua_tostring( L, index )];
				break;
			case LUA_TNUMBER:
				value = [NSNumber numberWithDouble:lua_tonumber( L, index )];
				break;
			case LUA_TTABLE:
				value = CoronaLuaCreateDictionary( L, index );
				break;
			default:
				CoronaLuaWarning( L, "iCloud.set() - second parameter (value) must be a number, a string or table with string field names" );
				break;
		}
		
		if(value)
		{
			[[NSUbiquitousKeyValueStore defaultStore] setObject:value forKey:key];
		}
	}
	else
	{
		CoronaLuaWarning( L, "iCloud.set() - first parameter (key) must be a string" );
	}
	
	return result;
}


int
PluginICloud::getValue( lua_State *L )
{
	int result = 0;
	int index = 1;
	
	if ( lua_type(L, index)  == LUA_TSTRING )
	{
		NSString *key = [NSString stringWithUTF8String:lua_tostring( L, index )];
		id value = [[NSUbiquitousKeyValueStore defaultStore] objectForKey:key];
		if ( !CoronaLuaPushValue( L, value) )
		{
			lua_pushnil( L );
		}
		result = 1;
	}
	else
	{
		CoronaLuaWarning( L, "iCloud.get() - first parameter (key) must be a string" );
	}
	
	return result;
}


int
PluginICloud::deleteValue( lua_State *L )
{
	int result = 0;
	int index = 1;
	
	if ( lua_type(L, index) == LUA_TSTRING )
	{
		NSString *key = [NSString stringWithUTF8String:lua_tostring( L, index )];
		[[NSUbiquitousKeyValueStore defaultStore] removeObjectForKey:key];
	}
	else
	{
		CoronaLuaWarning( L, "iCloud.delete() - first parameter (key) must be a string" );
	}
	
	return result;
}


int
PluginICloud::identityToken( lua_State *L )
{
	int result = 1;
	
	id token = [[NSFileManager defaultManager] ubiquityIdentityToken];
	if (token)
	{
		if ( [token respondsToSelector:@selector(base64Encoding)] )
		{
			lua_pushstring( L, [[token performSelector:@selector(base64Encoding)] UTF8String]);
		}
		else
		{
			NSData *tokenData = [NSKeyedArchiver archivedDataWithRootObject:token];
			lua_pushstring( L, [[tokenData base64EncodedStringWithOptions:0] UTF8String]);
		}
	}
	else
	{
		lua_pushnil( L );
	}
	
	return result;
}

int
PluginICloud::synchronize( lua_State *L )
{
	BOOL res = [[NSUbiquitousKeyValueStore defaultStore] synchronize];
	lua_pushboolean( L, res );
	return 1;
}

int
PluginICloud::tableRepresentation( lua_State *L )
{
	int result = 1;
	NSDictionary* d = [[NSUbiquitousKeyValueStore defaultStore] dictionaryRepresentation];
	if( !CoronaLuaPushValue( L, d ) )
	{
		lua_pushnil( L );
	}
	return result;
}

#pragma mark iCloud Documents Logic

bool
PluginICloud::InitFiles(NSString* containerId)
{
	NSURL* baseUrl = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:containerId];
	return (nil != baseUrl);
}


NSURL *
PluginICloud::GetURLForFile(NSString *fileName, NSString *containerId)
{
	if ( ![fileName length] )
	{
		return nil;
	}
	
	NSURL* baseUrl = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:containerId];
	if ( nil == baseUrl)
	{
		return nil;
	}
	NSURL *folderUrl = [baseUrl URLByAppendingPathComponent:@"Documents" isDirectory:YES];
	NSURL *fileUrl = [folderUrl URLByAppendingPathComponent:fileName];
	
	return fileUrl;
}


NSData*
PluginICloud::ReadFile( NSURL* fileUrl, NSError **error)
{
	__block NSError *err = nil;
	__block NSData *contents = nil;
	if (fileUrl)
	{
		NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fc coordinateReadingItemAtURL:fileUrl
							   options:0
								 error:&err
							byAccessor:^(NSURL * _Nonnull newURL) {
								contents = [NSData dataWithContentsOfURL:newURL options:0 error:&err];
							}];
		[fc release];
	}
	*error = err;
	return contents;
}


bool
PluginICloud::WriteFile( NSString *containerId, NSString *filename, NSData *contents, NSError **error )
{
	NSURL *fileUrl = GetURLForFile(filename, containerId);
	
	__block NSError *err = nil;
	__block BOOL res = NO;
	
	if (contents && fileUrl)
	{
		NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fc coordinateWritingItemAtURL:fileUrl
							   options:0
								 error:&err
							byAccessor:^(NSURL * _Nonnull newURL) {
								res = [contents writeToURL:newURL options:NSDataWritingAtomic error:&err];
							}];
		[fc release];
	}
	
	*error = err;
	return res;
}

bool
PluginICloud::DeleteFile( NSString *containerId, NSString *filename, NSError **error )
{
	NSURL *fileUrl = GetURLForFile(filename, containerId);
	
	__block NSError *err = nil;
	__block BOOL res = NO;
	
	if (fileUrl)
	{
		NSFileCoordinator *fc = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[fc coordinateWritingItemAtURL:fileUrl
							   options:NSFileCoordinatorWritingForDeleting
								 error:&err
							byAccessor:^(NSURL * _Nonnull newURL) {
								res = [[NSFileManager defaultManager] removeItemAtURL:fileUrl error:&err];
							}];
		[fc release];
	}
	*error = err;
	return res;
}

#pragma mark iCloud Documents Parameter Parsing

bool
PluginICloud::GetParameters( lua_State *L, NSString **containerId, CoronaLuaRef* listener, NSString **filename, NSData **contents, NSString **conflict)
{
	int index = 1;
	*containerId = nil;
	*listener = NULL;
	if( lua_istable( L, 1) )
	{
		lua_getfield( L, index, "containerId");
		if( lua_type( L, -1) == LUA_TSTRING )
		{
			*containerId = [NSString stringWithUTF8String:lua_tostring( L, -1)];
		}
		lua_pop( L, 1 );
		
		lua_getfield( L, index, "onComplete");
		if( CoronaLuaIsListener( L, -1, PluginICloud::kDocEvent) )
		{
			*listener = CoronaLuaNewRef( L, -1 );
		}
		lua_pop( L, 1 );
		
		if (filename)
		{
			lua_getfield( L, index, "filename");
			if( lua_type( L, -1) == LUA_TSTRING )
			{
				*filename = [NSString stringWithUTF8String:lua_tostring( L, -1)];
			}
			lua_pop( L, 1 );
		}
		
		if (conflict)
		{
			lua_getfield( L, index, "conflict");
			if( lua_type( L, -1) == LUA_TSTRING )
			{
				*conflict = [NSString stringWithUTF8String:lua_tostring( L, -1)];
			}
			lua_pop( L, 1 );
		}
		
		if (contents)
		{
			lua_getfield( L, index, "contents");
			if( lua_type( L, -1) == LUA_TSTRING )
			{
				size_t len=0;
				void *data = (void *)lua_tolstring( L, -1, &len );
				*contents = [NSData dataWithBytes:data length:len];
				index++;
			}
			lua_pop( L, 1 );
		}
	}
	else
	{
		if (filename)
		{
			if( lua_type( L, index ) == LUA_TSTRING )
			{
				NSString *firstParam = [NSString stringWithUTF8String:lua_tostring( L, index)];
				if ([firstParam length] == 0)
				{
					firstParam = nil;
				}
				if (filename)
				{
					*filename = firstParam;
				}
				if (conflict)
				{
					*conflict = firstParam;
				}
				index++;
			}
		}
	}
	return ( !filename || *filename) && ( !contents || *contents) && ( !conflict || *conflict);
}

void
PluginICloud::PushErrorOrNil(lua_State *L, BOOL test, NSError *err)
{
	if (test)
	{
		lua_pushnil( L );
	}
	else
	{
		NSString *errDescription = [err localizedFailureReason] ?: [err localizedDescription] ?: [err description];
		if (errDescription)
		{
			lua_pushstring( L, [errDescription UTF8String] );
		}
		else
		{
			lua_pushnil( L );
		}
	}
}

void
PluginICloud::CreateDocumentEvent(lua_State *L, const char *type, bool success, NSError *err)
{
	CoronaLuaNewEvent( L, kDocEvent );
	
	lua_pushstring( L, type );
	lua_setfield( L, -2, CoronaEventTypeKey());
	
	lua_pushboolean( L, !success );
	lua_setfield( L, -2, CoronaEventIsErrorKey());
	
	if (err)
	{
		lua_pushnumber( L, err.code );
		lua_setfield( L, -2, "errorCode" );
		
		PushErrorOrNil(L, success, err);
		lua_setfield( L, -2, "error");
	}
	
}

int
PluginICloud::docInit( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	GetParameters(L, &containerId, &listener);
	
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docInit() - onComplete parameter is missing or invalid" );
		return 0;
	}
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		bool res = InitFiles(containerId);
		dispatch_async(dispatch_get_main_queue(), ^(void){
			CreateDocumentEvent(L, "docInit", res, nil);
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		});
	});
	return 0;
}

void
PluginICloud::PushMetadataResults(lua_State *L, NSMetadataQuery *query)
{
	lua_createtable( L, (int)query.resultCount, 0);
	for(int i = 0;i < query.resultCount;i++)
	{
		NSMetadataItem *md = [query resultAtIndex:i];
		NSString *fileName = [md valueForAttribute:NSMetadataItemFSNameKey];
		lua_pushstring( L, [fileName UTF8String]);
		lua_rawseti( L, -2, i+1 );
	}

}

int
PluginICloud::docList( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	GetParameters(L, &containerId, &listener);
	
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docList() - onComplete parameter is missing or invalid" );
		return 0;
	}

	NSURL* baseUrl = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:containerId];
	if (!baseUrl)
		return 0;
	
	__block NSMetadataQuery* query = [[NSMetadataQuery alloc] init];
	__block id obs = nil;
	
	
	query.searchScopes = @[NSMetadataQueryUbiquitousDocumentsScope];
	query.predicate = [NSPredicate predicateWithValue:YES];
	[query disableUpdates];
	
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	obs = [nc addObserverForName:NSMetadataQueryDidFinishGatheringNotification
						  object:query
						   queue:nil
					  usingBlock:^(NSNotification *note) {
						  
						  CreateDocumentEvent( L, "docList", true, nil );
						  PushMetadataResults(L, query);
						  lua_setfield( L, -2, "files" );
						  CoronaLuaDispatchEvent( L, listener, 0);
						  CoronaLuaDeleteRef( L, listener );
						  
						  [[NSNotificationCenter defaultCenter] removeObserver:obs];
						  [query release];
						 }];
	
	[query startQuery];
	return 0;
}



int
PluginICloud::ReadAndPushFile(lua_State *L, NSURL *fileUrl)
{
	NSError *err = nil;
	NSData *contents = ReadFile(fileUrl, &err);
	
	// first push contents of the file
	if (contents)
	{
		lua_pushlstring( L, (const char*)contents.bytes, contents.length);
	}else
	{
		lua_pushnil( L );
	}
	
	PushErrorOrNil(L, nil != contents, err);
	
	return 2;
}



int
PluginICloud::docRead( lua_State *L )
{
	
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docRead() - filename parameter is missing or empty" );
		return 0;
	}
	
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docRead() - onComplete parameter is missing or invalid" );
		return 0;
	}

	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSURL *fileUrl = GetURLForFile(filename, containerId);
		NSError *err = nil;
		NSData *contents = ReadFile(fileUrl, &err);
		dispatch_async(dispatch_get_main_queue(), ^(void){
			CreateDocumentEvent(L, "docRead", nil != contents && err==nil, err);
			
			if (contents)
			{
				lua_pushlstring( L, (const char*)contents.bytes, contents.length);
				lua_setfield( L, -2, "contents" );
			}
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		});
	});
	return 0;
}


int
PluginICloud::docWrite( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	NSData *contents = nil;
	if ( !GetParameters(L, &containerId, &listener, &filename, &contents) )
	{
		if(!filename)
		{
			CoronaLuaWarning( L, "iCloud.docWrite() - filename parameter is missing or empty" );
		}
		if(!contents)
		{
			CoronaLuaWarning( L, "iCloud.docWrite() - contents parameter is missing" );
		}
		return 0;
	}
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSError *err;
		bool res = WriteFile(containerId, filename, contents, &err);
		if (listener)
		{
			dispatch_async(dispatch_get_main_queue(), ^(void){
				CreateDocumentEvent( L, "docWrite", res, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			});
		}
	});

	return 0;
}

int
PluginICloud::docDelete( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docDelete() - filename parameter is missing or empty" );
		return 0;
	}

	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSError *err;
		bool res = DeleteFile(containerId, filename, &err);
		if (listener)
		{
			dispatch_async(dispatch_get_main_queue(), ^(void){
				CreateDocumentEvent( L, "docDelete", res, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			});
		}
	});
	return 0;
	
}

bool
PluginICloud::CheckFile(NSString *containerId, NSString *filename)
{
	NSURL *fileUrl = GetURLForFile(filename, containerId);
	
	BOOL res = NO;
	if (fileUrl)
	{
		res = [[NSFileManager defaultManager] isUbiquitousItemAtURL:fileUrl];
	}
	return res;
}

int
PluginICloud::docCheck( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docCheck() - filename parameter is missing or empty" );
		return 0;
	}
	
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docCheck() - onComplete parameter is missing or empty" );
		return 0;
	}

	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		bool res = CheckFile(containerId, filename);
		dispatch_async(dispatch_get_main_queue(), ^(void){
			CreateDocumentEvent(L, "docCheck", res, nil);
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		});
	});
	return 0;
}


int
PluginICloud::docDownload( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docDownload() - filename parameter is missing or empty" );
		return 0;
	}
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSURL *fileUrl = GetURLForFile(filename, containerId);
		NSError *err = nil;
		bool res = NO;
		if (fileUrl)
		{
			res = [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:fileUrl error:&err];
		}
		if (listener)
		{
			dispatch_async(dispatch_get_main_queue(), ^(void){
				CreateDocumentEvent(L, "docDownload", res, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			});
		}
	});
	return 0;
}


int
PluginICloud::docEvict( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docEvict() - filename parameter is missing or empty" );
		return 0;
	}
	
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSURL *fileUrl = GetURLForFile(filename, containerId);
		
		NSError *err = nil;
		BOOL res = NO;
		if (fileUrl)
		{
			res = [[NSFileManager defaultManager] evictUbiquitousItemAtURL:fileUrl error:&err];
		}
		if (listener)
		{
			dispatch_async(dispatch_get_main_queue(), ^(void){
				CreateDocumentEvent(L, "docEvict", res, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			});
		}
	});
	return 0;
}


int
PluginICloud::docConflicts( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docConflicts() - filename parameter is missing or empty" );
		return 0;
	}

	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docConflicts() - onComplete parameter is missing or empty" );
		return 0;
	}

	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSURL *fileUrl = GetURLForFile(filename, containerId);
		
		NSArray<NSFileVersion *> *versions = nil;
		if(fileUrl)
		{
			versions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileUrl];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^(void){
			CreateDocumentEvent(L, "docConflicts", fileUrl!=nil, nil);
			
			if ([versions count])
			{
				lua_createtable( L, (int)versions.count, 0);
				int i = 1;
				for (NSFileVersion *v in versions)
				{
					lua_createtable( L, 0, 3);
					
					lua_pushstring( L, [v.localizedNameOfSavingComputer UTF8String] );
					lua_setfield( L, -2, "origin" );
					
					lua_pushnumber( L, [v.modificationDate timeIntervalSince1970] );
					lua_setfield( L, -2, "time" );
					
					lua_pushstring( L, [v.URL.absoluteString UTF8String] );
					lua_setfield( L, -2, "dataHandle" );
					
					lua_rawseti( L, -2, i++ );
				}
			}
			else
			{
				lua_pushnil( L );
			}
			lua_setfield( L, -2, "conflicts" );
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		});
	});
	
	return 0;
}


int
PluginICloud::docConflictData( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *conflict = nil;
	if ( !GetParameters(L, &containerId, &listener, NULL, NULL, &conflict) )
	{
		CoronaLuaWarning( L, "iCloud.docConflictData() - conflict parameter is missing or empty" );
		return 0;
	}
	
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.docConflictData() - onComplete parameter is missing or empty" );
	}
	
	NSURL *fileUrl = nil;
	if (conflict)
	{
		fileUrl = [NSURL URLWithString:conflict];
	}
	
	if (!fileUrl)
	{
		CoronaLuaWarning( L, "iCloud.docConflictData() - invalid parameter. This function only accepts a 'dataHandle' field from iCloud.conflictsForFile()");
		return 0;
	}

	

	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSError *err = nil;
		NSData *contents = ReadFile(fileUrl, &err);
		dispatch_async(dispatch_get_main_queue(), ^(void){
			CreateDocumentEvent(L, "docConflictData", nil != contents && err==nil, err);
			
			if (contents)
			{
				lua_pushlstring( L, (const char*)contents.bytes, contents.length);
				lua_setfield( L, -2, "contents" );
			}
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
			
		});
	});
	return 0;
}


int
PluginICloud::docResolve( lua_State *L )
{
	NSString *containerId;
	CoronaLuaRef listener;
	NSString *filename = nil;
	if( !GetParameters(L, &containerId, &listener, &filename) )
	{
		CoronaLuaWarning( L, "iCloud.docResolve() - filename parameter is missing or empty" );
		return 0;
	}
	
	dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
		NSURL *fileUrl = GetURLForFile(filename, containerId);
		
		NSError *err = nil;
		BOOL res = NO;
		if(fileUrl)
		{
			NSArray<NSFileVersion *> *versions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileUrl];
			for (NSFileVersion *v in versions)
			{
				[v setResolved:YES];
			}
			res = [NSFileVersion removeOtherVersionsOfItemAtURL:fileUrl error:&err];
		}
		
		if (listener)
		{
			dispatch_async(dispatch_get_main_queue(), ^(void){
				CreateDocumentEvent(L, "docResolve", res, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			});
		}
	});
	return 0;
}



#pragma mark CloudKit

const char PluginICloud::PluginCKRecord::className[] = "CloudKitRecord";
const Luna<PluginICloud::PluginCKRecord>::RegType PluginICloud::PluginCKRecord::Register[] = {
	{ "save", &PluginICloud::PluginCKRecord::save },
	{ "get", &PluginICloud::PluginCKRecord::get },
	{ "set", &PluginICloud::PluginCKRecord::set },
	{ "table", &PluginICloud::PluginCKRecord::tableRepresentation },
	{ "metadata", &PluginICloud::PluginCKRecord::metadata },
	{ 0 }
};

PluginICloud::PluginCKRecord::PluginCKRecord( lua_State *L )
{
	record = nil;
}

PluginICloud::PluginCKRecord::~PluginCKRecord()
{
	[record release];
}

int
PluginICloud::PluginCKRecord::save(lua_State *L)
{
	int index = 1;
	lua_pushvalue( L, index );
	int recordIndex = luaL_ref( L, LUA_REGISTRYINDEX ); // hold on to proxy object in canse it may be released by Lua GC
	index ++;

	CoronaLuaRef listener = GetRecordListener( L, index );
	CKDatabase *database = GetDatabase( L, index );
	
	
	void (^completionHandler)(CKRecord*, NSError*);
	if (listener)
	{
		completionHandler = ^(CKRecord * record, NSError * err)
		{
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				CreateRecordEvent( L, "recordSave", nil == err, err);
				
				if (record)
				{
					// this all is done to avoid creating new PluginCKRecord with same CKRecord object
					lua_rawgeti(L, LUA_REGISTRYINDEX, recordIndex); // reuse object we held on to
					lua_setfield( L, -2, "record");
					luaL_unref(L, LUA_REGISTRYINDEX, recordIndex);  // stop holding on
				}
				
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			}];
		};
		
	}
	else
	{
		completionHandler = ^(CKRecord * record, NSError * err){};
	}
	
	[database saveRecord:record completionHandler:completionHandler];
	
	return 0;
}

int
PluginICloud::PluginCKRecord::get(lua_State *L)
{
	int index = 2;
	NSString *key = nil;
	
	if( lua_type( L, index ) == LUA_TSTRING )
	{
		key = [NSString stringWithUTF8String:lua_tostring(L, index)];
	}
	
	
	if(key)
	{
		if(!PushRecordValue( L, record[key] ))
		{
			lua_pushnil( L );
		}
	}
	else
	{
		lua_pushnil( L );
	}
	return 1;
}

int
PluginICloud::PluginCKRecord::set(lua_State *L)
{
	int index = 2;
	NSString *key = nil;
	
	if( lua_type( L, index ) == LUA_TSTRING )
	{
		key = [NSString stringWithUTF8String:lua_tostring(L, index)];
	}
	index++;
	
	id value = GetRecordValue( L, index, true);
	
	if (key)
	{
		if (value)
		{
			record[key] = value;
		}
		else
		{
			[record setNilValueForKey:key];
		}
		
	}
	
	return 0;
}

int
PluginICloud::PluginCKRecord::tableRepresentation(lua_State *L)
{
	return PushRecordValues( L, record );
}

int
PluginICloud::PluginCKRecord::metadata(lua_State *L)
{
	lua_newtable( L );
	
	if ([record recordID])
	{
		PushRecordID( L, lua_gettop( L ),  record.recordID );
	}
	
	if ([record recordType])
	{
		lua_pushstring( L, [record.recordType UTF8String] );
		lua_setfield( L, -2, "type" );
	}
	
	if ([record creationDate])
	{
		lua_pushnumber( L, [record.creationDate timeIntervalSince1970] );
		lua_setfield( L, -2, "creationTime" );
	}

	if ([record modificationDate])
	{
		lua_pushnumber( L, [record.modificationDate timeIntervalSince1970] );
		lua_setfield( L, -2, "modificationTime" );
	}

	if ([record lastModifiedUserRecordID])
	{
		lua_newtable( L );
		PushRecordID( L, lua_gettop( L ),  record.lastModifiedUserRecordID );
		lua_setfield( L, -2, "lastModifiedUserRecordID" );
	}

	if ([record creatorUserRecordID])
	{
		lua_newtable( L );
		PushRecordID( L, lua_gettop( L ),  record.creatorUserRecordID );
		lua_setfield( L, -2, "creatorUserRecordID" );
	}
	
	return 1;
}



CoronaLuaRef
PluginICloud::GetRecordListener( lua_State *L, int index )
{
	if ( !lua_istable( L, index) )
	{
		return nil;
	}
	
	CoronaLuaRef listener = NULL;
	lua_getfield( L, index, "onComplete" );
	if( CoronaLuaIsListener( L, -1, kRecordEvent ) )
	{
		listener = CoronaLuaNewRef( L, -1 );
	}
	lua_pop( L, 1 );
	
	return listener;
}

CKContainer*
PluginICloud::GetContainer( lua_State *L, int index)
{
	NSString* containerId = nil;
	lua_getfield( L, index, "containerId" );
	if(lua_type( L, -1) == LUA_TSTRING )
	{
		containerId = [NSString stringWithUTF8String:lua_tostring( L, -1)];
	}
	lua_pop( L, 1 );
	
	CKContainer *container;
	if (nil != containerId)
	{
		container = [CKContainer containerWithIdentifier:containerId];
	}
	else
	{
		container = [CKContainer defaultContainer];
	}
	return container;
}

CKDatabase*
PluginICloud::GetDatabase( lua_State *L, int index )
{
	if ( !lua_istable( L, index) )
	{
		return nil;
	}
	
	CKDatabase *database = nil;
	CKContainer *container = GetContainer( L, index);
	
	lua_getfield( L, index, "database" );
	if(lua_type( L, -1) == LUA_TSTRING )
	{
		if ( strcmp( "public", lua_tostring( L, -1)) == 0 )
		{
			database = [container publicCloudDatabase];
		}
	}
	lua_pop( L, 1 );
	
	if ( database == nil )
	{
		database = [container privateCloudDatabase];
	}
	
	return database;
}

void
PluginICloud::PushRecordID( lua_State *L, int index, CKRecordID *recId )
{
	if( ![recId.zoneID.zoneName isEqualToString:CKRecordZoneDefaultName] )
	{
		lua_pushstring( L, [recId.zoneID.zoneName UTF8String] );
		lua_setfield( L, -2, "zoneName");
	}
	
	if( ![recId.zoneID.ownerName isEqualToString:CKOwnerDefaultName] )
	{
		lua_pushstring( L, [recId.zoneID.ownerName UTF8String] );
		lua_setfield( L, -2, "zoneOwner");
	}
	
	lua_pushstring( L, [recId.recordName UTF8String] );
	lua_setfield( L, -2, "recordName");
}

CKRecordZoneID *
PluginICloud::NewZoneID (lua_State *L, int index )
{
	CKRecordZoneID *zoneId = nil;
	lua_getfield( L, index, "zoneName" );
	if( lua_type( L, -1) == LUA_TSTRING )
	{
		NSString *zoneName = [NSString stringWithUTF8String:lua_tostring( L, -1)];
		if([zoneName length])
		{
			NSString *zoneOwner = CKOwnerDefaultName;
			
			lua_getfield( L, index, "zoneOwner" );
			if( lua_type( L, -1) == LUA_TSTRING )
			{
				zoneOwner = [NSString stringWithUTF8String:lua_tostring( L, -1)];
			}
			lua_pop(L, 1);
			
			zoneId = [[CKRecordZoneID alloc] initWithZoneName:zoneName ownerName:zoneOwner];
		}
	}
	lua_pop(L, 1);
	return zoneId;
}

CKRecordID *
PluginICloud::NewRecordID( lua_State *L, int index )
{
	CKRecordID *recId = nil;

	if( !lua_istable( L, index ) )
	{
		return recId;
	}

	CKRecordZoneID *zoneId = NewZoneID( L, index );
	
	NSString *recordName = nil;
	lua_getfield( L, index, "recordName" );
	if(lua_type( L, -1 ) == LUA_TSTRING)
	{
		recordName = [NSString stringWithUTF8String:lua_tostring(L, -1)];
	}
	lua_pop( L, 1 );
	
	if ([recordName length])
	{
		if ( nil == zoneId )
		{
			recId = [[CKRecordID alloc] initWithRecordName:recordName];
		}
		else
		{
			recId = [[CKRecordID alloc] initWithRecordName:recordName zoneID:zoneId];
		}
	}
	[zoneId release];
	
	return recId;
}

void
PluginICloud::CreateRecordEvent(lua_State *L, const char *type, bool success, NSError *err)
{
	CoronaLuaNewEvent( L, kRecordEvent );
	
	lua_pushstring( L, type );
	lua_setfield( L, -2, CoronaEventTypeKey());
	
	lua_pushboolean( L, !success );
	lua_setfield( L, -2, CoronaEventIsErrorKey());
	
	if (err)
	{
		lua_pushnumber( L, err.code );
		lua_setfield( L, -2, "errorCode" );
		
		PushErrorOrNil(L, success, err);
		lua_setfield( L, -2, "error");
	}
}


/*
 
 Here's list of acceptable types:
 
 CKReference
 CKAsset
 CLLocation
 NSData
 NSDate
 NSNumber
 NSString
 NSArray containing objects of any of the types above

 */
id
PluginICloud::GetRecordValue( lua_State *L, int index, bool allowArrays )
{
	index = CoronaLuaNormalize( L, index );
	id value = nil;
	switch(lua_type(L, index))
	{
		case LUA_TSTRING:
			value = [NSString stringWithUTF8String:lua_tostring( L, index )];
			break;
		case LUA_TNUMBER:
			value = [NSNumber numberWithDouble:lua_tonumber( L, index )];
			break;
		case LUA_TTABLE:
		{
			NSString *type = nil;
			lua_getfield( L, index, "type" );
			if ( lua_type( L, -1) == LUA_TSTRING )
			{
				type = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
			}
			lua_pop( L, 1 );
			
			if ([type isEqualToString:@"reference"])
			{
				CKRecordID *recId = NewRecordID( L, -1);
				CKReferenceAction action = CKReferenceActionNone;
				lua_getfield( L, -1, "action" );
				if (lua_type(L, -1) == LUA_TSTRING)
				{
					if(strcmp(lua_tostring( L, -1 ), "deleteSelf") == 0)
					{
						action = CKReferenceActionDeleteSelf;
					}
				}
				lua_pop( L, 1 );
				if (recId)
				{
					value = [[[CKReference alloc] initWithRecordID:recId action:action] autorelease];
				}
				[recId release];
			}
			else if([type isEqualToString:@"asset"])
			{
				NSString *path = nil;
				lua_getfield( L, -1, "path");
				if(lua_type( L, -1 ) == LUA_TSTRING )
				{
					path = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				}
				lua_pop( L, 1 );
				if(path)
				{
					value = [[[CKAsset alloc] initWithFileURL:[NSURL fileURLWithPath:path]] autorelease];
				}
			}
			else if([type isEqualToString:@"location"])
			{
				CLLocationDegrees lon=0,lat=0;
				int init = 0;
				lua_getfield( L, -1, "latitude");
				if(lua_type( L, -1 ) == LUA_TNUMBER )
				{
					lat = lua_tonumber( L, -1 );
					init += 1;
				}
				lua_pop( L, 1 );

				lua_getfield( L, -1, "longitude");
				if(lua_type( L, -1 ) == LUA_TNUMBER )
				{
					lon = lua_tonumber( L, -1 );
					init += 1;
				}
				lua_pop( L, 1 );
				
				if(init == 2)
				{
					value = [[[CLLocation alloc] initWithLatitude:lat longitude:lon] autorelease];
				}
			}
			else if([type isEqualToString:@"data"])
			{
				lua_getfield( L, -1, "data");
				if(lua_type( L, -1 ) == LUA_TSTRING )
				{
					size_t len=0;
					void *data = (void *)lua_tolstring( L, -1, &len );
					value = [NSData dataWithBytes:data length:len];
				}
				lua_pop( L, 1 );
			}
			else if([type isEqualToString:@"date"])
			{
				lua_getfield( L, -1, "time");
				if(lua_type( L, -1 ) == LUA_TNUMBER )
				{
					value = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, -1)];
				}
				lua_pop( L, 1 );
			}
			else if([type isEqualToString:@"number"])
			{
				lua_getfield( L, -1, "number");
				if(lua_type( L, -1 ) == LUA_TNUMBER )
				{
					value = [NSNumber numberWithDouble:lua_tonumber(L, -1)];
				}
				lua_pop( L, 1 );
			}
			else if([type isEqualToString:@"string"])
			{
				lua_getfield( L, -1, "string");
				if(lua_type( L, -1 ) == LUA_TSTRING )
				{
					value = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
				}
				lua_pop( L, 1 );
			}
			else if([type isEqualToString:@"array"] && allowArrays)
			{
				lua_getfield( L, -1, "array");
				if(lua_type( L, -1 ) == LUA_TTABLE )
				{
					size_t n = lua_objlen( L, -1 );
					NSMutableArray* ret = [NSMutableArray arrayWithCapacity:n];
					for (int i = 0; i<n; i++)
					{
						lua_rawgeti( L, -1, i+1 );
						id arrVal = GetRecordValue( L, -1, false);
						if (arrVal)
						{
							[ret addObject:arrVal];
						}
						lua_pop( L, 1 );
					}
					value = ret;
				}
				lua_pop( L, 1 );
			}
			
			break;
		}
		default:
			break;
	}
	return value;
}


int
PluginICloud::PushRecordValue(lua_State *L, id v)
{
	if ([v isKindOfClass:[CKReference class]])
	{
		CKReference * vv = (CKReference*)v;
		
		lua_createtable(L, 0, 4);
		
		lua_pushstring( L, "reference");
		lua_setfield( L, -2, "type");
		
		PushRecordID( L, lua_gettop( L ), vv.recordID );
		
		if (vv.referenceAction == CKReferenceActionDeleteSelf)
		{
			lua_pushstring( L, "deleteSelf");
			lua_setfield( L, -2, "action");
		}
	}
	else if([v isKindOfClass:[CKAsset class]])
	{
		CKAsset *vv = (CKAsset*)v;
		
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "asset");
		lua_setfield( L, -2, "type");
		
		lua_pushstring( L, [[vv.fileURL path] UTF8String]);
		lua_setfield( L, -2, "path");
	}
	else if([v isKindOfClass:[CLLocation class]])
	{
		CLLocation *vv = (CLLocation*)v;
		
		lua_createtable(L, 0, 3);
		
		lua_pushstring( L, "location");
		lua_setfield( L, -2, "type");
		
		lua_pushnumber( L, vv.coordinate.longitude);
		lua_setfield( L, -2, "longitude");
		
		lua_pushnumber( L, vv.coordinate.latitude);
		lua_setfield( L, -2, "latitude");
	}
	else if([v isKindOfClass:[NSData class]])
	{
		NSData *vv = (NSData*)v;
		
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "data");
		lua_setfield( L, -2, "type");
		
		lua_pushlstring( L, (const char*)vv.bytes, vv.length);
		lua_setfield( L, -2, "data");
	}
	else if([v isKindOfClass:[NSDate class]])
	{
		NSDate *vv = (NSDate*)v;
		
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "date");
		lua_setfield( L, -2, "type");
		
		lua_pushnumber( L, vv.timeIntervalSince1970);
		lua_setfield( L, -2, "time");
	}
	else if([v isKindOfClass:[NSNumber class]])
	{
		NSNumber *vv = (NSNumber*)v;
		
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "number");
		lua_setfield( L, -2, "type");
		
		lua_pushnumber( L, [vv doubleValue]);
		lua_setfield( L, -2, "number");
	}
	else if ([v isKindOfClass:[NSString class]])
	{
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "string");
		lua_setfield( L, -2, "type");
		
		lua_pushstring( L, [v UTF8String]);
		lua_setfield( L, -2, "string");
	}
	else if([v isKindOfClass:[NSArray class]])
	{
		NSArray *vv = v;
		lua_createtable(L, 0, 2);
		
		lua_pushstring( L, "array");
		lua_setfield( L, -2, "type");
		
		lua_createtable( L, (int)vv.count, 0);
		int i = 1;
		for (id o in v)
		{
			if (PushRecordValue(L, o) == 1)
			{
				lua_rawseti( L, -2, i++);
			}
		}
		lua_setfield( L, -2, "array");
	}
	else
	{
		return 0;
	}
	return 1;
}

int
PluginICloud::PushRecordValues(lua_State *L, CKRecord *record)
{
	NSArray<NSString *> *keys = record.allKeys;
	lua_createtable( L, 0, (int)[keys count]);
	for (NSString* k in keys)
	{
		if( PushRecordValue(L, record[k]) == 1 )
		{
			lua_setfield( L, -2, [k UTF8String]);
		}
	}
	return 1;
}

int
PluginICloud::PushRecord(lua_State *L, CKRecord *record)
{
	PluginCKRecord *recordProxy = new PluginCKRecord( L );
	recordProxy->SetRecord(record);
	return Luna<PluginCKRecord>::PushExistingObject( L, recordProxy);
}


int
PluginICloud::recordGetAccountStatus( lua_State* L )
{
	int index = 1;
	CoronaLuaRef listener = GetRecordListener( L, index );
	if (!listener)
	{
		CoronaLuaWarning( L, "iCloud.recordGetAccountStatus() - onComplete parameter is missing or empty");
		return 0;
	}
	
	if ([CKContainer class])
	{
		[GetContainer(L, index) accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError * err) {
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				CreateRecordEvent( L, "recordGetAccountStatus", nil == err, err);
				
				const char* status = "error";
				switch (accountStatus)
				{
					case CKAccountStatusAvailable:
						status = "ok";
						break;
					case CKAccountStatusRestricted:
						status = "restricted";
						break;
					case CKAccountStatusNoAccount:
						status = "noAccount";
						break;
					case CKAccountStatusCouldNotDetermine:
					default:
						break;
						
				}
				lua_pushstring( L, status );
				lua_setfield( L, -2, "status" );
				
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			}];
		}];
	}
	else
	{
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			CreateRecordEvent( L, "recordAccountStatus", false, [NSError errorWithDomain:@"This version of iOS doesn't support CloudKit" code:1 userInfo:nil]);
			
			const char* status = "error";
			lua_pushstring( L, status );
			lua_setfield( L, -2, "status" );
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );

		}];
	}
	
	return 0;
}


int
PluginICloud::recordDelete( lua_State *L )
{
	int index = 1;
	CoronaLuaRef listener = GetRecordListener( L, index );
	

	CKDatabase *database = GetDatabase( L, index );
	CKRecordID *recId = NewRecordID( L, index);
	
	if (!recId || !database)
	{
		CoronaLuaWarning( L, "iCloud.recordDelete() - invalid parameters");
		if (listener)
		{
			CoronaLuaDeleteRef( L, listener );
		}
		[recId release];
		return 0;
	}

	
	void (^completionHandler)(CKRecordID*, NSError*);
	if (listener)
	{
		completionHandler = ^(CKRecordID * record, NSError * err)
		{
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				CreateRecordEvent( L, "recordDelete", nil == err, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			}];
		};
		
	}
	else
	{
		completionHandler = ^(CKRecordID * record, NSError * err){};
	}
	
	[database deleteRecordWithID:recId completionHandler:completionHandler];
	
	[recId release];
	
	return 0;
}

int
PluginICloud::recordCreate(lua_State *L)
{
	int index = 1;
	
	if ( !lua_istable( L, index) )
	{
		CoronaLuaWarning( L, "iCloud.recordCreate() - didn't receive parameters table");
		return 0;
	}


	CKRecordID *recId = NewRecordID(L, index);
	NSString *recordType=nil;
	
	lua_getfield( L, index, "type" );
	if(lua_type( L, -1 ) == LUA_TSTRING)
	{
		recordType = [NSString stringWithUTF8String:lua_tostring(L, -1)];
	}
	lua_pop( L, 1 );
	
	if ( ![recordType length] )
	{
		CoronaLuaWarning( L, "iCloud.recordCreate() - record type must be non empty string");
		lua_pushnil( L );
		return 1;
	}
	
	CKRecord *record = nil;
	if (recId)
	{
		record = [[CKRecord alloc] initWithRecordType:recordType recordID:recId];
	}
	else
	{
		CKRecordZoneID *zoneId = NewZoneID( L, index );
		if (zoneId)
		{
			record = [[CKRecord alloc] initWithRecordType:recordType zoneID:zoneId];
		}
		else
		{
			record = [[CKRecord alloc] initWithRecordType:recordType];
		}
		[zoneId release];
	}
	
	
	lua_getfield( L, index, "table" );
	if(lua_istable( L, -1))
	{
		int t = lua_gettop( L );
		lua_pushnil(L);
		while (lua_next(L, t) != 0)
		{
			if (lua_type( L, -2) == LUA_TSTRING)
			{
				NSString *key = [NSString stringWithUTF8String:lua_tostring( L, -2 )];
				id value = GetRecordValue( L, -1, true );
				if (key && value)
				{
					record[key] = value;
				}
			}
			lua_pop(L, 1);
		}
	}
	lua_pop( L, 1 );

	
	
	PushRecord( L, record);
	
	[recId release];
	[record release];
	
	return 1;
}


int
PluginICloud::recordFetchMultiple( lua_State *L )
{
	
	int index = 1;
	
	if ( !lua_istable( L, index) )
	{
		CoronaLuaWarning( L, "iCloud.recordFetchMultiple() - didn't receive parameters table");
		return 0;
	}

	
	CoronaLuaRef listener = GetRecordListener( L, index );
	
	CKDatabase *database = GetDatabase( L, index );
	NSMutableArray<CKRecordID *> * records = nil;
	
	lua_getfield( L, index, "recordNameArray" );
	if ( lua_type(L, -1) == LUA_TTABLE )
	{
		size_t n = lua_objlen( L, -1 );
		records = [NSMutableArray arrayWithCapacity:n];
		for (int i = 0; i<n; i++)
		{
			lua_rawgeti( L, -1, i+1 );
			{
				CKRecordID * recordId = nil;
				if ( lua_type(L, -1) == LUA_TSTRING)
				{
					NSString* recIdStr = [NSString stringWithUTF8String:lua_tostring( L, -1 )];
					recordId = [[CKRecordID alloc] initWithRecordName:recIdStr];
				}
				else if ( lua_type(L, -1) == LUA_TTABLE )
				{
					recordId = NewRecordID( L, -1 );
				}
				if (recordId)
				{
					[records addObject:recordId];
				}
				[recordId release];
			}
			lua_pop( L, 1 );
		}
		
		
	}
	lua_pop( L, 1 );

	
	if (!listener || !database || !records)
	{
		CoronaLuaWarning( L, "iCloud.recordFetchMultiple() - invalid parameters");
		if (listener)
		{
			CoronaLuaDeleteRef( L, listener );
		}
		return 0;
	}
	
	CoronaLuaRef perRecordListener = NULL;
	lua_getfield( L, index, "onRecord" );
	if( CoronaLuaIsListener( L, -1, kRecordEvent ) )
	{
		perRecordListener = CoronaLuaNewRef( L, -1 );
	}
	lua_pop( L, 1 );

	
	
	CKFetchRecordsOperation* fetcher = [[CKFetchRecordsOperation alloc] initWithRecordIDs:records];
	fetcher.database = database;
	[fetcher setFetchRecordsCompletionBlock:^(NSDictionary<CKRecordID *,CKRecord *> * records, NSError * err) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{

			CreateRecordEvent( L, "recordFetchMultiple", nil == err, err);
			
			if ( nil == err && records != nil )
			{
				lua_createtable(L, (int)records.count, 0);
				int i = 1;
				for (CKRecordID* recordId in records)
				{
					CKRecord* record = [records objectForKey:recordId];
					if (record)
					{
						PushRecord(L, record);
						lua_rawseti( L, -2, i++);
					}
				}
				lua_setfield( L, -2, "recordArray");
			}
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
			
			if (perRecordListener)
			{
				CoronaLuaDeleteRef( L, perRecordListener );
			}
		}];
	}];
	
	if (perRecordListener)
	{
		[fetcher setPerRecordCompletionBlock:^(CKRecord * record, CKRecordID * recId, NSError * err) {
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				CreateRecordEvent( L, "recordFetchMultiple_OnRecord", nil == err, err);
				if (record && nil == err)
				{
					PushRecord(L, record);
				}
				else
				{
					lua_pushnil( L );
				}
				lua_setfield( L, -2, "record");
				
				if (recId && recId.recordName)
				{
					lua_pushstring( L, [recId.recordName UTF8String]);
					lua_setfield( L, -2, "recordName" );
				}
				
				CoronaLuaDispatchEvent( L, perRecordListener, 0 );
			}];
		}];
	}
	
	[fetcher start];
	[fetcher release];
	
	
	return 0;
}


int
PluginICloud::recordFetch( lua_State *L )
{
	
	CoronaLuaRef listener = NULL;
	
	int index = 1;
	
	if ( !lua_istable( L, index) )
	{
		CoronaLuaWarning( L, "iCloud.recordFetch() - didn't receive parameters table");
		return 0;
	}

	
	listener = GetRecordListener( L, index );
	
	CKDatabase *database = GetDatabase( L, index );
	CKRecordID *recId = NewRecordID(L, index);
	
	if (!listener || !recId || !database)
	{
		CoronaLuaWarning( L, "iCloud.recordFetch() - invalid parameters");
		if (listener)
		{
			CoronaLuaDeleteRef( L, listener );
		}
		return 0;
	}
	
	[database fetchRecordWithID:recId completionHandler:^(CKRecord *record, NSError * err) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			CreateRecordEvent( L, "recordFetch", nil == err, err);
			if (record && nil == err)
			{
				PushRecord(L, record);
			}
			else
			{
				lua_pushnil( L );
			}
			lua_setfield( L, -2, "record");
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		}];
		
	}];
	
	[recId release];
	return 0;
}


int
PluginICloud::recordQuery( lua_State *L )
{
	NSString *recordType = nil;
	NSPredicate *predicate = nil;
	int index = 1;
	
	if ( !lua_istable( L, index) )
	{
		CoronaLuaWarning( L, "iCloud.recordQuery() - didn't receive parameters table");
		return 0;
	}

	
	CoronaLuaRef listener = GetRecordListener( L, index );
	CKDatabase *database = GetDatabase( L, index );

	
	lua_getfield( L, index, "type" );
	if(lua_type( L, -1 ) == LUA_TSTRING)
	{
		recordType = [NSString stringWithUTF8String:lua_tostring(L, -1)];
	}
	lua_pop( L, 1 );
	
	NSMutableArray *args = nil;
	lua_getfield( L, index, "queryParams" );
	if(lua_type( L, -1 ) == LUA_TTABLE)
	{
		size_t n = lua_objlen( L, -1 );
		args = [NSMutableArray arrayWithCapacity:n];
		for (int i = 0; i<n; i++)
		{
			lua_rawgeti( L, -1, i+1 );
			id arrVal = GetRecordValue( L, -1, false);
			if (arrVal)
			{
				[args addObject:arrVal];
			}
			lua_pop( L, 1 );
		}
	}
	lua_pop( L, 1 );
	
	lua_getfield( L, index, "query" );
	if(lua_type( L, -1 ) == LUA_TSTRING)
	{
		NSString *query = [NSString stringWithUTF8String:lua_tostring(L, -1)];
		predicate = [NSPredicate predicateWithFormat:query argumentArray:args];
	}
	lua_pop( L, 1 );

	
	if (!listener || !recordType || !database || !predicate)
	{
		CoronaLuaWarning( L, "iCloud.recordQuery() - invalid parameters");
		if (listener)
		{
			CoronaLuaDeleteRef( L, listener );
		}
		return 0;
	}

	CKRecordZoneID *zoneId = NewZoneID( L, index );

	
	CKQuery *query = [[CKQuery alloc] initWithRecordType:recordType predicate:predicate];
	[database performQuery:query inZoneWithID:zoneId completionHandler:^(NSArray<CKRecord *> * results, NSError * err) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			CreateRecordEvent( L, "recordQuery", nil == err, err);
			
			if ( nil == err && results != nil )
			{
				lua_createtable(L, (int)results.count, 0);
				int i = 1;
				for (CKRecord*record in results)
				{
					PushRecord(L, record);
					lua_rawseti( L, -2, i++);
				}
				lua_setfield( L, -2, "recordArray");
			}
			
			CoronaLuaDispatchEvent( L, listener, 0 );
			CoronaLuaDeleteRef( L, listener );
		}];
	}];
	[CKQuery release];
	[zoneId release];

	return 0;
}

int
PluginICloud::recordCreateZone( lua_State *L )
{
	int index = 1;
	
	if ( !lua_istable( L, index) )
	{
		CoronaLuaWarning( L, "iCloud.recordCreateZone() - didn't receive parameters table");
		return 0;
	}

	CoronaLuaRef listener = GetRecordListener( L, index );
	CKDatabase *database = GetDatabase( L, index );
	CKRecordZoneID *zoneId = NewZoneID( L, index );
	
	if ( !database || !zoneId)
	{
		CoronaLuaWarning( L, "iCloud.recordCreateZone() - invalid parameters");
		if (listener)
		{
			CoronaLuaDeleteRef( L, listener );
		}
		return 0;
	}

	void (^completionHandler)(CKRecordZone*, NSError*);
	if (listener)
	{
		completionHandler = ^(CKRecordZone * zone, NSError* err) {
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				CreateRecordEvent( L, "recordCreateZone", nil == err, err);
				CoronaLuaDispatchEvent( L, listener, 0 );
				CoronaLuaDeleteRef( L, listener );
			}];
		};
		
	}
	else
	{
		completionHandler = ^(CKRecordZone * record, NSError * err){};
	}

	
	CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneID:zoneId];
	[database saveRecordZone:zone completionHandler:completionHandler];
	
	[zone release];
	[zoneId release];
	return 0;
}
// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_iCloud( lua_State *L )
{
	return PluginICloud::Open( L );
}
