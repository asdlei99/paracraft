--[[
Title: CommandWiki
Author(s): LiXizhi
Date: 2016/1/23
Desc: generate Wiki documentation for all paracraft commands,blocks and doc. 
wiki doc site is in sync with https://github.com/LiXizhi/ParaCraft/wiki
use the lib:
-------------------------------------------------------
NPL.load("(gl)script/apps/Aries/Creator/Game/Commands/CommandWiki.lua");
-------------------------------------------------------
]]
local SlashCommand = commonlib.gettable("MyCompany.Aries.SlashCommand.SlashCommand");
local CmdParser = commonlib.gettable("MyCompany.Aries.Game.CmdParser");	
local BlockEngine = commonlib.gettable("MyCompany.Aries.Game.BlockEngine")
local block_types = commonlib.gettable("MyCompany.Aries.Game.block_types")
local block = commonlib.gettable("MyCompany.Aries.Game.block")
local GameLogic = commonlib.gettable("MyCompany.Aries.Game.GameLogic")
local EntityManager = commonlib.gettable("MyCompany.Aries.Game.EntityManager");
local Commands = commonlib.gettable("MyCompany.Aries.Game.Commands");
local CommandManager = commonlib.gettable("MyCompany.Aries.Game.CommandManager");

local WikiGen = commonlib.inherit({});

Commands["wikigen"] = {
	name="wikigen", 
	quick_ref="/wikigen [-o output_path]", 
	desc=[[generate wiki documentation for all paracraft commands,blocks and doc. 
wiki doc site is in sync with https://github.com/LiXizhi/ParaCraft/wiki
@param -o output_path: specify the output path, default to "www/ParaCraftWiki"
Examples: 
/wikigen
/wikigen -o D:\lxzsrc\ParaCraft.wiki\
]], 
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		local output_dir;
		local option = "";
		while (option) do
			option, cmd_text = CmdParser.ParseOption(cmd_text);
			if(option == "o") then
				output_dir, cmd_text = CmdParser.ParseString(cmd_text);
			end
		end
		local sync_result = System.os("git pull");
		if(sync_result and sync_result:find("^%s*Already up%Wto%Wdate")) then
			local generator = WikiGen:new():Run(output_dir);
		else
			local msg = format("git pull failed: %s, please make sure local dir www/ParaCraftWiki/ is a valid clone of https://github.com/LiXizhi/ParaCraft/wiki/", sync_result or "");
			LOG.std(nil, "info", "cmd_wikigen", msg);
			_guihelper.MessageBox(msg);
		end
	end,
};

Commands["wiki"] = {
	name="wiki", 
	quick_ref="/wiki [item_id|wiki_word]", 
	desc=[[show wiki page for a given block id or wiki word
/wiki 100    show wiki for block id 100
/wiki cmd_wiki   show wiki command help
/wiki item_Bone   show bone block help
]], 
	handler = function(cmd_name, cmd_text, cmd_params, fromEntity)
		NPL.load("(gl)script/apps/Aries/Creator/Game/Areas/WebTutorials.lua");
		local WebTutorials = commonlib.gettable("MyCompany.Aries.Creator.Game.Desktop.WebTutorials");
		local item_id = tonumber(cmd_text);
		if(item_id) then
			local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
			local item = ItemClient.GetItem(item_id);
			if(item and item.name) then
				WebTutorials:ShowWebWiki("item_"..item.name);
			end
		else
			-- show wiki word
			local word = cmd_text:gsub("^%s+", ""):gsub("%s+$", "")
			if(word and word~="") then
				WebTutorials:ShowWebWiki(word);
			end
		end
	end,
};

function WikiGen:Run(output_dir)
	self.baseurl = "https://github.com/LiXizhi/ParaCraft/wiki/"
	self.output_dir = output_dir or "www/ParaCraftWiki/";
	
	ParaIO.CreateDirectory(self.output_dir);

	local count = self:GenerateAllCommands() or 0;
	count = (self:GenerateAllItems() or 0)+ count;
	
	GameLogic.AddBBS(nil, "%d wiki pages generated", count);
	-- open directory. 
	GameLogic.RunCommand("open", "-d "..self.output_dir);
end

function WikiGen:GetUrlFromPageName(name)
	return self.baseurl..(name or "");
end

function WikiGen:LocalFilenameFromPageName(name)
	return self.output_dir..(name or "")..".md";
end

--@param output: array of strings
--@param content: default to ""
--@return autogen_code_index
function WikiGen:InjectContent(output, content)
	local autogen_code_index;
	output[#output+1] = "<!-- BEGIN_AUTOGEN: do NOT edit in this block -->\r\n";
	output[#output+1] = content or "";
	autogen_code_index = #output;
	output[#output+1] = "<!-- END_AUTOGEN-->\r\n";
	return autogen_code_index;
end

-- return array of text blocks and the index at which to insert autogenerated code. 
-- @return output, autogen_code_index
function WikiGen:GetAutoGenFileContent(filename)
	local output = {};
	local autogen_code_index;
	local file = ParaIO.open(filename, "r");
	if(file:IsValid()) then
		local text = file:GetText();
		local from_code, from_code_end = text:find("<!%-%-%s*BEGIN_AUTOGEN");
		if(from_code) then
			local to_code, to_code_end = text:find("<!%-%-%s*END_AUTOGEN[^\r\n]*[\r\n]+", from_code_end);
			if(to_code) then
				if(from_code>1) then
					output[#output+1] = text:sub(1, from_code-1);
				end
				autogen_code_index = self:InjectContent(output);
				output[#output+1] = text:sub(to_code_end+1, -1);
			end
		end
		if(not autogen_code_index) then
			autogen_code_index = self:InjectContent(output);
			output[#output+1] = text;
		end
		file:close();
	end
	if(not autogen_code_index) then
		autogen_code_index = self:InjectContent(output);
	end
	return output, autogen_code_index;
end

-- normalize with \r\n
function WikiGen:NormalizeLineEnding(text)
	return text:gsub("([^\r])[\n]", "%1\r\n");
end

-- @param text: string or array of strings
-- inject auto generated wiki context into wiki page. 
function WikiGen:SetAutoGenFileContent(pagename, text)
	if(not text) then
		return;
	elseif(type(text) == "table") then
		text = table.concat(text, "");
	end
	text = self:NormalizeLineEnding(text);

	local filename = self:LocalFilenameFromPageName(pagename);
	local output, autogen_code_index = self:GetAutoGenFileContent(filename);
	if(output) then
		output[autogen_code_index] = text;
		local file = ParaIO.open(filename, "w");
		if(file:IsValid()) then
			file:WriteString(table.concat(output, ""));
			file:close();
			LOG.std(nil, "info", "WikiGen", "%s generated to %s", pagename, filename);
			return true;
		end
	end
end

-- @return the number of pages generated
function WikiGen:GenerateAllCommands()
	-- table of content page
	local all_cmds = {};

	local cmds = SlashCommand.GetSingleton();
	for name, _ in pairs(CommandManager:GetCmdHelpDS()) do
		local cmd = cmds:GetSlashCommand(name);
		if(cmd) then
			local pagename = "cmd_"..cmd.name;
			local output = {};
			output[#output+1] = "\r\n";
			output[#output+1] = format("**command: `/%s`**\r\n\r\n", cmd.name);
			output[#output+1] = "**quick ref:**\r\n> ";
			output[#output+1] = cmd.quick_ref or "";
			output[#output+1] = "\r\n\r\n";
			output[#output+1] = "**description:**\r\n\r\n";
			output[#output+1] = "```\r\n";
			output[#output+1] = cmd.desc or "";
			output[#output+1] = "```\r\n\r\n";
			if(self:SetAutoGenFileContent(pagename, output)) then
				all_cmds[#all_cmds+1] = cmd.name:gsub("^/", "");
			end
		end
	end

	self:GenerateCommandsTOC(all_cmds);

	return #all_cmds;
end

-- gen table of content page
function WikiGen:GenerateCommandsTOC(all_cmds)
	table.sort(all_cmds);
	local output = {};
	output[#output+1] = "### All Commands List\r\n\r\n";
	local lastCapital;
	for _, name in ipairs(all_cmds) do
		local capital = name:sub(1, 1);
		if(not lastCapital or lastCapital ~= capital) then
			lastCapital = capital;
			output[#output+1] = format("\r\n\r\n> %s\r\n\r\n", string.upper(lastCapital));
		end
		output[#output+1] = format("[%s](cmd_%s) | ", name, name);
	end
	output[#output+1] = "\r\n";
	local pagename = "AllCommands";
	if(self:SetAutoGenFileContent(pagename, output)) then
		
	end
end

-- @return the number of pages generated
function WikiGen:GenerateAllItems()
	local count = 0;
	local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
	local ds_src = ItemClient.GetBlockDS("all");
			
	if(ds_src) then
		for name,category_ds in pairs(ds_src) do
			for index, item in ipairs(category_ds) do 
				local block_id = item.id;
				if(block_id) then
					local name = item.name;
					if(name) then
						local pagename = "item_"..name;
						local output = {};
						output[#output+1] = "\r\n";
						output[#output+1] = format("**item: `%s`**\r\n", item:GetDisplayName());
						output[#output+1] = "\r\n";
						output[#output+1] = format("> * **name: ** %s\r\n", name);
						output[#output+1] = format("> * **id: `%d`**\r\n", block_id);
						output[#output+1] = "\r\n";
--[[						
| name | id | desc |
|---|---|---|
| BlockModel | 254 | X |
]]

						local block = item:GetBlock();
						if(block) then
							-- TODO: show block attributes
						end
						if(self:SetAutoGenFileContent(pagename, output)) then
							count = count + 1;
						end
					end
				end
			end	
		end
	end
	self:GenerateItemsTOC();
	return count;
end

function WikiGen:GenerateItemsTOC()
	local ItemClient = commonlib.gettable("MyCompany.Aries.Game.Items.ItemClient");
	local ds_src = ItemClient.GetBlockDS("all");
	local output = {};
	output[#output+1] = "### All Items List\r\n\r\n";
	if(ds_src) then
		for name,category_ds in pairs(ds_src) do
			output[#output+1] = format("\r\n\r\n> %s\r\n\r\n", name);
			for index, item in ipairs(category_ds) do 
				local block_id = item.id;
				if(block_id) then
					local name = item.name;
					if(name) then
						output[#output+1] = format("[%d_%s](item_%s) | ", block_id, item:GetDisplayName(), name);
					end
				end
			end	
		end
	end
	output[#output+1] = "\r\n";
	local pagename = "AllItems";
	if(self:SetAutoGenFileContent(pagename, output)) then
	end
end
