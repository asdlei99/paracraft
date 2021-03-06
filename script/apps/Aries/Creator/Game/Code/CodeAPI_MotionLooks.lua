--[[
Title: CodeAPI
Author(s): LiXizhi
Date: 2018/5/16
Desc: sandbox API environment
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Code/CodeAPI_MotionLooks.lua");
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Creator/Game/Common/Direction.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/SceneContext/SelectionManager.lua");
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CmdParser.lua");
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");
local SelectionManager = commonlib.gettable("MyCompany.Aries.Game.SelectionManager");
local Direction = commonlib.gettable("MyCompany.Aries.Game.Common.Direction")
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic");
local env_imp = commonlib.gettable("MyCompany.Aries.Game.Code.env_imp");

-- wait some time
-- @param seconds: in seconds, if nil, it is one tick or env_imp.GetDefaultTick(self)
function env_imp:wait(seconds)
	seconds = seconds or env_imp.GetDefaultTick(self);
	self.co:SetTimeout(math.floor(seconds*1000), function()
		env_imp.resume(self);
	end) 
	env_imp.yield(self);
end

-- say some text and wait for some time. 
-- @param text: if nil, it will remove text
-- @param duration: in seconds. if nil, it means forever
function env_imp:say(text, duration)
	if(duration) then
		env_imp.say(self, text);
		env_imp.wait(self, duration);
		env_imp.say(self, nil);
	else
		local actor = env_imp.GetActor(self);
		if(actor) then
			if(text~=nil) then
				text = tostring(text);
			end
			actor:Say(text, -1)
		else
			GameLogic.AddBBS("codeblock", text, 10000);
		end
	end
end

-- walk relative to current block position and make it not dummy(has physics simulations)
-- the entity maybe blocked if target unreachable. 
-- it will move at the default speed. 
-- @param dx,dy,dz: if z is nil, y is z. in block unit, can be real numbers
-- @param duration: default to none
function env_imp:walk(dx,dy,dz, duration)
	if(not dz) then
		dz = dy;
		dy = nil;
	end
	local entity = env_imp.GetEntity(self);
	if(entity) then
		local x,y,z = entity:GetBlockPos();
		x = x + math.floor((dx or 0) + 0.5);
		y = y + math.floor((dy or 0) + 0.5);
		z = z + math.floor((dz or 0) + 0.5);
		if(entity.MoveTo) then
			entity:EnableAnimation(true);
			entity:SetDummy(false);
			entity:WalkTo(x,y,z);
			if(not duration) then
				duration = math.sqrt(dx*dx + dz*dz) * BlockEngine.blocksize / entity:GetWalkSpeed();
			end
			env_imp.wait(self, duration);
		end
	end
end

-- TODO: just in case, we allow user to change rotation style.
local useFourDirectionRotationStyle = false;

-- @param dist: in block unit, can be real numbers
function env_imp:walkForward(dist, duration)
	local entity = env_imp.GetEntity(self);
	if(entity) then
		if(useFourDirectionRotationStyle) then
			local dir = Direction.GetDirectionFromFacing(entity:GetFacing());
			local dx, dy, dz = Direction.GetOffsetBySide(dir);
			env_imp.walk(self, -dx*dist, -dy*dist, -dz*dist, duration);
		else
			local facing = entity:GetFacing()
			env_imp.walk(self, math.cos(facing)*dist, 0, -math.sin(facing)*dist, duration);
		end
	end
end


-- move delta position and wait a tick. unlike walk, it will ignore physics and always move there. 
-- @param dx,dy,dz: if z is nil, y is z. in block unit, can be real numbers.
-- @param duration: seconds to move to the target. default to 1 tick time. 
function env_imp:move(dx,dy,dz, duration)
	if(not dz) then
		dz = dy;
		dy = nil;
	end
	local actor = self.actor;
	if(actor) then
		local x,y,z = actor:GetPosition();
		local targetX = x + (dx or 0)*BlockEngine.blocksize;
		local targetY = y + (dy or 0)*BlockEngine.blocksize;
		local targetZ = z + (dz or 0)*BlockEngine.blocksize;
		if(not duration) then
			actor:SetPosition(targetX,targetY,targetZ);
			env_imp.wait(self, env_imp.GetDefaultTick(self));
		else
			local endTime = commonlib.TimerManager.GetCurrentTime()/1000 + duration;
			local stepTime = env_imp.GetDefaultTick(self);
			for i=0, math.floor(duration / stepTime) do
				local timeLeft = endTime - commonlib.TimerManager.GetCurrentTime()/1000;
				local stepCount = math.floor(timeLeft/stepTime);
				local x,y,z = actor:GetPosition();
				local dx, dy, dz = targetX - x, targetY - y, targetZ - z;
				if(stepCount>=2) then
					local inverseStep = 1/stepCount;
					dx, dy, dz = dx*inverseStep, dy*inverseStep, dz*inverseStep;	
				end
				env_imp.move(self, dx,dy,dz)
				if(stepCount<2) then
					break;
				end
			end
		end
	end
end

-- same as moveTo, except that we use real coordinate in block unit
function env_imp:setPos(x, y, z)
	local actor = self.actor;
	if(actor) then
		x,y,z = BlockEngine:real_min(x, y, z);
		actor:SetPosition(x, y, z);
	end
end

-- same as getX(), getY(), getZ(), except that we return real coordinate in block unit
function env_imp:getPos()
	local actor = self.actor;
	if(actor) then
		local x, y, z = actor:GetPosition();
		if(x) then
			return BlockEngine:block_float(x, y, z);
		end
	end
end


-- moveTo to a given block position
-- @param x,y,z: if z is nil, y is z. x can also be "mouse-pointer" or "@p" for current player or other actor name, while y and z are nil.
function env_imp:moveTo(x, y, z)
	local entity = env_imp.GetEntity(self);
	if(entity) then
		if(type(x) == "string") then
			if(x == "mouse-pointer") then
				local result = SelectionManager:MousePickBlock(true, false, false); 
				if(result and result.blockX) then
					local x,y,z = BlockEngine:GetBlockIndexBySide(result.blockX,result.blockY,result.blockZ,result.side);
					env_imp.moveTo(self, x,y,z);
				end
			elseif(type(x) == "string") then
				local entity2 = GameLogic.GetCodeGlobal():FindEntityByName(x);
				if(entity2) then
					local x2, y2, z2 = entity2:GetBlockPos();
					env_imp.moveTo(self, x2, y2, z2);
				end
			end
		elseif(x and y) then
			local ox,oy,oz = entity:GetBlockPos();
			if(not z) then
				y,z = oy, y;
			end
			self.actor:SetBlockPos(x,y,z);
			env_imp.checkyield(self);
		end
	end
end

-- move forward using current direction
-- @param dist: 1 block unit, can be real number 
-- @param duration: default to 1 tick
function env_imp:moveForward(dist, duration)
	local actor = env_imp.GetActor(self);
	if(actor) then
		if(useFourDirectionRotationStyle) then
			local dir = Direction.GetDirectionFromFacing(actor:GetFacing());
			local dx, dy, dz = Direction.GetOffsetBySide(dir);
			env_imp.move(self, -dx*dist, -dy*dist, -dz*dist, duration);
		else
			local facing = actor:GetFacing()
			env_imp.move(self, math.cos(facing)*dist, 0, -math.sin(facing)*dist, duration);
		end
	end
end

function env_imp:turn(degree)
	if(self.actor) then
		self.actor:SetFacingDelta(degree*math.pi/180);
	end
	env_imp.wait(self, env_imp.GetDefaultTick(self));
end

-- @param degree: [-180, 180] or "mouse-pointer" or "@p" for current player, or any actor name
function env_imp:turnTo(degree)
	local entity = env_imp.GetEntity(self);
	if(entity) then
		if(type(degree) == "number") then
			self.actor:SetFacing(degree*math.pi/180);
		elseif(degree == "mouse-pointer") then
			local result = SelectionManager:MousePickBlock(true, false, false); 
			if(result and result.blockX) then
				local x, y, z = entity:GetBlockPos();
				if(result.blockX ~= x or result.blockZ ~= z) then
					local facing = Direction.GetFacingFromOffset(result.blockX - x, result.blockY - y, result.blockZ - z);
					self.actor:SetFacing(facing);
				end
			end
		elseif(type(degree) == "string") then
			local entity2 = GameLogic.GetCodeGlobal():FindEntityByName(degree);
			if(entity2) then
				local x2, y2, z2 = entity2:GetBlockPos();
				local x, y, z = entity:GetBlockPos();
				if(x2 ~= x or z2 ~= z) then
					local facing = Direction.GetFacingFromOffset(x2 - x, y2 - y, z2 - z);
					self.actor:SetFacing(facing);
				end
			end
		end
	end
	env_imp.checkyield(self);
end

function env_imp:scale(scaleDeltaPercentage)
	local entity = env_imp.GetEntity(self);
	if(entity) then
		entity:SetScalingDelta(scaleDeltaPercentage/100);
	end
	env_imp.wait(self, env_imp.GetDefaultTick(self));
end

function env_imp:scaleTo(scalePercentage)
	local entity = env_imp.GetEntity(self);
	if(entity) then
		entity:SetScaling(scalePercentage/100);
	end
	env_imp.checkyield(self);
end


-- set animation id
-- @param anim_id: 0 for standing (default), 4 for walk. 
-- @param duration: default to 1 tick
function env_imp:anim(anim_id, duration)
	anim_id = anim_id or 0;
	local entity = env_imp.GetEntity(self);
	if(entity) then
		entity:EnableAnimation(true);
		entity:SetAnimation(anim_id);

		if(duration) then
			env_imp.wait(self, duration);
		end
	end
end

-- how fast we will play() the animation in movie block
-- @param speed: default to 1. if nil, it will return current speed.
function env_imp:playSpeed(speed)
	if(self.actor) then
		if(speed) then
			self.actor:SetPlaySpeed(speed);
		else
			return self.actor:GetPlaySpeed();
		end
	end
end

-- play a time series animation in the movie block.
-- this function will return immediately.
-- @param timeFrom: time in milliseconds, default to 0.
-- @param timeTo: if nil, default to timeFrom
-- @param isLooping: default to false.
function env_imp:play(timeFrom, timeTo, isLooping)
	timeFrom = timeFrom or 0;
	local time = timeFrom;
	local entity = env_imp.GetEntity(self);
	if(entity) then
		entity:SetDummy(true);
		entity:EnableAnimation(false);
		local actor = env_imp.GetActor(self);
		if(not actor) then
			return
		end
		actor:SetTime(time);
		actor:ResetOffsetPosAndRotation();
		actor:FrameMove(0, false);
		self.codeblock:OnAnimateActor(actor, time);

		if(timeTo and timeTo>timeFrom) then
			local deltaTime = math.floor(env_imp.GetDefaultTick(self)*1000);
			local function frameMove_(timer)
				local delta = timer:GetDelta() * actor:GetPlaySpeed();
				time = time + delta;
				if(time >= timeTo) then
					if(isLooping) then
						if((time - delta) == timeTo) then
							time = timeFrom;
						else
							time = timeTo;
						end
					else
						time = timeTo;
						timer:Change();
					end
				end
				actor:SetTime(time);
				actor:FrameMove(0, false);
				if(timeTo == time) then
					self.codeblock:OnAnimateActor(actor, time);
				end
			end
			if(not self.actor.playTimer) then
				self.actor.playTimer = self.codeblock:SetTimer(self.co:MakeCallbackFunc(frameMove_), 0, deltaTime);
				self.actor:Connect("beforeRemoved", function(actor)
					if(actor.playTimer) then
						self.codeblock:KillTimer(actor.playTimer);
						actor.playTimer = nil;
					end
				end)
			else
				self.actor.playTimer.callbackFunc = self.co:MakeCallbackFunc(frameMove_);
			end
			self.actor.playTimer:Change(0, deltaTime);
		end
	end
end

-- same as play(), but looping
function env_imp:playLoop(timeFrom, timeTo)
	env_imp.play(self, timeFrom, timeTo, true);
	env_imp.checkyield(self);
end

function env_imp:stop()
	if(self.actor and self.actor.playTimer) then
		self.codeblock:KillTimer(self.actor.playTimer);
		self.actor.playTimer = nil;
	end
	env_imp.checkyield(self);
end

function env_imp:show()
	if(self.actor) then
		self.actor:SetVisible(true);
	end
	env_imp.checkyield(self);
end

function env_imp:hide()
	if(self.actor) then
		self.actor:SetVisible(false);
	end
	env_imp.checkyield(self);
end

function env_imp:bounce()
	if(self.actor) then
		self.actor:Bounce();
	end
	env_imp.checkyield(self);
end

-- set focus to current actor or the main player 
-- @param : nil or "myself" means current actor, "player" means the main player
function env_imp:focus(name)
	if(not name or name == "myself") then
		if(self.actor) then
			self.actor:SetFocus();
		end
	elseif(name == "player") then
		EntityManager.GetPlayer():SetFocus();
	end
	env_imp.checkyield(self);
end

-- same as the /velocity command
-- "1,~,~"   :set current player's speed
-- "set 1,1,1"   :set speed of the test entity
-- "add 1,~,~"   :use ~ to retain last speed.
function env_imp:velocity(cmd_text)
	env_imp.checkyield(self);
	local list, bIsAdd;
	local playerEntity = env_imp.GetEntity(self);
	if(not playerEntity) then
		return;
	end
	-- default to set velocity
	bIsAdd, cmd_text = CmdParser.ParseText(cmd_text, "add");
	if(not bIsAdd) then
		bIsAdd, cmd_text = CmdParser.ParseText(cmd_text, "set");
		bIsAdd = nil;
	end
	list, cmd_text = CmdParser.ParseNumberList(cmd_text, nil, "|,%s")
	if(list) then
		local x, y, z;
		if(#list == 1) then
			x,y,z = nil,list[1],nil;
		elseif(#list == 2) then
			x,y,z = list[1],nil,list[2];
		else
			x,y,z = list[1],list[2],list[3];
		end
		if(bIsAdd) then
			playerEntity:AddVelocity(x or 0,y or 0,z or 0);
		else
			playerEntity:SetVelocity(x,y,z);
		end
		playerEntity:SetDummy(false);
	end
end

function env_imp:camera(dist, pitch, facing)
	if(dist) then
		GameLogic.options:SetCameraObjectDistance(dist)
	end
	if(pitch) then
		pitch = pitch*math.pi/180;
		local att = ParaCamera.GetAttributeObject();
		att:SetField("CameraLiftupAngle", pitch);
	end
	if(facing) then
		facing = facing*math.pi/180;
		local att = ParaCamera.GetAttributeObject();
		att:SetField("CameraRotY", facing);
	end
end