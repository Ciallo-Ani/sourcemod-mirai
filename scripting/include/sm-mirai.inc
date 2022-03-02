#if defined _sm_mirai_included
	#endinput
#endif
#define _sm_mirai_included

#include <ripext>

typedef OnBotRequested = function void(QQBot bot, HTTPResponse response);

// =======[ methodmap ]=======

methodmap QQBot < Handle
{
	public native void AddBot(const char[] verifyKey);
	public native void GetSessionKey(char[] buffer, int maxlength);
	public native void GetMemberInfo(int group, int member, OnBotRequested callback);
	public native void SendMessageToGroup(int group, const char[] message, OnBotRequested callback);
	public native void SendTempMessage(int qq, int group, const char[] message, OnBotRequested callback);
	public native bool IsSingleMode();
};



public SharedPlugin __pl_sm_mirai =
{
	name = "sm-mirai",
	file = "sm-mirai.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_sm_mirai_SetNTVOptional()
{
	MarkNativeAsOptional("QQBot.AddBot");
	MarkNativeAsOptional("QQBot.GetMemberInfo");
	MarkNativeAsOptional("QQBot.SendMessageToGroup");
	MarkNativeAsOptional("QQBot.GetSessionKey");
	MarkNativeAsOptional("QQBot.IsSingleMode");
}
#endif