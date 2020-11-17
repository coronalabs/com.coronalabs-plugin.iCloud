//
//  luna.h
//  Plugin
//
//  Created by Vlad Shcherban on 2015-12-04.
//
//

#ifndef luna_wrapper_h
#define luna_wrapper_h

// http://lua-users.org/wiki/LunaWrapper
// available under BSD 2-Clause license - http://opensource.org/licenses/BSD-2-Clause

template<class T> class Luna {
public:
	static void Register(lua_State *L, bool pushGlobal = true) {
		if (pushGlobal)
		{
			lua_pushcfunction(L, &Luna<T>::constructor);
			lua_setglobal(L, T::className);
		}
		
		luaL_newmetatable(L, T::className);
		lua_pushstring(L, "__gc");
		lua_pushcfunction(L, &Luna<T>::gc_obj);
		lua_settable(L, -3);
	}
	
	static int PushExistingObject( lua_State *L, T* obj )
	{
		lua_newtable(L);
		lua_pushnumber(L, 0);
		T** a = (T**)lua_newuserdata(L, sizeof(T*));
		*a = obj;
		luaL_getmetatable(L, T::className);
		lua_setmetatable(L, -2);
		lua_settable(L, -3); // table[0] = obj;
		
		for (int i = 0; T::Register[i].name; i++) {
			lua_pushstring(L, T::Register[i].name);
			lua_pushnumber(L, i);
			lua_pushcclosure(L, &Luna<T>::thunk, 1);
			lua_settable(L, -3);
		}
		return 1;
	}
	
	static int constructor(lua_State *L) {
		T* obj = new T(L);
		return PushExistingObject( L, obj );
	}
	
	static int thunk(lua_State *L) {
		int i = (int)lua_tonumber(L, lua_upvalueindex(1));
		lua_pushnumber(L, 0);
		lua_gettable(L, 1);
		
		T** obj = static_cast<T**>(luaL_checkudata(L, -1, T::className));
		lua_remove(L, -1);
		return ((*obj)->*(T::Register[i].mfunc))(L);
	}
	
	static int gc_obj(lua_State *L) {
		T** obj = static_cast<T**>(luaL_checkudata(L, -1, T::className));
		delete (*obj);
		return 0;
	}
	
	struct RegType {
		const char *name;
		int(T::*mfunc)(lua_State*);
	};
};



#endif /* luna_wrapper_h */
