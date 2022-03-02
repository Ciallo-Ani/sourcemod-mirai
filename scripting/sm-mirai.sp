#include <sourcemod>
#include <convar_class>
#include <sm-mirai>



#pragma newdecls required
#pragma semicolon 1

Convar gCV_Remote_URL = null;

bool gB_Connected = false;

char gS_RemoteURL[512];
char gS_SessionKey[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("QQBot.AddBot", Native_AddQQBot);
	CreateNative("QQBot.GetSessionKey", Native_QQBot_GetSessionKey);
	CreateNative("QQBot.GetMemberInfo", Native_QQBot_GetMemberInfo);
	CreateNative("QQBot.SendMessageToGroup", Native_QQBot_SendMessageToGroup);
	CreateNative("QQBot.IsSingleMode", Native_QQBot_IsSingleMode);
	CreateNative("QQBot.SendTempMessage", Native_QQBot_SendTempMessage);

	RegPluginLibrary("sm-mirai");

	return APLRes_Success;
}

public void OnPluginStart()
{
	gCV_Remote_URL = new Convar("mirai_remote_http_url", "http://112.74.41.91:6666");
	Convar.AutoExecConfig();

	gCV_Remote_URL.AddChangeHook(OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	strcopy(gS_RemoteURL, sizeof(gS_RemoteURL), newValue);
}

public void OnConfigsExecuted()
{
	gCV_Remote_URL.GetString(gS_RemoteURL, sizeof(gS_RemoteURL));
}

void FormatURL(char[] buffer, int len, const char[] interfaceName)
{
	FormatEx(buffer, len, "%s%s", gS_RemoteURL, interfaceName);
}

public any Native_AddQQBot(Handle plugin, int numParams)
{
	QQBot bot = GetNativeCell(1); /* this pointer */

	char key[64];
	GetNativeString(2, key, sizeof(key));

	char sURL[512];
	FormatURL(sURL, sizeof(sURL), "/verify");
	HTTPRequest http = new HTTPRequest(sURL);

	JSONObject json = new JSONObject();
	json.SetString("verifyKey", key);

	http.Post(json, QQBot_Verify_Callback, bot);

	delete json;
}

public void QQBot_Verify_Callback(HTTPResponse response, QQBot bot, const char[] error)
{
	if(response.Status != HTTPStatus_OK)
	{
		LogMessage("QQBot verify connection failed. Error: %s", error);
		gB_Connected = false;
		return;
	}

	char sBuffer[512];
	response.Data.ToString(sBuffer, sizeof(sBuffer));

	JSONObject jsonObj = JSONObject.FromString(sBuffer);
	if(jsonObj.GetInt("code") != 0)
	{
		char sError[64];
		jsonObj.GetString("msg", sError, sizeof(sError));

		LogMessage("QQBot verify connection failed. Error: %s", sError);

		gB_Connected = false;

		delete jsonObj;

		return;
	}

	jsonObj.GetString("session", gS_SessionKey, sizeof(gS_SessionKey));

	if(!StrEqual(gS_SessionKey, "SINGLE_SESSION"))
	{
		char sURL[512];
		FormatURL(sURL, sizeof(sURL), "/bind");
		HTTPRequest http = new HTTPRequest(sURL);

		JSONObject jsonObj2 = new JSONObject();
		jsonObj2.SetString("sessionKey", gS_SessionKey);
		jsonObj2.SetInt64("qq", "3199329079");

		http.Post(jsonObj2, OnBindSession_Callback);
		delete jsonObj2;
	}
	else
	{
		gB_Connected = true;
	}

	delete jsonObj;

	PrintToServer(gS_SessionKey);
}

public void OnBindSession_Callback(HTTPResponse response, any value, const char[] error)
{
	char sBuffer[512];
	response.Data.ToString(sBuffer, sizeof(sBuffer));

	JSONObject jsonObj = JSONObject.FromString(sBuffer);
	if(jsonObj.GetInt("code") != 0)
	{
		char sError[64];
		jsonObj.GetString("msg", sError, sizeof(sError));

		LogMessage("QQBot verify bind failed. Error: %s", sError);

		gB_Connected = false;

		delete jsonObj;

		return;
	}

	gB_Connected = true;

	delete jsonObj;

	PrintToServer(sBuffer);
}

public any Native_QQBot_GetMemberInfo(Handle plugin, int numParams)
{
	if(!gB_Connected)
	{
		LogMessage("[mirai] QQBot haven't connected!");

		return;
	}

	QQBot bot = GetNativeCell(1); /* this pointer */
	int group = GetNativeCell(2);
	int member = GetNativeCell(3);
	Function callback = GetNativeFunction(4);

	char sURL[512];
	FormatURL(sURL, sizeof(sURL), "/memberInfo");
	HTTPRequest http = new HTTPRequest(sURL);

	if(!bot.IsSingleMode())
	{
		http.AppendQueryParam("sessionKey", "%s", gS_SessionKey);
	}

	http.AppendQueryParam("target", "%d", group);
	http.AppendQueryParam("memberId", "%u", member);

	PrivateForward fwd = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell);
	fwd.AddFunction(plugin, callback);

	JSONObject tmpCache = new JSONObject();
	tmpCache.SetInt("bot", view_as<int>(bot));
	tmpCache.SetInt("callback", view_as<int>(fwd));

	http.Get(QQBot_GetMemberInfo_Callback, tmpCache);
}

public void QQBot_GetMemberInfo_Callback(HTTPResponse response, JSONObject data, const char[] error)
{
	if(response.Status != HTTPStatus_OK)
	{
		LogMessage("QQBot GetMemberInfo failed. Error: %s", error);
		return;
	}

	QQBot bot = view_as<QQBot>(data.GetInt("bot"));
	PrivateForward fwd = view_as<PrivateForward>(data.GetInt("callback"));

	if(fwd != null)
	{
		Call_StartForward(fwd);
		Call_PushCell(bot);
		Call_PushCell(response);
		Call_Finish();
	}

	delete bot;
	delete fwd;
	delete data;
}

public any Native_QQBot_SendMessageToGroup(Handle plugin, int numParams)
{
	if(!gB_Connected)
	{
		LogMessage("[mirai] QQBot haven't connected!");

		return;
	}

	QQBot bot = GetNativeCell(1); /* this pointer */
	int group = GetNativeCell(2);

	char sMessage[1024];
	GetNativeString(3, sMessage, sizeof(sMessage));

	Function callback = GetNativeFunction(4);

	char sURL[512];
	FormatURL(sURL, sizeof(sURL), "/sendGroupMessage");
	HTTPRequest http = new HTTPRequest(sURL);

	JSONObject jsonObj = new JSONObject();
	if(!bot.IsSingleMode())
	{
		jsonObj.SetString("sessionKey", gS_SessionKey);
	}

	jsonObj.SetInt("target", group);

	JSONObject jsonObj2 = new JSONObject();
	jsonObj2.SetString("type", "Plain");
	jsonObj2.SetString("text", sMessage);

	JSONArray jsonArr = new JSONArray();
	jsonArr.Push(jsonObj2);
	jsonObj.Set("messageChain", jsonArr);

	PrivateForward fwd = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell);
	fwd.AddFunction(plugin, callback);

	JSONObject tmpCache = new JSONObject();
	tmpCache.SetInt("bot", view_as<int>(bot));
	tmpCache.SetInt("callback", view_as<int>(fwd));

	http.Post(jsonObj, QQBot_SendMessageToGroup_Callback, tmpCache);

	delete jsonObj;
	delete jsonObj2;
	delete jsonArr;
}

public void QQBot_SendMessageToGroup_Callback(HTTPResponse response, JSONObject data, const char[] error)
{
	if(response.Status != HTTPStatus_OK)
	{
		LogMessage("QQBot SendMessageToGroup failed. Error: %s", error);
		return;
	}

	QQBot bot = view_as<QQBot>(data.GetInt("bot"));
	PrivateForward fwd = view_as<PrivateForward>(data.GetInt("callback"));

	if(fwd != null)
	{
		Call_StartForward(fwd);
		Call_PushCell(bot);
		Call_PushCell(response);
		Call_Finish();
	}

	delete bot;
	delete fwd;
	delete data;
}

public any Native_QQBot_SendTempMessage(Handle plugin, int numParams)
{
	if(!gB_Connected)
	{
		LogMessage("[mirai] QQBot haven't connected!");

		return;
	}

	QQBot bot = GetNativeCell(1); /* this pointer */
	int qq = GetNativeCell(2);
	int group = GetNativeCell(3);

	char sMessage[1024];
	GetNativeString(4, sMessage, sizeof(sMessage));

	Function callback = GetNativeFunction(5);

	char sURL[512];
	FormatURL(sURL, sizeof(sURL), "/sendTempMessage");
	HTTPRequest http = new HTTPRequest(sURL);

	JSONObject jsonObj = new JSONObject();
	if(!bot.IsSingleMode())
	{
		jsonObj.SetString("sessionKey", gS_SessionKey);
	}

	jsonObj.SetInt("qq", qq);
	jsonObj.SetInt("group", group);

	JSONObject jsonObj2 = new JSONObject();
	jsonObj2.SetString("type", "Plain");
	jsonObj2.SetString("text", sMessage);

	JSONArray jsonArr = new JSONArray();
	jsonArr.Push(jsonObj2);
	jsonObj.Set("messageChain", jsonArr);

	PrivateForward fwd = new PrivateForward(ET_Ignore, Param_Cell, Param_Cell);
	fwd.AddFunction(plugin, callback);

	JSONObject tmpCache = new JSONObject();
	tmpCache.SetInt("bot", view_as<int>(bot));
	tmpCache.SetInt("callback", view_as<int>(fwd));

	http.Post(jsonObj, QQBot_SendTempMessage_Callback, tmpCache);

	delete jsonObj;
	delete jsonObj2;
	delete jsonArr;
}

public void QQBot_SendTempMessage_Callback(HTTPResponse response, JSONObject data, const char[] error)
{
	if(response.Status != HTTPStatus_OK)
	{
		LogMessage("QQBot SendTempMessage failed. Error: %s", error);
		return;
	}

	QQBot bot = view_as<QQBot>(data.GetInt("bot"));
	PrivateForward fwd = view_as<PrivateForward>(data.GetInt("callback"));

	if(fwd != null)
	{
		Call_StartForward(fwd);
		Call_PushCell(bot);
		Call_PushCell(response);
		Call_Finish();
	}

	delete bot;
	delete fwd;
	delete data;
}

public any Native_QQBot_GetSessionKey(Handle plugin, int numParams)
{
	return SetNativeString(2, gS_SessionKey, GetNativeCell(3));
}

public any Native_QQBot_IsSingleMode(Handle plugin, int numParams)
{
	return StrEqual(gS_SessionKey, "SINGLE_SESSION");
}