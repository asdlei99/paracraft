--[[
Title: CodeAPI
Author(s): LiXizhi
Date: 2018/5/16
Desc: sandbox API environment
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_Events.lua");
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeCoroutine.lua");
local CodeCoroutine = commonlib.gettable("MyCompany.Aries.Game.Code.CodeCoroutine");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local env_imp = commonlib.gettable("MyCompany.Aries.Game.Code.env_imp");

-- create a clone of some code block's actor
-- @param name: if nil or "myself", it means clone myself
-- @param msg: any mesage that is forwared to clone event
function env_imp:clone(name, msg)
	self.codeblock:CreateClone(name, msg)
	env_imp.checkyield(self);
end

-- delete current cloned actor
function env_imp:delete()
	if(self.actor) then
		self.actor:DeleteThisActor();
		self.actor = nil;
	end
	env_imp.checkyield(self);
end

function env_imp:registerCloneEvent(callbackFunc)
	self.codeblock:RegisterCloneActorEvent(callbackFunc);
	env_imp.checkyield(self);
end

function env_imp:registerBroadcastEvent(text, callbackFunc)
	self.codeblock:RegisterTextEvent(text, callbackFunc);
	env_imp.checkyield(self);
end

-- broadcast a global message.
-- @param msg: if nil, default to current actor's name
function env_imp:broadcast(text, msg)
	if(msg==nil and self.actor) then
		msg = self.actor:GetName();
	end
	self.codeblock:BroadcastTextEvent(text, msg);
	env_imp.checkyield(self);
end

-- broadcast a global message and wait for all its handlers are finished
-- @param msg: if nil, default to current actor's name
function env_imp:broadcastAndWait(text, msg)
	local isFinished = false;
	if(msg==nil and self.actor) then
		msg = self.actor:GetName();
	end
	self.codeblock:BroadcastTextEvent(text, msg, self.co:MakeCallbackFunc(function()
		isFinished = true;
		env_imp.resume(self);
	end));
	if(not isFinished) then
		env_imp.yield(self);
	end
end

function env_imp:registerStartEvent(callbackFunc)
	self.codeblock:RegisterTextEvent("start", callbackFunc);
end

function env_imp:registerClickEvent(callbackFunc)
	self.codeblock:RegisterClickEvent(callbackFunc);
end

function env_imp:registerKeyPressedEvent(keyname, callbackFunc)
	self.codeblock:RegisterKeyPressedEvent(keyname, callbackFunc);
end

function env_imp:registerAnimationEvent(time, callbackFunc)
	self.codeblock:RegisterAnimationEvent(time, callbackFunc);
end

-- run function in a new coroutine
function env_imp:run(mainFunc)
	if(type(mainFunc) == "function") then
		local co = CodeCoroutine:new():Init(self.codeblock);
		co:SetActor(self.actor);
		co:SetFunction(mainFunc);
		co:Run();	
	end
end




