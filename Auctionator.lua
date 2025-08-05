-- Auctionator.lua - part of Auctionator addon

AuctionatorVersion = "???";		-- set from toc upon loading
AuctionatorAuthor  = "Zirco";

local AuctionatorLoaded = false;
local AuctionatorInited = false;

local addonName, addonTable = ...; 
local zc = addonTable.zc;

gAtrZC = addonTable.zc;		-- share with AuctionatorDev

local gCurrentPane

-- Column descriptors used for building browse rows and headings
BROWSE_COLUMNS = {
  {name = "CurrentBid", width = 120, heading = "Bid"},
  {name = "PerItem",    width = 120, heading = "Buyout"},
  {name = "Quantity",   width = 90,  heading = "Quantity"},
  {name = "TimeLeft",   width = 60,  heading = "Time Left"},
  {name = "Owner",      width = 80,  heading = "Seller"},
}

local browseSortCol = "PerItem"
local browseSortAsc = true

local BROWSE_SORT_FUNCS = {
  CurrentBid = function(a) return a.nextBidPerItem or 0 end,
  PerItem    = function(a) return a.itemPrice end,
  Quantity   = function(a) return (a.count or 0) * (a.stackSize or 0) end,
  TimeLeft   = function(a) return a.timeLeft or 0 end,
  Owner      = function(a) return string.lower(a.owner or "") end,
}

function Atr_UpdateBrowseArrows()
  for _, col in ipairs(BROWSE_COLUMNS) do
    if col.button then
      local arrow = col.button:GetNormalTexture()
      if col.name == browseSortCol then
        arrow:Show()
        if browseSortAsc then
          arrow:SetTexCoord(0, 0.5625, 0, 1)
        else
          arrow:SetTexCoord(0, 0.5625, 1, 0)
        end
      else
        arrow:Hide()
      end
    end
  end
end

function Atr_HideAllColumns()
  for _, col in ipairs(BROWSE_COLUMNS) do
    if col.button then
      col.button:Hide()
    end
  end
end

function Atr_ShowAllColumns()
  for _, col in ipairs(BROWSE_COLUMNS) do
    if col.button then
      local text = ZT and ZT(col.heading) or col.heading
      col.button:SetText(text)
      col.button:Show()
    end
  end
end

function Atr_BuildBrowseHeaders(parent)
  local prev
  for _, col in ipairs(BROWSE_COLUMNS) do
    local button = CreateFrame("Button", "Atr_BrowseHeading"..col.name, parent, "Atr_Col_Heading_Template")
    button:SetSize(col.width, 20)
    local text = ZT and ZT(col.heading) or col.heading
    button:SetText(text)
    if prev then
      button:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
    else
      button:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -21)
    end
    button:SetScript("OnClick", function() Atr_SortBrowseColumn(col.name) end)
    col.button = button
    prev = button
  end
  Atr_ShowAllColumns()
  Atr_UpdateBrowseArrows()
end

function Atr_BuildBrowseEntry(row)
  local prev
  for _, col in ipairs(BROWSE_COLUMNS) do
    local frame = CreateFrame("Frame", row:GetName() .. "_" .. col.name, row)
    frame:SetSize(col.width, 16)
    if frame.SetClipsChildren then
      frame:SetClipsChildren(true)
    end
    if prev then
      frame:SetPoint("LEFT", prev, "RIGHT", 5, 0)
    else
      frame:SetPoint("LEFT", row, "LEFT", 0, 0)
    end

    if col.name == "CurrentBid" or col.name == "PerItem" then
      local price = CreateFrame("Frame", frame:GetName().."_Price", frame, "SmallMoneyFrameTemplate")
      price:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
      SmallMoneyFrame_OnLoad(price)
      MoneyFrame_SetType(price, "AUCTION")

      if col.name == "PerItem" then
        local text = frame:CreateFontString(frame:GetName().."_Text", "BACKGROUND", "GameFontDarkGraySmall")
        text:SetPoint("CENTER", frame, "CENTER", 0, 1)
        text:SetWidth(col.width)
        text:SetJustifyH("CENTER")
        text:SetWordWrap(false)
      end
    else
      local justify = "RIGHT"
      if col.name == "Owner" then
        justify = "CENTER"
      end
      local text = frame:CreateFontString(frame:GetName().."_Text", "BACKGROUND", "GameFontHighlightSmall")
      text:SetJustifyH(justify)
      text:SetPoint("RIGHT", frame, "RIGHT", 0, 1)
      text:SetWidth(col.width)
      text:SetWordWrap(false)
    end

    prev = frame
  end
end

function Atr_SortBrowseColumn(colName)
  local sorter = BROWSE_SORT_FUNCS[colName]
  if not sorter or not gCurrentPane or not gCurrentPane.activeScan then return end
  if browseSortCol == colName then
    browseSortAsc = not browseSortAsc
  else
    browseSortCol = colName
    browseSortAsc = true
  end
  table.sort(gCurrentPane.activeScan.sortedData, function(a, b)
    local av, bv = sorter(a), sorter(b)
    if av == bv then
      return a.itemPrice < b.itemPrice
    end
    if browseSortAsc then
      return av < bv
    else
      return av > bv
    end
  end)
  Atr_UpdateBrowseArrows()
  FauxScrollFrame_SetOffset(AuctionatorScrollFrame, 0)
  gCurrentPane.UINeedsUpdate = true
end

-----------------------------------------

local recommendElements			= {};

AUCTIONATOR_ENABLE_ALT		= 1;
AUCTIONATOR_OPEN_ALL_BAGS	= 1;
AUCTIONATOR_SHOW_ST_PRICE	= 0;
AUCTIONATOR_SHOW_TIPS		= 1;
AUCTIONATOR_DEF_DURATION	= "N";		-- none
AUCTIONATOR_V_TIPS			= 1;
AUCTIONATOR_A_TIPS			= 1;
AUCTIONATOR_D_TIPS			= 1;
AUCTIONATOR_SHIFT_TIPS		= 1;
AUCTIONATOR_DE_DETAILS_TIPS	= 4;		-- off by default
AUCTIONATOR_DEFTAB			= 1;
AUCTIONATOR_CACHE_THRESHOLD	= 300;		-- 5 minutes default cache

AUCTIONATOR_OPEN_FIRST		= 0;	-- obsolete - just needed for migration
AUCTIONATOR_OPEN_BUY		= 0;	-- obsolete - just needed for migration

local SELL_TAB		= 1;
local MORE_TAB		= 2;
local BUY_TAB 		= 3;

local MODE_LIST_ACTIVE	= 1;
local MODE_LIST_ALL		= 2;


-- saved variables - amounts to undercut

local auctionator_savedvars_defaults =
	{
	["_5000000"]			= 10000;	-- amount to undercut buyouts over 500 gold
	["_1000000"]			= 2500;
	["_200000"]				= 1000;
	["_50000"]				= 500;
	["_10000"]				= 200;
	["_2000"]				= 100;
	["_500"]				= 5;
	["STARTING_DISCOUNT"]	= 5;	-- PERCENT
	};


-----------------------------------------

local auctionator_orig_AuctionFrameTab_OnClick;
local auctionator_orig_ContainerFrameItemButton_OnClick;
local auctionator_orig_AuctionFrameAuctions_Update;
local auctionator_orig_CanShowRightUIPanel;
local auctionator_orig_ChatEdit_InsertLink;
local auctionator_orig_ChatFrame_OnEvent;
local auctionator_orig_FriendsFrame_OnEvent;

local gForceMsgAreaUpdate = true;
local gAtr_ClickAuctionSell = false;

local AUTO_SELL_OFF			= 0;
local AUTO_SELL_PREP		= 1;
local AUTO_SELL_WAITING		= 2;
local AUCTION_POST_PENDING	= 3;
local STACK_MERGE_PENDING	= 4;
local STACK_SPLIT_PENDING	= 5;

local gAutoSellState = AUTO_SELL_WAITING;

local gBS_ItemName;
local gBS_ItemLink;
local gBS_ItemFamily;
local gBS_GoodStackSize;
local gBS_FullStackSize;
local gBS_Buyout_StackPrice;
local gBS_Buyout_ItemPrice;
local gBS_Start_StackPrice;
local gBS_Start_ItemPrice;
local gBS_Hours;
local gBS_targetBS;
local gBS_targetCount;
local gBS_AuctionNum;
local gBS_NumAuctionsToCreate;
local gBS_TotalItems;

local gOpenAllBags  			= AUCTIONATOR_OPEN_ALL_BAGS;
local gTimeZero;
local gTimeTightZero;

local cslots = {};
local gEmptyBScached = nil;

local gAutoSingleton = 0;

local gJustPosted_ItemName = nil;		-- set to the last item posted, even after the posting so that message and icon can be displayed
local gJustPosted_ItemLink;
local gJustPosted_BuyoutPrice;
local gJustPosted_StackSize;
local gJustPosted_NumInBagsAtStart;
local gJustPosted_NumStacks;

local auctionator_pending_message = nil;

local kBagIDs = {};

local Atr_Confirm_Proc_Yes = nil;

local gStartingTime			= time();
local gHentryTryAgain		= nil;
local gCondensedThisSession = {};

local ITEM_HIST_NUM_LINES = 20;

local gActiveAuctions = {};

local gHlistNeedsUpdate = false;

local gSellPane;
local gMorePane;
local gActivePane;
local gShopPane;

local gHistoryItemList = {};

local ATR_CACT_NULL							= 0;
local ATR_CACT_READY						= 1;
local ATR_CACT_PROCESSING					= 2;
local ATR_CACT_WAITING_ON_CANCEL_CONFIRM	= 3;


local gItemPostingInProgress = false;
local gQuietWho = 0;
local gSendZoneMsgs = false;

gAtr_ptime = nil;		-- a more precise timer but may not be updated very frequently

gAtr_ScanDB			= nil;
gAtr_PriceHistDB	= nil;

-----------------------------------------

ATR_SK_GLYPHS		= "*_glyphs";
ATR_SK_GEMS_CUT		= "*_gemscut";
ATR_SK_GEMS_UNCUT	= "*_gemsuncut";
ATR_SK_ITEM_ENH		= "*_itemenh";
ATR_SK_POT_ELIX		= "*_potelix";
ATR_SK_FLASKS		= "*_flasks";
ATR_SK_HERBS		= "*_herbs";     

-----------------------------------------

local BS_GetCount, BS_InCslots, BS_GetEmptySlot, BS_PostAuction, BS_FindGoodStack, BS_MergeSmallStacks, BS_SplitLargeStack;

local roundPriceDown, ToTightTime, FromTightTime, monthDay;

-----------------------------------------

local function Atr_SetRowTextColor(row, r, g, b)
    local base = row:GetName()
    local fields = { "_EntryText", "_PerItem_Text",
                     "_Quantity_Text", "_TimeLeft_Text",
                     "_Owner_Text" }
    for _, suf in ipairs(fields) do
        local fs = _G[base .. suf]
        if fs then fs:SetTextColor(r, g, b) end
    end
end

-----------------------------------------

function Atr_RegisterEvents(self)

	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("ADDON_LOADED");
	self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE");
	self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE");
	self:RegisterEvent("AUCTION_MULTISELL_START");
	self:RegisterEvent("AUCTION_MULTISELL_UPDATE");
	self:RegisterEvent("AUCTION_HOUSE_SHOW");
	self:RegisterEvent("AUCTION_HOUSE_CLOSED");
	self:RegisterEvent("NEW_AUCTION_UPDATE");
	self:RegisterEvent("CHAT_MSG_ADDON");
	self:RegisterEvent("WHO_LIST_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
			
end

-----------------------------------------

function Atr_EventHandler()

--	zc.msg_dev (event);

	if (event == "VARIABLES_LOADED")			then	Atr_OnLoad(); 					end;
	if (event == "ADDON_LOADED")				then	Atr_OnAddonLoaded(); 			end;
	if (event == "AUCTION_ITEM_LIST_UPDATE")	then	Atr_OnAuctionUpdate(); 			end;
	if (event == "AUCTION_OWNED_LIST_UPDATE")	then	Atr_OnAuctionOwnedUpdate(); 	end;
	if (event == "AUCTION_MULTISELL_START")		then	Atr_OnAuctionMultiSellStart(); 	end;
	if (event == "AUCTION_MULTISELL_UPDATE")	then	Atr_OnAuctionMultiSellUpdate(); end;
	if (event == "AUCTION_HOUSE_SHOW")			then	Atr_OnAuctionHouseShow(); 		end;
	if (event == "AUCTION_HOUSE_CLOSED")		then	Atr_OnAuctionHouseClosed(); 	end;
	if (event == "NEW_AUCTION_UPDATE")			then	Atr_OnNewAuctionUpdate(); 		end;
	if (event == "CHAT_MSG_ADDON")				then	Atr_OnChatMsgAddon(); 			end;
	if (event == "WHO_LIST_UPDATE")				then	Atr_OnWhoListUpdate(); 			end;
	if (event == "PLAYER_ENTERING_WORLD")		then	Atr_OnPlayerEnteringWorld(); 	end;

end

-----------------------------------------

function Atr_SetupHookFunctionsEarly ()

	auctionator_orig_FriendsFrame_OnEvent = FriendsFrame_OnEvent;
	FriendsFrame_OnEvent = Atr_FriendsFrame_OnEvent;

	Atr_Hook_OnTooltipAddMoney ();
	
end


-----------------------------------------

function Atr_SetupHookFunctions ()

	auctionator_orig_AuctionFrameTab_OnClick = AuctionFrameTab_OnClick;
	AuctionFrameTab_OnClick = Atr_AuctionFrameTab_OnClick;

	auctionator_orig_ContainerFrameItemButton_OnModifiedClick = ContainerFrameItemButton_OnModifiedClick;
	ContainerFrameItemButton_OnModifiedClick = Atr_ContainerFrameItemButton_OnModifiedClick;

	auctionator_orig_AuctionFrameAuctions_Update = AuctionFrameAuctions_Update;
	AuctionFrameAuctions_Update = Atr_AuctionFrameAuctions_Update;

	auctionator_orig_CanShowRightUIPanel = CanShowRightUIPanel;
	CanShowRightUIPanel = auctionator_CanShowRightUIPanel;
	
	auctionator_orig_ChatEdit_InsertLink = ChatEdit_InsertLink;
	ChatEdit_InsertLink = auctionator_ChatEdit_InsertLink;
	
	auctionator_orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
	ChatFrame_OnEvent = auctionator_ChatFrame_OnEvent;
	
--	auctionator_orig_AuctionFrameBrowse_Update = AuctionFrameBrowse_Update;
--	AuctionFrameBrowse_Update = auctionator_AuctionFrameBrowse_Update;
end

-----------------------------------------

local gItemLinkCache = {};
local gA2IC_prevName = "";

-----------------------------------------

function Atr_AddToItemLinkCache (itemName, itemLink)

	if (itemName == gA2IC_prevName) then		-- for performance reasons only
		return;
	end

	gA2IC_prevName = itemName;

	gItemLinkCache[string.lower(itemName)] = itemLink;
end

-----------------------------------------

function Atr_GetItemLink (itemName)
	if (itemName == nil or itemName == "") then
		return nil;
	end
	
	local itemLink = gItemLinkCache[string.lower(itemName)];
	
	if (itemLink == nil) then
		_, itemLink = GetItemInfo (itemName);
		if (itemLink) then
			Atr_AddToItemLinkCache (itemName, itemLink);
		end
	end
	
	return itemLink;

end

-----------------------------------------

local checkVerString		= nil;
local versionReminderCalled	= false;	-- make sure we don't bug user more than once

-----------------------------------------

local function CheckVersion (verString)
	
	if (checkVerString == nil) then
		checkVerString = AuctionatorVersion;
	end
	
	local a,b,c = strsplit (".", verString);

	if (tonumber(a) == nil or tonumber(b) == nil or tonumber(c) == nil) then
		return false;
	end
	
	if (verString > checkVerString) then
		checkVerString = verString;
		return true;	-- out of date
	end
	
	return false;
end

-----------------------------------------

function Atr_VersionReminder ()
	if (not versionReminderCalled) then
		versionReminderCalled = true;

		zc.msg_atr (ZT("There is a more recent version of Auctionator: VERSION").." "..checkVerString);
	end
end



-----------------------------------------

local VREQ_sent = 0;

-----------------------------------------

function Atr_SendAddon_VREQ (type, target)

	VREQ_sent = time();
	
	SendAddonMessage ("ATR", "VREQ_"..AuctionatorVersion, type, target);
	
end

-----------------------------------------

function Atr_OnChatMsgAddon ()

	local	prefix			= arg1;
	local	msg				= arg2;
	local	distribution	= arg3;
	local	sender			= arg4;
	
--	local s = string.format ("%s %s |cff88ffff %s |cffffffaa %s|r", prefix, distribution, sender, msg);
--	zc.msg_dev (s);

	if (arg1 == "ATR") then
	
		if (zc.StringStartsWith (msg, "VREQ_")) then
			SendAddonMessage ("ATR", "V_"..AuctionatorVersion, "WHISPER", sender);
		end
		
		if (zc.StringStartsWith (msg, "V_") and time() - VREQ_sent < 5) then

			local herVerString = string.sub (msg, 3);
			zc.msg_dev ("version found:", herVerString, "   ", sender, "     delta", time() - VREQ_sent);
			local outOfDate = CheckVersion (herVerString);
			if (outOfDate) then
				zc.AddDeferredCall (3, "Atr_VersionReminder", nil, nil, "VR");
			end
		end
	end

	if (Atr_OnChatMsgAddon_Dev) then
		Atr_OnChatMsgAddon_Dev (prefix, msg, distribution, sender);
	end
	
end


-----------------------------------------

local function Atr_GetAuctionatorMemString(msg)

	UpdateAddOnMemoryUsage();
	
	local mem  = GetAddOnMemoryUsage("Auctionator");
	return string.format ("%6i KB", math.floor(mem));
end

-----------------------------------------

local function Atr_SlashCmdFunction(msg)

	local cmd, param1u, param2u, param3u = zc.words (msg);

	if (cmd == nil or type (cmd) ~= "string") then
		return;
	end
	
		  cmd    = cmd     and cmd:lower()    or nil;
	local param1 = param1u and param1u:lower() or nil;
	local param2 = param2u and param2u:lower() or nil;
	local param3 = param3u and param3u:lower() or nil;
	
	if (cmd == "mem") then

		UpdateAddOnMemoryUsage();
		
		for i = 1, GetNumAddOns() do
			local mem  = GetAddOnMemoryUsage(i);
			local name = GetAddOnInfo(i);
			if (mem > 0) then
				local s = string.format ("%6i KB   %s", math.floor(mem), name);
				zc.msg_yellow (s);
			end
		end
	
	elseif (cmd == "locale") then
		Atr_PickLocalizationTable (param1u);

	elseif (cmd == "clear") then
	
		zc.msg_atr ("memory usage: "..Atr_GetAuctionatorMemString());
		
		if (param1 == "fullscandb") then
			gAtr_ScanDB = nil;
			AUCTIONATOR_PRICE_DATABASE = nil;
			Atr_InitScanDB();
			zc.msg_atr (ZT("full scan database cleared"));
			
		elseif (param1 == "posthistory") then
			AUCTIONATOR_PRICING_HISTORY = {};
			zc.msg_atr (ZT("pricing history cleared"));
		end
		
		collectgarbage  ("collect");
		
		zc.msg_atr ("memory usage: "..Atr_GetAuctionatorMemString());

	elseif (Atr_HandleDevCommands and Atr_HandleDevCommands (cmd, param1, param2)) then
		-- do nothing
	else
		zc.msg_atr (ZT("unrecognized command"));
	end
	
end


-----------------------------------------

function Atr_InitScanDB()

	local realm_Faction = GetRealmName().."_"..UnitFactionGroup ("player");

	if (AUCTIONATOR_PRICE_DATABASE and AUCTIONATOR_PRICE_DATABASE["__dbversion"] == nil) then	-- see if we need to migrate
	
		local temp = zc.CopyDeep (AUCTIONATOR_PRICE_DATABASE);
		
		AUCTIONATOR_PRICE_DATABASE = {};
		AUCTIONATOR_PRICE_DATABASE["__dbversion"] = 2;
	
		AUCTIONATOR_PRICE_DATABASE[realm_Faction] = zc.CopyDeep (temp);
		
		temp = {};
	end

	if (AUCTIONATOR_PRICE_DATABASE == nil) then
		AUCTIONATOR_PRICE_DATABASE = {};
		AUCTIONATOR_PRICE_DATABASE["__dbversion"] = 2;
	end
	
	if (AUCTIONATOR_PRICE_DATABASE[realm_Faction] == nil) then
		AUCTIONATOR_PRICE_DATABASE[realm_Faction] = {};
	end

	gAtr_ScanDB = AUCTIONATOR_PRICE_DATABASE[realm_Faction];

end


-----------------------------------------

function Atr_OnLoad()

	AuctionatorVersion = GetAddOnMetadata("Auctionator", "Version");

	gTimeZero		= time({year=2000, month=1, day=1, hour=0});
	gTimeTightZero	= time({year=2008, month=8, day=1, hour=0});

	local x;
	for x = 0, NUM_BAG_SLOTS do
		kBagIDs[x+1] = x;
	end
	
	kBagIDs[NUM_BAG_SLOTS+2] = KEYRING_CONTAINER;

	AuctionatorLoaded = true;

	SlashCmdList["Auctionator"] = Atr_SlashCmdFunction;
	
	SLASH_Auctionator1 = "/auctionator";
	SLASH_Auctionator2 = "/atr";

	Atr_InitScanDB ();
	
	if (AUCTIONATOR_PRICING_HISTORY == nil) then	-- the old history of postings
		AUCTIONATOR_PRICING_HISTORY = {};
	end
	
	if (AUCTIONATOR_TOONS == nil) then
		AUCTIONATOR_TOONS = {};
	end

	if (AUCTIONATOR_STACKING_PREFS == nil) then
		Atr_StackingPrefs_Init();
	end


	local playerName = UnitName("player");

	if (not AUCTIONATOR_TOONS[playerName]) then
		AUCTIONATOR_TOONS[playerName] = {};
		AUCTIONATOR_TOONS[playerName].firstSeen		= time();
		AUCTIONATOR_TOONS[playerName].firstVersion	= AuctionatorVersion;
	end

	AUCTIONATOR_TOONS[playerName].guid = UnitGUID ("player");

	if (AUCTIONATOR_SCAN_MINLEVEL == nil) then
		AUCTIONATOR_SCAN_MINLEVEL = 1;			-- poor (all) items
	end
	
	if (AUCTIONATOR_SHOW_TIPS == 0) then		-- migrate old option to new ones
		AUCTIONATOR_V_TIPS = 0;
		AUCTIONATOR_A_TIPS = 0;
		AUCTIONATOR_D_TIPS = 0;
		
		AUCTIONATOR_SHOW_TIPS = 2;
	end

	if (AUCTIONATOR_OPEN_FIRST < 2) then	-- set to 2 to indicate it's been migrated
		if		(AUCTIONATOR_OPEN_FIRST == 1)	then AUCTIONATOR_DEFTAB = 1;
		elseif	(AUCTIONATOR_OPEN_BUY == 1)		then AUCTIONATOR_DEFTAB = 2;
		else										 AUCTIONATOR_DEFTAB = 0; end;
	
		AUCTIONATOR_OPEN_FIRST = 2;
	end


	Atr_SetupHookFunctionsEarly();

	------------------

	CreateFrame( "GameTooltip", "AtrScanningTooltip" ); -- Tooltip name cannot be nil
	AtrScanningTooltip:SetOwner( WorldFrame, "ANCHOR_NONE" );
	-- Allow tooltip SetX() methods to dynamically add new lines based on these
	AtrScanningTooltip:AddFontStrings(
	AtrScanningTooltip:CreateFontString( "$parentTextLeft1", nil, "GameTooltipText" ),
	AtrScanningTooltip:CreateFontString( "$parentTextRight1", nil, "GameTooltipText" ) );

	------------------

	Atr_InitDETable();

	if ( IsAddOnLoaded("Blizzard_AuctionUI") ) then		-- need this for AH_QuickSearch since that mod forces Blizzard_AuctionUI to load at a startup
		Atr_Init();
	end

	

end

-----------------------------------------

local gPrevTime = 0;

function Atr_OnAddonLoaded()

	local addonName = arg1;

	if (zc.StringSame (addonName, "blizzard_auctionui")) then
		Atr_Init();
	end

	if (zc.StringSame (addonName, "lilsparkysWorkshop")) then

		local LSW_version = GetAddOnMetadata("lilsparkysWorkshop", "Version");

		if (LSW_version and (LSW_version == "0.72" or LSW_version == "0.90" or LSW_version == "0.91")) then

			if (LSW_itemPrice) then
				zc.msg ("** |cff00ffff"..ZT("Auctionator provided an auction module to LilSparky's Workshop."), 0, 1, 0);
				zc.msg ("** |cff00ffff"..ZT("Ignore any ERROR message to the contrary below."), 0, 1, 0);
				LSW_itemPrice = Atr_LSW_itemPriceGetAuctionBuyout;
			end
		end
	end

	Atr_Check_For_Conflicts (addonName);

	local now = time();

--	zc.msg_red (addonName.."   time: "..now - gStartingTime);

	gPrevTime = now;

end


-----------------------------------------

function Atr_OnPlayerEnteringWorld()

	Atr_InitOptionsPanels();

--	Atr_MakeOptionsFrameOpaque();
end

-----------------------------------------

function Atr_LSW_itemPriceGetAuctionBuyout(link)

    sellPrice = Atr_GetAuctionBuyout(link)
    if sellPrice then
        return sellPrice, false
    else
        return 0, true
    end
 end
 
-----------------------------------------

function Atr_Init()

	if (AuctionatorInited) then
		return;
	end

--	zc.msg("Auctionator Initialized");

	AuctionatorInited = true;

	if (AUCTIONATOR_SAVEDVARS == nil) then
		Atr_ResetSavedVars();
	end


	if (AUCTIONATOR_SHOPPING_LISTS == nil) then
		AUCTIONATOR_SHOPPING_LISTS = {};
		Atr_SList.create (ZT("Recent Searches"), true);

		if (zc.IsEnglishLocale()) then
			local slist = Atr_SList.create ("Sample Shopping List #1");
			slist:AddItem ("Greater Cosmic Essence");
			slist:AddItem ("Infinite Dust");
			slist:AddItem ("Dream Shard");
			slist:AddItem ("Abyss Crystal");
		end
	else
		Atr_ShoppingListsInit();
	end

	gShopPane	= Atr_AddSellTab (ZT("Buy"),			BUY_TAB);
	gSellPane	= Atr_AddSellTab (ZT("Sell"),			SELL_TAB);
	gMorePane	= Atr_AddSellTab (ZT("More").."...",	MORE_TAB);

	Atr_AddMainPanel ();

	Atr_SetupHookFunctions ();

	recommendElements[1] = getglobal ("Atr_Recommend_Text");
	recommendElements[2] = getglobal ("Atr_RecommendPerItem_Text");
	recommendElements[3] = getglobal ("Atr_RecommendPerItem_Price");
	recommendElements[4] = getglobal ("Atr_RecommendPerStack_Text");
	recommendElements[5] = getglobal ("Atr_RecommendPerStack_Price");
	recommendElements[6] = getglobal ("Atr_Recommend_Basis_Text");
	recommendElements[7] = getglobal ("Atr_RecommendItem_Tex");
	
	-- Initialize cache age display as hidden
	if (Atr_CacheAge_Text) then
		Atr_CacheAge_Text:Hide();
	end
	
	-- Initialize debug messages array
	if (not AtrL["Debug messages"]) then
		AtrL["Debug messages"] = {};
	end
	
	-- Create refresh button programmatically for better control
	if (not Atr_RefreshButton_Custom) then
		local button = CreateFrame("Button", "Atr_RefreshButton_Custom", Atr_Main_Panel, "UIPanelButtonTemplate");
		button:SetSize(60, 16);
		button:SetPoint("TOPLEFT", Atr_Recommend_Text, "TOPLEFT", 160, -17);
		button:SetText(ZT("Refresh"));
		button:EnableMouse(true);
		button:SetFrameLevel(Atr_Main_Panel:GetFrameLevel() + 10); -- Higher z-order
		
		button:SetScript("OnClick", function()
			table.insert(AtrL["Debug messages"], "CUSTOM button clicked!");
			Atr_Refresh_OnClick();
		end);
		
		button:SetScript("OnEnter", function(self)
			table.insert(AtrL["Debug messages"], "CUSTOM button mouse enter");
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText("Принудительно обновить данные");
			GameTooltip:Show();
		end);
		
		button:SetScript("OnLeave", function()
			table.insert(AtrL["Debug messages"], "CUSTOM button mouse leave");
			GameTooltip:Hide();
		end);
		
		button:Hide(); -- Initially hidden
		table.insert(AtrL["Debug messages"], "Custom refresh button created successfully");
	end

	-- create the lines that appear in the item history scroll pane

	local line, n;

	for n = 1, ITEM_HIST_NUM_LINES do
		local y = -5 - ((n-1)*16);
		line = CreateFrame("BUTTON", "AuctionatorHEntry"..n, Atr_Hlist, "Atr_HEntryTemplate");
		line:SetPoint("TOPLEFT", 0, y);
	end

	Atr_ShowHide_StartingPrice();
	
	Atr_LocalizeFrames();

end

-----------------------------------------

function Atr_ShowHide_StartingPrice()

	if (AUCTIONATOR_SHOW_ST_PRICE == 1) then
		Atr_StartingPriceText:Show();
		Atr_StartingPrice:Show();
		Atr_StartingPriceDiscountText:Hide();
		Atr_Duration_Text:SetPoint ("TOPLEFT", 10, -307);
	else
		Atr_StartingPriceText:Hide();
		Atr_StartingPrice:Hide();
		Atr_StartingPriceDiscountText:Show();
		Atr_Duration_Text:SetPoint ("TOPLEFT", 10, -304);
	end
end


-----------------------------------------

function Atr_GetSellItemInfo ()

	local auctionItemName, auctionTexture, auctionCount = GetAuctionSellItemInfo();

	if (auctionItemName == nil) then
		auctionItemName = "";
		auctionCount	= 0;
	end

	local auctionItemLink = nil;

	-- only way to get sell itemlink that I can figure

	if (auctionItemName ~= "") then
		AtrScanningTooltip:SetAuctionSellItem();
		local name;
		name, auctionItemLink = AtrScanningTooltip:GetItem();

		if (auctionItemLink == nil) then
			return "",0,nil;
		else
			Atr_AddToItemLinkCache (auctionItemName, auctionItemLink);
		end

	end

	return auctionItemName, auctionCount, auctionItemLink;

end


-----------------------------------------

function Atr_ResetSavedVars ()
	AUCTIONATOR_SAVEDVARS = zc.CopyDeep (auctionator_savedvars_defaults);
end


--------------------------------------------------------------------------------
-- don't reference these directly; use the function below instead

local _AUCTIONATOR_SELL_TAB_INDEX = 0;
local _AUCTIONATOR_MORE_TAB_INDEX = 0;
local _AUCTIONATOR_BUY_TAB_INDEX = 0;

--------------------------------------------------------------------------------

function Atr_FindTabIndex (whichTab)

	if (_AUCTIONATOR_SELL_TAB_INDEX == 0) then

		local i = 4;
		while (true)  do
			local tab = getglobal('AuctionFrameTab'..i);
			if (tab == nil) then
				break;
			end

			if (tab.auctionatorTab) then
				if (tab.auctionatorTab == SELL_TAB)		then _AUCTIONATOR_SELL_TAB_INDEX = i; end;
				if (tab.auctionatorTab == MORE_TAB)		then _AUCTIONATOR_MORE_TAB_INDEX = i; end;
				if (tab.auctionatorTab == BUY_TAB)		then _AUCTIONATOR_BUY_TAB_INDEX = i; end;
			end

			i = i + 1;
		end
	end

	if (whichTab == SELL_TAB)	then return _AUCTIONATOR_SELL_TAB_INDEX ; end;
	if (whichTab == MORE_TAB)	then return _AUCTIONATOR_MORE_TAB_INDEX; end;
	if (whichTab == BUY_TAB)	then return _AUCTIONATOR_BUY_TAB_INDEX; end;

	return 0;
end


-----------------------------------------


function Atr_AuctionFrameTab_OnClick (self, index, down)

	if ( index == nil or type(index) == "string") then
		index = self:GetID();
	end

	getglobal("Atr_Main_Panel"):Hide();

	gBuyState = ATR_BUY_NULL;			-- just in case
	gItemPostingInProgress = false;		-- just in case
	
	auctionator_orig_AuctionFrameTab_OnClick (self, index, down);

	if (not Atr_IsAuctionatorTab(index)) then
		gForceMsgAreaUpdate = true;
		Atr_HideAllDialogs();
		AuctionFrameMoneyFrame:Show();
		gAutoSellState = AUTO_SELL_OFF;

		if (AP_Bid_MoneyFrame) then		-- for the addon 'Auction Profit'
			if (AP_ShowBid)	then	AP_ShowHide_Bid_Button(1);	end;
			if (AP_ShowBO)	then	AP_ShowHide_BO_Button(1);	end;
		end


	elseif (Atr_IsAuctionatorTab(index)) then
	
		AuctionFrameAuctions:Hide();
		AuctionFrameBrowse:Hide();
		AuctionFrameBid:Hide();
		PlaySound("igCharacterInfoTab");

		PanelTemplates_SetTab(AuctionFrame, index);

--		AuctionFrameTopLeft:SetTexture	("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopLeft");
		AuctionFrameTopLeft:SetTexture	("Interface\\AddOns\\Auctionator\\Images\\Atr_topleft");
		AuctionFrameBotLeft:SetTexture	("Interface\\AddOns\\Auctionator\\Images\\Atr_botleft");
		AuctionFrameTop:SetTexture		("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Top");
		AuctionFrameTopRight:SetTexture	("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-TopRight");
		AuctionFrameBot:SetTexture		("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-Bot");
		AuctionFrameBotRight:SetTexture	("Interface\\AuctionFrame\\UI-AuctionFrame-Auction-BotRight");

		if (index == Atr_FindTabIndex(SELL_TAB))	then gCurrentPane = gSellPane; end;
		if (index == Atr_FindTabIndex(BUY_TAB))		then gCurrentPane = gShopPane; end;
		if (index == Atr_FindTabIndex(MORE_TAB))	then gCurrentPane = gMorePane; end;

		if (index == Atr_FindTabIndex(SELL_TAB))	then AuctionatorTitle:SetText ("Auctionator - "..ZT("Sell"));			end;
		if (index == Atr_FindTabIndex(BUY_TAB))		then AuctionatorTitle:SetText ("Auctionator - "..ZT("Buy"));			end;
		if (index == Atr_FindTabIndex(MORE_TAB))	then AuctionatorTitle:SetText ("Auctionator - "..ZT("More").."...");	end;

		Atr_ClearHlist();
		Atr_SellControls:Hide();
		Atr_Hlist:Hide();
		Atr_Hlist_ScrollFrame:Hide();
		Atr_Search_Box:Hide();
		Atr_Search_Button:Hide();
		Atr_AddToSListButton:Hide();
		Atr_RemFromSListButton:Hide();
		Atr_NewSListButton:Hide();
		Atr_DelSListButton:Hide();
		Atr_DropDown1:Hide();
		Atr_DropDownSL:Hide();
		Atr_CheckActiveButton:Hide();
		Atr_Back_Button:Hide()
		
		AuctionFrameMoneyFrame:Hide();
		
		if (index == Atr_FindTabIndex(SELL_TAB)) then
			Atr_SellControls:Show();
		else
			Atr_Hlist:Show();
			Atr_Hlist_ScrollFrame:Show();
			if (gJustPosted_ItemName) then
				gJustPosted_ItemName = nil;
				gSellPane:ClearSearch ();
			end
		end


		if (index == Atr_FindTabIndex(MORE_TAB)) then
			FauxScrollFrame_SetOffset (Atr_Hlist_ScrollFrame, gCurrentPane.hlistScrollOffset);
			Atr_DisplayHlist();
			Atr_DropDown1:Show();
			
			if (UIDropDownMenu_GetSelectedValue(Atr_DropDown1) == MODE_LIST_ACTIVE) then
				Atr_CheckActiveButton:Show();
			end
		end
		
		
		if (index == Atr_FindTabIndex(BUY_TAB)) then
			Atr_Search_Box:Show();
			Atr_Search_Button:Show();
			AuctionFrameMoneyFrame:Show();
			Atr_BuildGlobalHistoryList(true);
			Atr_AddToSListButton:Show();
			Atr_RemFromSListButton:Show();
			Atr_NewSListButton:Show();
			Atr_DelSListButton:Show();
			Atr_DropDownSL:Show();
			Atr_Hlist:SetHeight (252);
			Atr_Hlist_ScrollFrame:SetHeight (252);
		else
			Atr_Hlist:SetHeight (335);
			Atr_Hlist_ScrollFrame:SetHeight (335);
		end

		if (index == Atr_FindTabIndex(BUY_TAB) or index == Atr_FindTabIndex(SELL_TAB)) then
			Atr_Buy1_Button:Show();
			Atr_Buy1_Button:Disable();
		end

		Atr_HideElems (recommendElements);

		getglobal("Atr_Main_Panel"):Show();

		gCurrentPane.UINeedsUpdate = true;

		if (gOpenAllBags == 1) then
			OpenAllBags(true);
			gOpenAllBags = 0;
		end

	end

end

-----------------------------------------

function Atr_StackSize ()
	return Atr_Batch_Stacksize:GetNumber();
end

-----------------------------------------

function Atr_SetStackSize (n)
	return Atr_Batch_Stacksize:SetText(n);
end

-----------------------------------------

function Atr_SelectPane (whichTab)

	local index = Atr_FindTabIndex(whichTab);
	local tab   = getglobal('AuctionFrameTab'..index);
	
	Atr_AuctionFrameTab_OnClick (tab, index);

end

-----------------------------------------

function Atr_IsModeCreateAuction ()
	return (Atr_IsTabSelected(SELL_TAB));
end


-----------------------------------------

function Atr_IsModeBuy ()
	return (Atr_IsTabSelected(BUY_TAB));
end

-----------------------------------------

function Atr_IsModeActiveAuctions ()
	return (Atr_IsTabSelected(MORE_TAB) and UIDropDownMenu_GetSelectedValue(Atr_DropDown1) == MODE_LIST_ACTIVE);
end

-----------------------------------------

function Atr_ClickAuctionSellItemButton (self, button)

	gAtr_ClickAuctionSell = true;
	ClickAuctionSellItemButton(self, button);
end


-----------------------------------------

function Atr_OnDropItem (self, button)

	if (GetCursorInfo() ~= "item") then
		return;
	end

	if (not Atr_IsTabSelected(SELL_TAB)) then
		Atr_SelectPane (SELL_TAB);		-- then fall through
	end
	
	Atr_ClickAuctionSellItemButton (self, button);
	ClearCursor();
end

-----------------------------------------

function Atr_SellItemButton_OnClick (self, button, ...)

	Atr_ClickAuctionSellItemButton (self, button);
end

-----------------------------------------

function Atr_SellItemButton_OnEvent (self, event, ...)

	if ( event == "NEW_AUCTION_UPDATE") then
		local name, texture, count, quality, canUse, price = GetAuctionSellItemInfo();
		Atr_SellControls_Tex:SetNormalTexture(texture);
	end
	
end

-----------------------------------------

function Atr_ContainerFrameItemButton_OnModifiedClick (self, button)

	if (AUCTIONATOR_ENABLE_ALT ~= 0 and	AuctionFrame:IsShown() and IsAltKeyDown()) then
	
		local bagID  = this:GetParent():GetID();
		local slotID = this:GetID();

		if (not Atr_IsTabSelected(SELL_TAB)) then
			Atr_SelectPane (SELL_TAB);
		end

		if (IsControlKeyDown()) then
			gAutoSingleton = time();
		end

		PickupContainerItem(bagID, slotID);

		local infoType = GetCursorInfo()

		if (infoType == "item") then
			Atr_ClearAll();
			Atr_ClickAuctionSellItemButton ();
			ClearCursor();
		end

		return;
	end
	
	return auctionator_orig_ContainerFrameItemButton_OnModifiedClick (self, button);

end




-----------------------------------------

function BeginAutoSell ()

	gJustPosted_ItemName			= gCurrentPane.activeScan.itemName;
	gJustPosted_ItemLink			= gCurrentPane.activeScan.itemLink;
	gJustPosted_BuyoutPrice			= MoneyInputFrame_GetCopper(Atr_StackPrice);
	gJustPosted_StackSize			= Atr_StackSize();
	gJustPosted_NumInBagsAtStart	= Atr_GetNumItemInBags(gJustPosted_ItemName);
	gJustPosted_NumStacks			= Atr_Batch_NumAuctions:GetNumber();

	
	local duration				= UIDropDownMenu_GetSelectedValue(Atr_Duration);
	local stackStartingPrice	= MoneyInputFrame_GetCopper(Atr_StartingPrice);
	local stackBuyoutPrice		= MoneyInputFrame_GetCopper(Atr_StackPrice);
	local numStacks				= Atr_Batch_NumAuctions:GetNumber();
	
	StartAuction (stackStartingPrice, stackBuyoutPrice, duration, gJustPosted_StackSize, gJustPosted_NumStacks);
end

-----------------------------------------

function BeginAutoSell_Old ()

	gBS_GoodStackSize		= Atr_StackSize();
	gBS_FullStackSize		= gCurrentPane.fullStackSize;
	gBS_ItemName			= gCurrentPane.activeScan.itemName;
	gBS_ItemLink			= gCurrentPane.activeScan.itemLink;

	gBS_ItemFamily			= GetItemFamily (gBS_ItemLink);
	gBS_Buyout_StackPrice	= MoneyInputFrame_GetCopper(Atr_StackPrice);
	gBS_Start_StackPrice	= MoneyInputFrame_GetCopper(Atr_StartingPrice);
	gBS_Hours				= UIDropDownMenu_GetSelectedValue(Atr_Duration);
	gBS_NumAuctionsToCreate	= Atr_Batch_NumAuctions:GetNumber();

	local maxStacks = math.floor (gCurrentPane.totalItems / gBS_GoodStackSize);

	if (gBS_NumAuctionsToCreate > maxStacks) then
		Atr_Error_Display (string.format (ZT("You can create at most %d auctions"), maxStacks));
		return;
	end

	if (Atr_StackSize() > gBS_FullStackSize) then
		Atr_Error_Display (string.format (ZT("You can stack at most %d of these items"), gBS_FullStackSize));
		return;
	end

	if (Atr_StackSize() == 1 and gBS_FullStackSize > 1) then

		local scan = gCurrentPane.activeScan;
		
		if (scan and scan.numYourSingletons + gBS_NumAuctionsToCreate > 40) then
			local s = ZT("You may have at most 40 single-stack (x1)\nauctions posted for this item.\n\nYou already have %d such auctions and\nyou are trying to post %d more.");
			Atr_Error_Display (string.format (s, scan.numYourSingletons, gBS_NumAuctionsToCreate));
			return;
		end
	end

	Atr_Memorize_Stacking_If ();	-- if changed

	gAutoSellState = AUTO_SELL_PREP;	-- must come before potential ClickAuctionSellItemButton

	local _, _, auctionCount = GetAuctionSellItemInfo();

	if (gBS_GoodStackSize ~= auctionCount) then		-- she changed the stacksize
		ClearCursor();
		Atr_ClickAuctionSellItemButton ();
		ClearCursor();
	end

	gJustPosted_ItemName	= gBS_ItemName;
	gJustPosted_BuyoutPrice	= gBS_Buyout_StackPrice;
	gJustPosted_StackSize	= gBS_GoodStackSize;
	gJustPosted_ItemLink	= gBS_ItemLink;

	local b, bagID, slotID, numslots;

	-- build a table of all the slots that contain the item

	cslots			= {};
	gEmptyBScached	= nil;

	for b = 1, #kBagIDs do
		bagID = kBagIDs[b];
		numslots = GetContainerNumSlots (bagID);
		for slotID = 1,numslots do
			local itemLink = GetContainerItemLink(bagID, slotID);
			if (itemLink) then
				local itemName = GetItemInfo(itemLink);
				if (itemName == gBS_ItemName) then
					local bs = {};
					bs.bagID  = bagID;
					bs.slotID = slotID;
					tinsert (cslots, bs);
				end
			end
		end
	end

	-- get it going (see the idle loop)

	gAutoSellState	= AUTO_SELL_WAITING;
	gBS_AuctionNum	= 1;
end


-----------------------------------------

local function AutoSell_InProgress()

	return (gAutoSellState ~= AUTO_SELL_OFF);
end

-----------------------------------------

function Atr_AuctionFrameAuctions_Update()

	auctionator_orig_AuctionFrameAuctions_Update();

end


-----------------------------------------

function Atr_LogMsg (itemlink, itemcount, price, numstacks)

	local logmsg = string.format (ZT("Auction created for %s"), itemlink);
	
	if (numstacks > 1) then
		logmsg = string.format (ZT("%d auctions created for %s"), numstacks, itemlink);
	end
	
	
	if (itemcount > 1) then
		logmsg = logmsg.."|cff00ddddx"..itemcount.."|r";
	end

	logmsg = logmsg.."   "..zc.priceToString(price);

	if (numstacks > 1 and itemcount > 1) then
		logmsg = logmsg.."  per stack";
	end
	

	zc.msg_yellow (logmsg);

end

-----------------------------------------

function Atr_OnAuctionOwnedUpdate ()

	gItemPostingInProgress = false;

	if (Atr_IsModeActiveAuctions()) then
		gHlistNeedsUpdate = true;
	end

	-- if (not Atr_IsTabSelected()) then
	-- 	Atr_ClearScanCache();		-- if not our tab, we have no idea what happened so must flush all caches
	-- 	return;
	-- end;

	gActiveAuctions = {};		-- always flush this cache

	if (AutoSell_InProgress()) then

zc.msg_dev ("AutoSell_InProgress");
	
		if (gAutoSellState == AUCTION_POST_PENDING) then
			gAutoSellState = AUTO_SELL_WAITING;
			gBS_AuctionNum = gBS_AuctionNum + 1;
		end

		local s = string.format (ZT("Auction #%d created for %s"), gBS_AuctionNum-1, gBS_ItemName);
		Atr_Recommend_Text:SetText (s);
		MoneyFrame_Update ("Atr_RecommendPerStack_Price", gBS_Buyout_StackPrice);
		Atr_SetTextureButton ("Atr_RecommendItem_Tex", gBS_GoodStackSize, gCurrentPane.activeScan.itemLink);

		Atr_LogMsg (gBS_ItemLink, gBS_GoodStackSize, gBS_Buyout_StackPrice);

		if (gBS_AuctionNum-1 == gBS_NumAuctionsToCreate) then
			Atr_AddHistoricalPrice (gBS_ItemName, gBS_Buyout_StackPrice / gBS_GoodStackSize, gBS_GoodStackSize, gBS_ItemLink);

			Atr_AddToScan (gBS_ItemName, gBS_GoodStackSize, gBS_Buyout_StackPrice, gBS_NumAuctionsToCreate);

			gJustPosted_ItemName = gBS_ItemName;

			gAutoSellState = AUTO_SELL_OFF;
			Atr_OnNewAuctionUpdate ();  -- been surpressing this during autoselling - need to call now
		else
			Atr_RedisplayAuctions();
		end

	elseif (gJustPosted_ItemName) then

		if (gJustPosted_NumStacks == 1) then
			Atr_LogMsg (gJustPosted_ItemLink, gJustPosted_StackSize, gJustPosted_BuyoutPrice, 1);
			Atr_AddHistoricalPrice (gJustPosted_ItemName, gJustPosted_BuyoutPrice / gJustPosted_StackSize, gJustPosted_StackSize, gJustPosted_ItemLink);
			Atr_AddToScan (gJustPosted_ItemName, gJustPosted_StackSize, gJustPosted_BuyoutPrice, 1);
		end
	end

	
end

-----------------------------------------

local gMS_stacksDelta;

-----------------------------------------

function Atr_OnAuctionMultiSellStart()

	gMS_stacksPrev = 0;

end

-----------------------------------------

function Atr_OnAuctionMultiSellUpdate()
	local stacksSoFar  = arg1;
	local stacksTotal  = arg2;
	
	local delta = stacksSoFar - gMS_stacksPrev;

--zc.msg_dev ("stacksSoFar: ", stacksSoFar, "stacksTotal: ", stacksTotal, "delta: ", delta);
	
	gMS_stacksPrev = stacksSoFar;
	
	Atr_AddToScan (gJustPosted_ItemName, gJustPosted_StackSize, gJustPosted_BuyoutPrice, delta);
	
	if (stacksSoFar == stacksTotal) then
		Atr_LogMsg (gJustPosted_ItemLink, gJustPosted_StackSize, gJustPosted_BuyoutPrice, stacksTotal);
		Atr_AddHistoricalPrice (gJustPosted_ItemName, gJustPosted_BuyoutPrice / gJustPosted_StackSize, gJustPosted_StackSize, gJustPosted_ItemLink);
	end
	
end

-----------------------------------------

function Atr_ResetDuration()

--	Atr_Duration_Initialize();	-- have to initialize or text doesn't get set (seems like a bug to me)

	if (AUCTIONATOR_DEF_DURATION == "S") then UIDropDownMenu_SetSelectedValue(Atr_Duration, 1); end;
	if (AUCTIONATOR_DEF_DURATION == "M") then UIDropDownMenu_SetSelectedValue(Atr_Duration, 2); end;
	if (AUCTIONATOR_DEF_DURATION == "L") then UIDropDownMenu_SetSelectedValue(Atr_Duration, 3); end;

end

-----------------------------------------

function Atr_AddToScan (itemName, stackSize, buyoutPrice, numAuctions)

	local scan = Atr_FindScan (itemName);

	scan:AddScanItem (itemName, stackSize, buyoutPrice, UnitName("player"), numAuctions);

	scan:CondenseAndSort ();

	gCurrentPane.UINeedsUpdate = true;
end

-----------------------------------------

function AuctionatorSubtractFromScan (itemName, stackSize, buyoutPrice, howMany)

	if (howMany == nil) then
		howMany = 1;
	end
	
	local scan = Atr_FindScan (itemName);

	local x;
	for x = 1, howMany do
		scan:SubtractScanItem (itemName, stackSize, buyoutPrice);
	end
	
	scan:CondenseAndSort ();

	gCurrentPane.UINeedsUpdate = true;
end


-----------------------------------------

function auctionator_ChatEdit_InsertLink(text)

	if (AuctionFrame:IsShown() and IsShiftKeyDown() and Atr_IsTabSelected(BUY_TAB)) then	
		local item;
		if ( strfind(text, "item:", 1, true) ) then
			item = GetItemInfo(text);
		end
		if ( item ) then
			Atr_Search_Box:SetText (item);
			Atr_Search_Onclick ();
			return true;
		end
	end

	return auctionator_orig_ChatEdit_InsertLink(text);

end

-----------------------------------------

function auctionator_ChatFrame_OnEvent(self, event, ...)

	if (event == "CHAT_MSG_SYSTEM") then
		if (arg1 == ERR_AUCTION_STARTED) then		-- absorb the Auction Created message
			return;
		end
		if (arg1 == ERR_AUCTION_REMOVED) then		-- absorb the Auction Created message
			return;
		end
	end

	return auctionator_orig_ChatFrame_OnEvent (self, event, ...);

end




-----------------------------------------

function auctionator_CanShowRightUIPanel(frame)

	if (zc.StringSame (frame:GetName(), "TradeSkillFrame")) then
		return 1;
	end;

	return auctionator_orig_CanShowRightUIPanel(frame);

end

-----------------------------------------

function Atr_AddMainPanel ()

	local frame = CreateFrame("FRAME", "Atr_Main_Panel", AuctionFrame, "Atr_Sell_Template");
	frame:EnableMouse(true);
	frame:Hide();

	UIDropDownMenu_SetWidth (Atr_DropDownSL, 150);
	UIDropDownMenu_JustifyText (Atr_DropDownSL, "CENTER");
	
	UIDropDownMenu_SetWidth (Atr_Duration, 95);

end

-----------------------------------------

function Atr_AddSellTab (tabtext, whichTab)

	local n = AuctionFrame.numTabs+1;

	local framename = "AuctionFrameTab"..n;

	local frame = CreateFrame("Button", framename, AuctionFrame, "AuctionTabTemplate");

	frame:SetID(n);
	frame:SetText(tabtext);

	frame:SetNormalFontObject(getglobal("AtrFontOrange"));

	frame.auctionatorTab = whichTab;

	frame:SetPoint("LEFT", getglobal("AuctionFrameTab"..n-1), "RIGHT", -8, 0);

	PanelTemplates_SetNumTabs (AuctionFrame, n);
	PanelTemplates_EnableTab  (AuctionFrame, n);
	
	return AtrPane.create (whichTab);
end

-----------------------------------------

function Atr_HideElems (tt)

	if (not tt) then
		return;
	end

	for i,x in ipairs(tt) do
		x:Hide();
	end
end

-----------------------------------------

function Atr_ShowElems (tt)

	for i,x in ipairs(tt) do
		x:Show();
	end
end




-----------------------------------------

function Atr_OnAuctionUpdate ()

	if (gAtr_FullScanState == ATR_FS_STARTED) then
		Atr_FullScanAnalyze();
		return;
	end

	-- if (not Atr_IsTabSelected()) then
	-- 	Atr_ClearScanCache();		-- if not our tab, we have no idea what happened so must flush all caches
	-- 	return;
	-- end;

	if (Atr_Buy_OnAuctionUpdate()) then
		return;
	end

	if (gCurrentPane.activeSearch and gCurrentPane.activeSearch.processing_state == KM_POSTQUERY) then

		local isDup = gCurrentPane.activeSearch:CheckForDuplicatePage ();
		
		if (not isDup) then

			local done = gCurrentPane.activeSearch:AnalyzeResultsPage();

			if (done) then
				gCurrentPane.activeSearch:Finish();
				Atr_OnSearchComplete ();
			end
		end
	end

end

-----------------------------------------

function Atr_OnSearchComplete ()

	gCurrentPane.sortedHist = nil;

	local count = gCurrentPane.activeSearch:NumScans();
	if (count == 1) then
		gCurrentPane.activeScan = gCurrentPane.activeSearch:GetFirstScan();
	end

	if (Atr_IsModeCreateAuction()) then
			
		gCurrentPane:SetToShowCurrent();

		if (#gCurrentPane.activeScan.scanData == 0) then
			gCurrentPane.hints = Atr_BuildHints (gCurrentPane.activeScan.itemName);
			if (#gCurrentPane.hints > 0) then
				gCurrentPane:SetToShowHints();	
				gCurrentPane.hintsIndex = 1;
			end

		end
		
		if (gCurrentPane:ShowCurrent()) then
			Atr_FindBestCurrentAuction ();
		end

		Atr_UpdateRecommendation(true);
	else
		if (Atr_IsModeActiveAuctions()) then
			Atr_DisplayHlist();
		end
		
		Atr_FindBestCurrentAuction ();
	end
	
	if (Atr_IsModeBuy()) then
		Atr_Shop_OnFinishScan ();
	end

	Atr_CheckingActive_OnSearchComplete();

	gCurrentPane.UINeedsUpdate = true;

end

-----------------------------------------

function Atr_ClearTop ()
	Atr_HideElems (recommendElements);

	if (AuctionatorMessageFrame) then
		AuctionatorMessageFrame:Hide();
		AuctionatorMessage2Frame:Hide();
	end
end

-----------------------------------------

function Atr_ClearList ()

       Atr_HideAllColumns();


	local line;							-- 1 through 12 of our window to scroll

	FauxScrollFrame_Update (AuctionatorScrollFrame, 0, 12, 16);

	for line = 1,12 do
		local lineEntry = getglobal ("AuctionatorEntry"..line);
		lineEntry:Hide();
	end

end

-----------------------------------------

function Atr_ClearAll ()

	if (AuctionatorMessageFrame) then	-- just to make sure xml has been loaded

		Atr_ClearTop();
		Atr_ClearList();
	end
end

-----------------------------------------

function Atr_SetMessage (msg)
	Atr_HideElems (recommendElements);

	if (gCurrentPane.activeSearch.searchText) then
		
		Atr_ShowItemNameAndTexture (gCurrentPane.activeSearch.searchText);
		
		AuctionatorMessage2Frame:SetText (msg);
		AuctionatorMessage2Frame:Show();
		
	else
		AuctionatorMessageFrame:SetText (msg);
		AuctionatorMessageFrame:Show();
		AuctionatorMessage2Frame:Hide();
	end
end

-----------------------------------------

function Atr_ShowItemNameAndTexture(itemName)

        AuctionatorMessageFrame:Hide();
        AuctionatorMessage2Frame:Hide();

        if (not gCurrentPane or not gCurrentPane.activeScan) then
                return;
        end

        local scn = gCurrentPane.activeScan;

	local color = "";
	if (scn and not scn:IsNil()) then
		color = "|cff"..zc.RGBtoHEX (scn.itemTextColor[1], scn.itemTextColor[2], scn.itemTextColor[3]);
		itemName = scn.itemName;
	end

	Atr_Recommend_Text:Show ();
	Atr_Recommend_Text:SetText (color..itemName);

	Atr_SetTextureButton ("Atr_RecommendItem_Tex", 1, gCurrentPane.activeScan.itemLink);
	
	-- Update cache age display
	Atr_UpdateCacheAgeDisplay();
end

-----------------------------------------

function Atr_GetCacheAgeText()

        if (not gCurrentPane or not gCurrentPane.activeScan) then
                return "";
        end

        local scn = gCurrentPane.activeScan;

        if (scn:IsNil() or scn.whenScanned == 0) then
                return "";
        end
	
	local ageSeconds = time() - scn.whenScanned;
	
	if (ageSeconds < 5) then
		return ZT("Data: just updated");
	elseif (ageSeconds < 60) then
		return string.format(ZT("Data: %d seconds ago"), ageSeconds);
	elseif (ageSeconds < 3600) then
		local minutes = math.floor(ageSeconds / 60);
		return string.format(ZT("Data: %d minutes ago"), minutes);
	else
		local hours = math.floor(ageSeconds / 3600);
		return string.format(ZT("Data: %d hours ago"), hours);
	end
end

-----------------------------------------

function Atr_UpdateCacheAgeDisplay()
	
	if (not Atr_CacheAge_Text) then
		return;
	end
	
	local ageText = Atr_GetCacheAgeText();
	local customButton = getglobal("Atr_RefreshButton_Custom");
	
	if (ageText == "") then
		Atr_CacheAge_Text:Hide();
		if (customButton) then
			customButton:Hide();
		end
	else
		Atr_CacheAge_Text:SetText(ageText);
		Atr_CacheAge_Text:Show();
		
		-- Show refresh button on all tabs when we have cached data
		if (gCurrentPane and gCurrentPane.activeSearch and gCurrentPane.activeSearch.searchText ~= "") then
			if (customButton) then
				customButton:Show();
			end
		else
			if (customButton) then
				customButton:Hide();
			end
		end
	end
end

-----------------------------------------

function Atr_ClearCurrent()
	-- Clear the auction list display by clearing the active scan
	if (gCurrentPane) then
		gCurrentPane.activeScan = Atr_FindScan(nil);
	end
	
	-- Clear the recommendation text
	if (Atr_Recommend_Text) then
		Atr_Recommend_Text:SetText("");
	end
	
	-- Clear any current message
	Atr_SetMessage("");
end

function Atr_Refresh_OnClick()
	
	if (not gCurrentPane or not gCurrentPane.activeSearch) then
		return;
	end
	
	-- Clear cached data to force refresh
	local searchText = gCurrentPane.activeSearch.searchText;
	if (searchText and searchText ~= "") then
		local scan = Atr_FindScan(searchText);
		if (scan) then
			scan.whenScanned = 0;  -- Mark as outdated
			scan.scanData = {};    -- Clear cached results
		end
		
		-- Clear the current display first for better visual effect
		Atr_ClearCurrent();	
		Atr_ClearAll();
		
		-- Show "Refreshing..." message
		Atr_SetMessage(ZT("Refreshing data..."));
		
		-- Force a new search by clearing the cache and restarting
		gCurrentPane.activeSearch:Start();
	else
		-- No search text to refresh
	end
end



-----------------------------------------

function Atr_SortHistoryData (x, y)

	return x.when > y.when;

end

-----------------------------------------

function BuildHtag (type, y, m, d)

	local t = time({year=y, month=m, day=d, hour=0});

	return tostring (ToTightTime(t))..":"..type;
end

-----------------------------------------

function ParseHtag (tag)
	local when, type = strsplit(":", tag);

	if (type == nil) then
		type = "hx";
	end

	when = FromTightTime (tonumber (when));

	return when, type;
end

-----------------------------------------

function ParseHist (tag, hist)

	local when, type = ParseHtag(tag);

	local price, count	= strsplit(":", hist);

	price = tonumber (price);

	local stacksize, numauctions;

	if (type == "hx") then
		stacksize	= tonumber (count);
		numauctions	= 1;
	else
		stacksize = 0;
		numauctions	= tonumber (count);
	end

	return when, type, price, stacksize, numauctions;

end

-----------------------------------------

function CalcAbsTimes (when, whent)

	local absYear	= whent.year - 2000;
	local absMonth	= (absYear * 12) + whent.month;
	local absDay	= floor ((when - gTimeZero) / (60*60*24));

	return absYear, absMonth, absDay;

end

-----------------------------------------

function Atr_Condense_History (itemname)

	if (AUCTIONATOR_PRICING_HISTORY[itemname] == nil) then
		return;
	end

	local tempHistory = {};

	local now			= time();
	local nowt			= date("*t", now);

	local absNowYear, absNowMonth, absNowDay = CalcAbsTimes (now, nowt);

	local n = 1;
	local tag, hist, newtag, stacksize, numauctions;
	for tag, hist in pairs (AUCTIONATOR_PRICING_HISTORY[itemname]) do
		if (tag ~= "is") then

			local when, type, price, stacksize, numauctions = ParseHist (tag, hist);

			local whnt = date("*t", when);

			local absYear, absMonth, absDay	= CalcAbsTimes (when, whnt);

			if (absNowYear - absYear >= 3) then
				newtag = BuildHtag ("hy", whnt.year, 1, 1);
			elseif (absNowMonth - absMonth >= 2) then
				newtag = BuildHtag ("hm", whnt.year, whnt.month, 1);
			elseif (absNowDay - absDay >= 2) then
				newtag = BuildHtag ("hd", whnt.year, whnt.month, whnt.day);
			else
				newtag = tag;
			end

			tempHistory[n] = {};
			tempHistory[n].price		= price;
			tempHistory[n].numauctions	= numauctions;
			tempHistory[n].stacksize	= stacksize;
			tempHistory[n].when			= when;
			tempHistory[n].newtag		= newtag;
			n = n + 1;
		end
	end

	-- clear all the existing history

	local is = AUCTIONATOR_PRICING_HISTORY[itemname]["is"];

	AUCTIONATOR_PRICING_HISTORY[itemname] = {};
	AUCTIONATOR_PRICING_HISTORY[itemname]["is"] = is;

	-- repopulate the history

	local x;

	for x = 1,#tempHistory do

		local thist		= tempHistory[x];
		local newtag	= thist.newtag;

		if (AUCTIONATOR_PRICING_HISTORY[itemname][newtag] == nil) then

			local when, type = ParseHtag (newtag);

			local count = thist.numauctions;
			if (type == "hx") then
				count = thist.stacksize;
			end

			AUCTIONATOR_PRICING_HISTORY[itemname][newtag] = tostring(thist.price)..":"..tostring(count);

		else

			local hist = AUCTIONATOR_PRICING_HISTORY[itemname][newtag];

			local when, type, price, stacksize, numauctions = ParseHist (newtag, hist);

			local newNumAuctions = numauctions + thist.numauctions;
			local newPrice		 = ((price * numauctions) + (thist.price * thist.numauctions)) / newNumAuctions;

			AUCTIONATOR_PRICING_HISTORY[itemname][newtag] = tostring(newPrice)..":"..tostring(newNumAuctions);
		end
	end

end

-----------------------------------------

function Atr_Process_Historydata ()

	-- Condense the data if needed - only once per session for each item

	if (gCurrentPane:IsScanEmpty()) then
		return;
	end
	
	local itemName = gCurrentPane.activeScan.itemName;

	if (gCondensedThisSession[itemName] == nil) then

		gCondensedThisSession[itemName] = true;

		Atr_Condense_History(itemName);
	end

	-- build the sorted history list

	gCurrentPane.sortedHist = {};

	if (AUCTIONATOR_PRICING_HISTORY[itemName]) then
		local n = 1;
		local tag, hist;
		for tag, hist in pairs (AUCTIONATOR_PRICING_HISTORY[itemName]) do
			if (tag ~= "is") then
				local when, type, price, stacksize, numauctions = ParseHist (tag, hist);

				if (stacksize == 0) then
					stacksize = numauctions;
				end
				
				gCurrentPane.sortedHist[n]				= {};
				gCurrentPane.sortedHist[n].itemPrice	= price;
				gCurrentPane.sortedHist[n].buyoutPrice	= price * stacksize;
				gCurrentPane.sortedHist[n].stackSize	= stacksize;
				gCurrentPane.sortedHist[n].when			= when;
				gCurrentPane.sortedHist[n].yours		= true;
				gCurrentPane.sortedHist[n].type			= type;

				n = n + 1;
			end
		end
	end

	table.sort (gCurrentPane.sortedHist, Atr_SortHistoryData);

	if (#gCurrentPane.sortedHist > 0) then
		return gCurrentPane.sortedHist[1].itemPrice;
	end

end

-----------------------------------------

function Atr_GetMostRecentSale (itemName)

	local recentPrice;
	local recentWhen = 0;
	
	if (AUCTIONATOR_PRICING_HISTORY and AUCTIONATOR_PRICING_HISTORY[itemName]) then
		local n = 1;
		local tag, hist;
		for tag, hist in pairs (AUCTIONATOR_PRICING_HISTORY[itemName]) do
			if (tag ~= "is") then
				local when, type, price = ParseHist (tag, hist);

				if (when > recentWhen) then
					recentPrice = price;
					recentWhen  = when;
				end
			end
		end
	end

	return recentPrice;

end


-----------------------------------------

function Atr_ShowingSearchSummary ()

	if (gCurrentPane.activeSearch and gCurrentPane.activeSearch.searchText ~= "" and gCurrentPane:IsScanEmpty() and gCurrentPane.activeSearch:NumScans() > 0) then
		return true;
	end
	
	return false;
end

-----------------------------------------

function Atr_ShowingCurrentAuctions ()
	if (gCurrentPane) then
		return gCurrentPane:ShowCurrent();
	end
	
	return true;
end

-----------------------------------------

function Atr_ShowingHistory ()
	if (gCurrentPane) then
		return gCurrentPane:ShowHistory();
	end
	
	return false;
end

-----------------------------------------

function Atr_ShowingHints ()
	if (gCurrentPane) then
		return gCurrentPane:ShowHints();
	end
	
	return false;
end



-----------------------------------------

function Atr_UpdateRecommendation (updatePrices)

	if (gCurrentPane == gSellPane and gJustPosted_ItemLink and GetAuctionSellItemInfo() == nil) then
		return;
	end

	local basedata;

	if (Atr_ShowingSearchSummary()) then
	
	elseif (Atr_ShowingCurrentAuctions()) then

		if (gCurrentPane:GetProcessingState() ~= KM_NULL_STATE) then
			return;
		end

		if (#gCurrentPane.activeScan.sortedData == 0) then
			Atr_SetMessage (ZT("No current auctions found"));
			return;
		end

		if (not gCurrentPane.currIndex) then
			if (gCurrentPane.activeScan.numMatches == 0) then
				Atr_SetMessage (ZT("No current auctions found\n\n(related auctions shown)"));
			elseif (gCurrentPane.activeScan.numMatchesWithBuyout == 0) then
				Atr_SetMessage (ZT("No current auctions with buyouts found"));
			else
				Atr_SetMessage ("");
			end
			return;
		end

		basedata = gCurrentPane.activeScan.sortedData[gCurrentPane.currIndex];
		
	elseif (Atr_ShowingHistory()) then
	
		basedata = zc.GetArrayElemOrFirst (gCurrentPane.sortedHist, gCurrentPane.histIndex);
		
		if (basedata == nil) then
			Atr_SetMessage (ZT("Auctionator has yet to record any auctions for this item"));
			return;
		end
	
	else	-- hints
		
		local data = zc.GetArrayElemOrFirst (gCurrentPane.hints, gCurrentPane.hintsIndex);
		
		if (data) then		
			basedata = {};
			basedata.itemPrice		= data.price;
			basedata.buyoutPrice	= data.price;
			basedata.stackSize		= 1;
			basedata.sourceText		= data.text;
			basedata.yours			= true;		-- so no discounting
		end
	end

	if (Atr_StackSize() == 0) then
		return;
	end

	local new_Item_BuyoutPrice;
	
	if (gItemPostingInProgress and gCurrentPane.itemLink == gJustPosted_ItemLink) then	-- handle the unusual case where server is still in the process of creating the last auction

		new_Item_BuyoutPrice = gJustPosted_BuyoutPrice / gJustPosted_StackSize;
		
	elseif (basedata) then			-- the normal case
	
		new_Item_BuyoutPrice = basedata.itemPrice;

		if (not basedata.yours and not basedata.altname) then
			new_Item_BuyoutPrice = Atr_CalcUndercutPrice (new_Item_BuyoutPrice);
		end
	end

	if (new_Item_BuyoutPrice == nil) then
		return;
	end
	
	local new_Item_StartPrice = Atr_CalcStartPrice (new_Item_BuyoutPrice);

	--Atr_ShowElems (recommendElements);
	AuctionatorMessageFrame:Hide();
	AuctionatorMessage2Frame:Hide();

	Atr_Recommend_Text:SetText (ZT("Recommended Buyout Price"));
	Atr_RecommendPerStack_Text:SetText (string.format (ZT("for your stack of %d"), Atr_StackSize()));

	Atr_SetTextureButton ("Atr_RecommendItem_Tex", Atr_StackSize(), gCurrentPane.activeScan.itemLink);

	MoneyFrame_Update ("Atr_RecommendPerItem_Price",  zc.round(new_Item_BuyoutPrice));
	MoneyFrame_Update ("Atr_RecommendPerStack_Price", zc.round(new_Item_BuyoutPrice * Atr_StackSize()));

	if (updatePrices) then
		MoneyInputFrame_SetCopper (Atr_StackPrice,		new_Item_BuyoutPrice * Atr_StackSize());
		MoneyInputFrame_SetCopper (Atr_StartingPrice, 	new_Item_StartPrice * Atr_StackSize());
		MoneyInputFrame_SetCopper (Atr_ItemPrice,		new_Item_BuyoutPrice);
	end
	
	local cheapestStack = gCurrentPane.activeScan.bestPrices[Atr_StackSize()];

	Atr_Recommend_Basis_Text:SetTextColor (1,1,1);

	if (Atr_ShowingHints()) then
		Atr_Recommend_Basis_Text:SetTextColor (.8,.8,1);
		Atr_Recommend_Basis_Text:SetText ("("..ZT("based on").." "..basedata.sourceText..")");
	elseif (gCurrentPane.activeScan.absoluteBest and basedata.stackSize == gCurrentPane.activeScan.absoluteBest.stackSize and basedata.buyoutPrice == gCurrentPane.activeScan.absoluteBest.buyoutPrice) then
		Atr_Recommend_Basis_Text:SetText ("("..ZT("based on cheapest current auction")..")");
	elseif (cheapestStack and basedata.stackSize == cheapestStack.stackSize and basedata.buyoutPrice == cheapestStack.buyoutPrice) then
		Atr_Recommend_Basis_Text:SetText ("("..ZT("based on cheapest stack of the same size")..")");
	else
		Atr_Recommend_Basis_Text:SetText ("("..ZT("based on selected auction")..")");
	end

end


-----------------------------------------

function Atr_StackPriceChangedFunc ()

	local new_Stack_BuyoutPrice = MoneyInputFrame_GetCopper (Atr_StackPrice);
	local new_Item_BuyoutPrice  = math.floor (new_Stack_BuyoutPrice / Atr_StackSize());
	local new_Item_StartPrice   = Atr_CalcStartPrice (new_Item_BuyoutPrice);

	local calculatedStackPrice = MoneyInputFrame_GetCopper(Atr_ItemPrice) * Atr_StackSize();

	-- check to prevent looping
	
	if (calculatedStackPrice ~= new_Stack_BuyoutPrice) then
		MoneyInputFrame_SetCopper (Atr_ItemPrice,		new_Item_BuyoutPrice);
		MoneyInputFrame_SetCopper (Atr_StartingPrice,	new_Item_StartPrice * Atr_StackSize());
	end
	
end

-----------------------------------------

function Atr_ItemPriceChangedFunc ()

	local new_Item_BuyoutPrice = MoneyInputFrame_GetCopper (Atr_ItemPrice);
	local new_Item_StartPrice  = Atr_CalcStartPrice (new_Item_BuyoutPrice);
	
	local calculatedItemPrice = math.floor (MoneyInputFrame_GetCopper (Atr_StackPrice) / Atr_StackSize());

	-- check to prevent looping
	
	if (calculatedItemPrice ~= new_Item_BuyoutPrice) then
		MoneyInputFrame_SetCopper (Atr_StackPrice, 		new_Item_BuyoutPrice * Atr_StackSize());
		MoneyInputFrame_SetCopper (Atr_StartingPrice,	new_Item_StartPrice  * Atr_StackSize());
	end

end

-----------------------------------------

function Atr_StackSizeChangedFunc ()

	local item_BuyoutPrice		= MoneyInputFrame_GetCopper (Atr_ItemPrice);
	local new_Item_StartPrice   = Atr_CalcStartPrice (item_BuyoutPrice);
	
	MoneyInputFrame_SetCopper (Atr_StackPrice, 		item_BuyoutPrice * Atr_StackSize());
	MoneyInputFrame_SetCopper (Atr_StartingPrice,	new_Item_StartPrice  * Atr_StackSize());

--	Atr_MemorizeButton:Show();

	gSellPane.UINeedsUpdate = true;

end

-----------------------------------------

function Atr_NumAuctionsChangedFunc (x)

--	Atr_MemorizeButton:Show();

	gSellPane.UINeedsUpdate = true;
end


-----------------------------------------

function Atr_SetTextureButton (elementName, count, itemlink)

	local texture = GetItemIcon (itemlink);

	local textureElement = getglobal (elementName);

	if (texture) then
		textureElement:Show();
		textureElement:SetNormalTexture (texture);
		Atr_SetTextureButtonCount (elementName, count);
	else
		Atr_SetTextureButtonCount (elementName, 0);
	end

end

-----------------------------------------

function Atr_SetTextureButtonCount (elementName, count)

	local countElement   = getglobal (elementName.."Count");

	if (count > 1) then
		countElement:SetText (count);
		countElement:Show();
	else
		countElement:Hide();
	end

end

-----------------------------------------

function Atr_ShowRecTooltip ()
	
	local link = gCurrentPane.activeScan.itemLink;
	local num  = Atr_StackSize();
	
	if (not link) then
		link = gJustPosted_ItemLink;
		num  = gJustPosted_StackSize;
	end
	
	if (link) then
		if (num < 1) then num = 1; end;
		
		GameTooltip:SetOwner(Atr_RecommendItem_Tex, "ANCHOR_RIGHT");
		GameTooltip:SetHyperlink (link, num);
		gCurrentPane.tooltipvisible = true;
	end

end

-----------------------------------------

function Atr_HideRecTooltip ()
	
	gCurrentPane.tooltipvisible = nil;
	GameTooltip:Hide();

end


-----------------------------------------

function Atr_OnAuctionHouseShow()

	gOpenAllBags = AUCTIONATOR_OPEN_ALL_BAGS;

	if (AUCTIONATOR_DEFTAB == 1) then		Atr_SelectPane (SELL_TAB);	end
	if (AUCTIONATOR_DEFTAB == 2) then		Atr_SelectPane (BUY_TAB);	end
	if (AUCTIONATOR_DEFTAB == 3) then		Atr_SelectPane (MORE_TAB);	end

	Atr_ResetDuration();

	gJustPosted_ItemName = nil;
	gSellPane:ClearSearch();

	if (gCurrentPane) then
		gCurrentPane.UINeedsUpdate = true;
	end
end

-----------------------------------------

function Atr_OnAuctionHouseClosed()

	Atr_HideAllDialogs();
	
	gAutoSellState = AUTO_SELL_OFF;
	
	Atr_CheckingActive_Finish ();

	Atr_ClearScanCache();

	gSellPane:ClearSearch();
	gShopPane:ClearSearch();
	gMorePane:ClearSearch();

end

-----------------------------------------

function Atr_HideAllDialogs()

	Atr_CheckActives_Frame:Hide();
	Atr_Error_Frame:Hide();
	Atr_Buy_Confirm_Frame:Hide();
	Atr_FullScanFrame:Hide();
	Atr_Mask:Hide();

end



-----------------------------------------

function Atr_BasicOptionsUpdate(self, elapsed)

	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;

	if (self.TimeSinceLastUpdate > 0.25) then

		self.TimeSinceLastUpdate = 0;

		if (AuctionatorOption_Def_Duration_CB:GetChecked()) then
			AuctionatorOption_Durations:Show();
		else
			AuctionatorOption_Durations:Hide();
		end

	end
end


-----------------------------------------

function Atr_OnWhoListUpdate()

	if (gSendZoneMsgs) then
		gSendZoneMsgs = false;
		
		local numWhos, totalCount = GetNumWhoResults();
		local i;
		
		zc.msg_dev (numWhos.." out of "..totalCount.." users found");

		for i = 1,numWhos do
			local name, guildname, level = GetWhoInfo(i);
			Atr_SendAddon_VREQ ("WHISPER", name);
			if (Atr_Guildinfo) then
				Atr_Guildinfo[name] = guildname;
			end
			if (Atr_Levelinfo) then
				Atr_Levelinfo[name] = level;
			end
			
		end
	end
end

-----------------------------------------

function Atr_OnUpdate(self, elapsed)

	-- update the global "precision" timer
	
	gAtr_ptime = gAtr_ptime and gAtr_ptime + elapsed or 0;

	
	-- check deferred call queue

	if (zc.periodic (self, "dcq_lastUpdate", 0.05, elapsed)) then
		zc.CheckDeferredCall();
	end

	-- make sure all dusts and essences are in the local cache

	if (gAtr_dustCacheIndex > 0 and zc.periodic (self, "dust_lastUpdate", 0.1, elapsed)) then
		Atr_GetNextDustIntoCache();
	end
	
	-- the core Idle routine

	if (zc.periodic (self, "idle_lastUpdate", 0.2, elapsed)) then
		Atr_Idle (self, elapsed);
	end
	
	-- update cache age display periodically
	
	if (zc.periodic (self, "cacheAge_lastUpdate", 1, elapsed)) then
		Atr_UpdateCacheAgeDisplay();
	end
end


-----------------------------------------
local verCheckMsgState = 0;
-----------------------------------------

function Atr_Idle(self, elapsed)


	if (gCurrentPane and gCurrentPane.tooltipvisible) then
		Atr_ShowRecTooltip();
	end


	if (gAtr_FullScanState ~= ATR_FS_NULL) then
		Atr_FullScanFrameIdle();
	end
	
	if (verCheckMsgState == 0) then
		verCheckMsgState = time();
	end
	
	if (verCheckMsgState > 1 and time() - verCheckMsgState > 5) then	-- wait 5 seconds
		verCheckMsgState = 1;
		
		local guildname = GetGuildInfo ("player");
		if (guildname) then
			Atr_SendAddon_VREQ ("GUILD");
		end
	end

	if (not Atr_IsTabSelected() or AuctionatorMessageFrame == nil) then
		return;
	end

	if (gHentryTryAgain) then
		Atr_HEntryOnClick();
		return;
	end

	if (gCurrentPane.activeSearch and gCurrentPane.activeSearch.processing_state == KM_PREQUERY) then		------- check whether to send a new auction query to get the next page -------
		gCurrentPane.activeSearch:Continue();
	end

	Atr_Idle_AutoSelling (self);

	Atr_UpdateUI ();

	Atr_CheckingActiveIdle();
	
	Atr_Buy_Idle();
	
	if (gHideAPFrameCheck == nil) then	-- for the addon 'Auction Profit' (flags for efficiency so we only check one time)
		gHideAPFrameCheck = true;
		if (AP_Bid_MoneyFrame) then	
			AP_Bid_MoneyFrame:Hide();
			AP_Buy_MoneyFrame:Hide();
		end
	end
end

-----------------------------------------

local gPrevSellItemLink;

-----------------------------------------

function Atr_OnNewAuctionUpdate()

	if (AutoSell_InProgress()) then
		return;
	end
	
	if (not gAtr_ClickAuctionSell) then
		gPrevSellItemLink = nil;
		return;
	end
	
--	zc.msg_dev ("gAtr_ClickAuctionSell:", gAtr_ClickAuctionSell);
	
	gAtr_ClickAuctionSell = false;

	local auctionItemName, auctionCount, auctionLink = Atr_GetSellItemInfo();

	if (gPrevSellItemLink ~= auctionLink) then

		gPrevSellItemLink = auctionLink;
		
		if (auctionLink) then
			gJustPosted_ItemName = nil;
			Atr_AddToItemLinkCache (auctionItemName, auctionLink);
			Atr_ClearList();		-- better UE
			gSellPane:SetToShowCurrent();
		end
		
		MoneyInputFrame_SetCopper (Atr_StackPrice, 0);
		MoneyInputFrame_SetCopper (Atr_StartingPrice,  0);
		Atr_ResetDuration();
		
		if (gJustPosted_ItemName == nil) then
			local cacheHit = gSellPane:DoSearch (auctionItemName, true, AUCTIONATOR_CACHE_THRESHOLD);
			
			gSellPane.totalItems	= Atr_GetNumItemInBags (auctionItemName);
			gSellPane.fullStackSize = auctionLink and (select (8, GetItemInfo (auctionLink))) or 0;

			local prefNumStacks, prefStackSize = Atr_GetSellStacking (auctionLink, auctionCount, gSellPane.totalItems);
			
			if (time() - gAutoSingleton < 5) then
				Atr_SetInitialStacking (1, 1);
			else
				Atr_SetInitialStacking (prefNumStacks, prefStackSize);
			end
			
			if (cacheHit) then
				Atr_OnSearchComplete ();
			end
			
			Atr_SetTextureButton ("Atr_SellControls_Tex", Atr_StackSize(), auctionLink);
			Atr_SellControls_TexName:SetText (auctionItemName);
		else
			Atr_SetTextureButton ("Atr_SellControls_Tex", 0, nil);
			Atr_SellControls_TexName:SetText ("");
		end
		
	elseif (Atr_StackSize() ~= auctionCount) then
	
		local prefNumStacks, prefStackSize = Atr_GetSellStacking (auctionLink, auctionCount, gSellPane.totalItems);

		Atr_SetInitialStacking (prefNumStacks, prefStackSize);

		Atr_SetTextureButton ("Atr_SellControls_Tex", Atr_StackSize(), auctionLink);

		Atr_FindBestCurrentAuction();
		Atr_ResetDuration();
	end
		
	gSellPane.UINeedsUpdate = true;
	
end

---------------------------------------------------------

function Atr_UpdateUI ()

	local needsUpdate = gCurrentPane.UINeedsUpdate;
	
	if (gCurrentPane.UINeedsUpdate) then

		gCurrentPane.UINeedsUpdate = false;

               if (Atr_ShowingSearchSummary()) then
                       Atr_ShowSearchSummary();
                       if (gCurrentPane.activeSearch) then
                               gCurrentPane.activeSearch:UpdateArrows();
                       end
               elseif (gCurrentPane:ShowCurrent()) then
			PanelTemplates_SetTab(Atr_ListTabs, 1);
			Atr_ShowCurrentAuctions();
		elseif (gCurrentPane:ShowHistory()) then
			PanelTemplates_SetTab(Atr_ListTabs, 2);
			Atr_ShowHistory();
		else
			PanelTemplates_SetTab(Atr_ListTabs, 3);
			Atr_ShowHints();
		end
		
		if (gCurrentPane:IsScanEmpty()) then
			Atr_ListTabs:Hide();
		else
			Atr_ListTabs:Show();
		end

		Atr_SetMessage ("");
		local scn = gCurrentPane.activeScan;
		
		if (Atr_IsModeCreateAuction()) then
		
			Atr_UpdateRecommendation (false);
		else
			Atr_HideElems (recommendElements);
		
			if (scn:IsNil()) then
				Atr_ShowItemNameAndTexture (gCurrentPane.activeSearch.searchText);
			else
				Atr_ShowItemNameAndTexture (gCurrentPane.activeScan.itemName);
			end

			if (Atr_IsModeBuy()) then

				if (gCurrentPane.activeSearch.searchText == "") then
					Atr_SetMessage (ZT("Select an item from the list on the left\n or type a search term above to start a scan."));
				end
			end
		
		end
		
		
		if (Atr_IsTabSelected(BUY_TAB)) then
			Atr_Shop_UpdateUI();
		end
		
	end
	
	-- update the hlist if needed

	if (gHlistNeedsUpdate and Atr_IsModeActiveAuctions()) then
		gHlistNeedsUpdate = false;
		Atr_DisplayHlist();
	end
	
	if (Atr_IsTabSelected(SELL_TAB)) then
		Atr_UpdateUI_SellPane (needsUpdate);
	end

end

---------------------------------------------------------

function Atr_UpdateUI_SellPane (needsUpdate)

	local auctionItemName = GetAuctionSellItemInfo();

	if (needsUpdate) then

		if (gCurrentPane.activeSearch and gCurrentPane.activeSearch.processing_state ~= KM_NULL_STATE) then
			Atr_CreateAuctionButton:Disable();
			Atr_FullScanButton:Disable();
			Auctionator1Button:Disable();		
			MoneyInputFrame_SetCopper (Atr_StartingPrice,  0);
			return;
		else
			Atr_FullScanButton:Enable();
			Auctionator1Button:Enable();		


			if (Atr_Batch_Stacksize.oldStackSize ~= Atr_StackSize()) then
				Atr_Batch_Stacksize.oldStackSize = Atr_StackSize();
				local itemPrice = MoneyInputFrame_GetCopper(Atr_ItemPrice);
				MoneyInputFrame_SetCopper (Atr_StackPrice,  itemPrice * Atr_StackSize());
			end

			Atr_StartingPriceDiscountText:SetText (ZT("Starting Price Discount")..":  "..AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT.."%");
			
			if (Atr_Batch_NumAuctions:GetNumber() < 2) then
				Atr_Batch_Stacksize_Text:SetText (ZT("stack of"));
				Atr_CreateAuctionButton:SetText (ZT("Create Auction"));
			else
				Atr_Batch_Stacksize_Text:SetText (ZT("stacks of"));
				Atr_CreateAuctionButton:SetText (string.format (ZT("Create %d Auctions"), Atr_Batch_NumAuctions:GetNumber()));
			end

			if (Atr_StackSize() > 1) then
				Atr_StackPriceText:SetText (ZT("Buyout Price").." |cff55ddffx"..Atr_StackSize().."|r");
				Atr_ItemPriceText:SetText (ZT("Per Item"));
				Atr_ItemPriceText:Show();
				Atr_ItemPrice:Show();
			else
				Atr_StackPriceText:SetText (ZT("Buyout Price"));
				Atr_ItemPriceText:Hide();
				Atr_ItemPrice:Hide();
			end

			Atr_SetTextureButton ("Atr_SellControls_Tex", Atr_StackSize(), Atr_GetItemLink(auctionItemName));

			
			local maxAuctions = 0;
			if (Atr_StackSize() > 0) then
				maxAuctions = math.floor (gCurrentPane.totalItems / Atr_StackSize());
			end
			
			Atr_Batch_MaxAuctions_Text:SetText (ZT("max")..": "..maxAuctions);
			Atr_Batch_MaxStacksize_Text:SetText (ZT("max")..": "..gCurrentPane.fullStackSize);
			
			Atr_SetDepositText();			
		end

		if (gJustPosted_ItemName ~= nil) then

			Atr_Recommend_Text:SetText (string.format (ZT("Auction created for %s"), gJustPosted_ItemName));
			MoneyFrame_Update ("Atr_RecommendPerStack_Price", gJustPosted_BuyoutPrice);
			Atr_SetTextureButton ("Atr_RecommendItem_Tex", gJustPosted_StackSize, gJustPosted_ItemLink);

			gCurrentPane.currIndex = gCurrentPane.activeScan:FindInSortedData (gJustPosted_StackSize, gJustPosted_BuyoutPrice);

			if (gCurrentPane:ShowCurrent()) then
				Atr_HighlightEntry (gCurrentPane.currIndex);		-- highlight the newly created auction(s)
			else
				Atr_HighlightEntry (gCurrentPane.histIndex);
			end
		
		elseif (gCurrentPane:IsScanEmpty()) then
			Atr_SetMessage (ZT("Drag an item you want to sell to this area."));
		end
	end

	-- stuff we should do every time (not just when needsUpdate is true)
	
	local start		= MoneyInputFrame_GetCopper(Atr_StartingPrice);
	local buyout	= MoneyInputFrame_GetCopper(Atr_StackPrice);

	local pricesOK	= (start > 0 and (start <= buyout or buyout == 0) and (auctionItemName ~= nil));
	
	local numToSell = Atr_Batch_NumAuctions:GetNumber() * Atr_Batch_Stacksize:GetNumber();

	zc.EnableDisable (Atr_CreateAuctionButton,	pricesOK and (numToSell <= gCurrentPane.totalItems));
	
end

-----------------------------------------

function Atr_SetDepositText()
			
	_, auctionCount = Atr_GetSellItemInfo();
	
	if (auctionCount > 0) then
		local duration = UIDropDownMenu_GetSelectedValue(Atr_Duration);
	
		local deposit1 = CalculateAuctionDeposit (duration) / auctionCount;
		local numAuctionString = "";
		if (Atr_Batch_NumAuctions:GetNumber() > 1) then
			numAuctionString = "  |cffff55ff x"..Atr_Batch_NumAuctions:GetNumber();
		end
		
		Atr_Deposit_Text:SetText (ZT("Deposit")..":    "..zc.priceToMoneyString(deposit1 * Atr_StackSize(), true)..numAuctionString);
	else
		Atr_Deposit_Text:SetText ("");
	end
end

-----------------------------------------

function BS_GetCount(bs)

	local texture, count = GetContainerItemInfo (bs.bagID, bs.slotID);
	if (texture ~= nil) then
		return count;
	end

	return 0;

end

-----------------------------------------

function BS_InCslots(xbs)

	local i, bs;

	for i,bs in pairs(cslots) do
		if (xbs.bagID == bs.bagID and xbs.slotID == bs.slotID) then
			return true;
		end
	end

	return false;

end

-----------------------------------------

function BS_GetEmptySlot()

	if (gEmptyBScached == nil or BS_GetCount (gEmptyBScached) ~= 0) then

		gEmptyBScached = nil;

		local b;
		
		for b = 1, #kBagIDs do
			bagID = kBagIDs[b];
			
			if (bagID ~= KEYRING_CONTAINER ) then
				local freeSlots, itemFamily = GetContainerNumFreeSlots (bagID)
			
				if (freeSlots > 0 and (itemFamily == 0 or bit.band (itemFamily, gBS_ItemFamily) ~= 0)) then
				
					numslots = GetContainerNumSlots (bagID);
					for slotID = 1,numslots do
						local itemLink = GetContainerItemLink(bagID, slotID);
						if (itemLink == nil) then
							gEmptyBScached = {};
							gEmptyBScached.bagID  = bagID;
							gEmptyBScached.slotID = slotID;

							-- add to cslots if not already there

							if (not BS_InCslots (gEmptyBScached)) then
								-- zc.msg ("Inserting "..bagID.."/"..slotID);
								tinsert (cslots, gEmptyBScached);
							end

							return gEmptyBScached;
						end
					end
				end
			end
		end
	end

	return gEmptyBScached;
end



-----------------------------------------

function BS_PostAuction(bs)

	if (bs) then
		PickupContainerItem (bs.bagID, bs.slotID);

		local infoType = GetCursorInfo()

		if (infoType == "item") then
			Atr_ClickAuctionSellItemButton ();
			ClearCursor();
		end
	end
	
	local orig_BuyoutPrice	= MoneyInputFrame_GetCopper(Atr_StackPrice);
	local startingPrice		= MoneyInputFrame_GetCopper(Atr_StartingPrice);
	
	if (orig_BuyoutPrice ~= gBS_Buyout_StackPrice) then
	
		startingPrice = math.floor (gBS_Start_StackPrice);
		
		MoneyInputFrame_SetCopper (Atr_StartingPrice,  startingPrice);
		MoneyInputFrame_SetCopper (Atr_StackPrice, gBS_Buyout_StackPrice);
	
	end

	StartAuction (startingPrice, gBS_Buyout_StackPrice, gBS_Hours * 60);

end

-----------------------------------------

function BS_FindGoodStack()

	local dstr = "";
	local i;

	for i, bs in pairs (cslots) do

		dstr = dstr..BS_GetCount (bs).." ";

		if (BS_GetCount (bs) == gBS_GoodStackSize) then
--			zc.msg ("FindGood: "..dstr);
			return bs
		end

	end

--	zc.msg ("FindGoodx: "..dstr);

	return nil;

end

-----------------------------------------

function BS_MergeSmallStacks()			-- find the 2 smallest stacks and merge them together if possible

	if (#cslots < 2) then
		return false;
	end

	local i, bs;

	local zbs	= nil;		-- smallest
	local ybs	= nil;		-- second smallest

	local zcount = 10000;
	local ycount = 10000;

	for i, bs in pairs (cslots) do
		local count = BS_GetCount (bs);

		if (count > 0) then
			if (count < zcount) then
				ybs = zbs;	ycount = zcount;
				zbs = bs;	zcount = count;
			elseif (count < ycount) then
				ybs = bs;	ycount = count;
			end
		end
	end

	if (zcount == 10000 or ycount == 10000) then
		return false;
	end

	-- try to make a "good" stack

	if (zcount < gBS_GoodStackSize and ycount + zcount >= gBS_GoodStackSize) then
		SplitContainerItem  (ybs.bagID, ybs.slotID, gBS_GoodStackSize - zcount);
		--if (not CursorHasItem()) then
		--	zc.msg_red("oops1");
		--end
		PickupContainerItem (zbs.bagID, zbs.slotID);

		gBS_targetBS	= zbs;
		gBS_targetCount	= gBS_GoodStackSize;

		return true;

	end

	-- merge them best as possible

	local numToMove = zcount;
	if (zcount + ycount > gBS_FullStackSize) then
		numToMove = gBS_FullStackSize - ycount;
	end

	if (numToMove > 0) then
		SplitContainerItem  (zbs.bagID, zbs.slotID, numToMove);
		
		--if (not CursorHasItem()) then
		--	zc.msg_red("oops2");
		--end
		
		PickupContainerItem (ybs.bagID, ybs.slotID);

		gBS_targetBS		= ybs;
		gBS_targetCount	= ycount + numToMove;

		return true;
	end

	return false;

end


-----------------------------------------

function BS_SplitLargeStack()

	local i, bs;

	local emptyBS = BS_GetEmptySlot ();

	for i, bs in pairs (cslots) do
		local count = BS_GetCount (bs);

		if (count > gBS_GoodStackSize) then
			if (emptyBS) then
				SplitContainerItem  (bs.bagID, bs.slotID, gBS_GoodStackSize);
				PickupContainerItem (emptyBS.bagID, emptyBS.slotID);

				gBS_targetBS		= emptyBS;
				gBS_targetCount		= gBS_GoodStackSize;
				return true;
			end
		end

	end

	return false;

end

-----------------------------------------

StaticPopupDialogs["AUCTIONATOR_AUTOSELL_FAIL"] = {
	text = "",
	button1 = OKAY,
	timeout = 0,
	showAlert = 1,
	exclusive = 1,
	hideOnEscape = 1
};

-----------------------------------------

function Atr_Idle_AutoSelling()

	if (gAutoSellState == AUTO_SELL_OFF or gAutoSellState == AUCTION_POST_PENDING) then
		return;
	end

	if (CursorHasItem()) then
		return;
	end

	if (gAutoSellState == STACK_MERGE_PENDING or gAutoSellState == STACK_SPLIT_PENDING) then

		if (BS_GetCount (gBS_targetBS) == gBS_targetCount) then
			ClearCursor();
			gAutoSellState = AUTO_SELL_WAITING;
		else
			return;
		end
	end

	if (gAutoSellState ~= AUTO_SELL_WAITING) then
		return;
	end

	-- let's see if we're done

	if (gBS_AuctionNum > gBS_NumAuctionsToCreate or gCurrentPane.autoSellReady ~= true) then
		gAutoSellState = AUTO_SELL_OFF;
		if (gBS_AuctionNum <= gBS_NumAuctionsToCreate) then
			zc.msg_yellow (ZF("gO8NCIH6NIL: CHN-LH6F -LLIL"));
		end
		return;
	end

	-- if there's a stack already loaded, sell it
	
	local auctionItemName, _, auctionCount = GetAuctionSellItemInfo();

	if (auctionItemName == gBS_ItemName and auctionCount == gBS_GoodStackSize) then
		BS_PostAuction();
		gAutoSellState = AUCTION_POST_PENDING;
		return;
	end		

	-- if there's a stack that's ready to sell, sell it

	local goodBS = BS_FindGoodStack();
	if (goodBS) then
		BS_PostAuction (goodBS);
		gAutoSellState = AUCTION_POST_PENDING;
		return;
	end

	-- see if we can split a larger stack to get a sellable stack

	local success = BS_SplitLargeStack();
	if (success) then
		gAutoSellState = STACK_SPLIT_PENDING;
		return;
	end

	-- see if we can merge two smaller stacks

	local success = BS_MergeSmallStacks();
	if (success) then
		gAutoSellState = STACK_MERGE_PENDING;
		return;
	end

	-- nothing left to do - we're done

	gAutoSellState = AUTO_SELL_OFF;

	gJustPosted_ItemName	= nil;
	gJustPosted_BuyoutPrice	= 0;
	gJustPosted_StackSize	= 0;
	gJustPosted_ItemLink	= nil;

	Atr_OnNewAuctionUpdate ();
	
	StaticPopupDialogs["AUCTIONATOR_AUTOSELL_FAIL"].text = ZT("Create Multiple Auctions failed.\nYou need at least one empty slot in your bags.");
	StaticPopup_Show ("AUCTIONATOR_AUTOSELL_FAIL");
	
end


-----------------------------------------

function Atr_BuildActiveAuctions ()

	gActiveAuctions = {};
	
	local i = 1;
	while (true) do
		local name, _, count = GetAuctionItemInfo ("owner", i);
		if (name == nil) then
			break;
		end

		if (count > 0) then		-- count is 0 for sold items
			if (gActiveAuctions[name] == nil) then
				gActiveAuctions[name] = 1;
			else
				gActiveAuctions[name] = gActiveAuctions[name] + 1;
			end
		end
		
		i = i + 1;
	end
end

-----------------------------------------

function Atr_GetUCIcon (itemName)

	local icon = "|TInterface\\BUTTONS\\\UI-PassiveHighlight:18:18:0:0|t "

	local undercutFound = false;
	
	local scan = Atr_FindScan (itemName);
	if (scan and scan.absoluteBest and scan.whenScanned ~= 0 and scan.yourBestPrice and scan.yourWorstPrice) then
		
		local absBestPrice = scan.absoluteBest.itemPrice;
			
		if (scan.yourBestPrice <= absBestPrice and scan.yourWorstPrice > absBestPrice) then
			icon = "|TInterface\\AddOns\\Auctionator\\Images\\CrossAndCheck:18:18:0:0|t "
			undercutFound = true;
		elseif (scan.yourBestPrice <= absBestPrice) then
			icon = "|TInterface\\RAIDFRAME\\\ReadyCheck-Ready:18:18:0:0|t "
		else
			icon = "|TInterface\\RAIDFRAME\\\ReadyCheck-NotReady:18:18:0:0|t "
			undercutFound = true;
		end
	end

	if (gAtr_CheckingActive_State ~= ATR_CACT_NULL and undercutFound) then
		gAtr_CheckingActive_NumUndercuts = gAtr_CheckingActive_NumUndercuts + 1;
	end

	return icon;

end

-----------------------------------------

function Atr_DisplayHlist ()

	if (Atr_IsTabSelected (BUY_TAB)) then		-- done this way because OnScrollFrame always calls Atr_DisplayHlist
		Atr_DisplaySlist();
		return;
	end

	local doFull = (UIDropDownMenu_GetSelectedValue(Atr_DropDown1) == MODE_LIST_ALL);

	Atr_BuildGlobalHistoryList (doFull);
	
	local numrows = #gHistoryItemList;

	local line;							-- 1 through NN of our window to scroll
	local dataOffset;					-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (Atr_Hlist_ScrollFrame, numrows, ITEM_HIST_NUM_LINES, 16);

	for line = 1,ITEM_HIST_NUM_LINES do

		gCurrentPane.hlistScrollOffset = FauxScrollFrame_GetOffset (Atr_Hlist_ScrollFrame);
		
		dataOffset = line + gCurrentPane.hlistScrollOffset;

		local lineEntry = getglobal ("AuctionatorHEntry"..line);

		lineEntry:SetID(dataOffset);

		if (dataOffset <= numrows and gHistoryItemList[dataOffset]) then

			local lineEntry_text = getglobal("AuctionatorHEntry"..line.."_EntryText");

			local iName = gHistoryItemList[dataOffset];

			local icon = "";
			
			if (not doFull) then
				icon = Atr_GetUCIcon (iName);
			end

			lineEntry_text:SetText	(icon..Atr_AbbrevItemName (iName));


			if (iName == gCurrentPane.activeSearch.searchText) then
				lineEntry:SetButtonState ("PUSHED", true);
			else
				lineEntry:SetButtonState ("NORMAL", false);
			end

			lineEntry:Show();
		else
			lineEntry:Hide();
		end
	end


end

-----------------------------------------

function Atr_ClearHlist ()
	local line;
	for line = 1,ITEM_HIST_NUM_LINES do
		local lineEntry = getglobal ("AuctionatorHEntry"..line);
		lineEntry:Hide();
		
		local lineEntry_text = getglobal("AuctionatorHEntry"..line.."_EntryText");
		lineEntry_text:SetText		("");
		lineEntry_text:SetTextColor	(.7,.7,.7);
	end

end

-----------------------------------------

function Atr_HEntryOnClick(itemName)

	if (gCurrentPane == gShopPane) then
		Atr_SEntryOnClick();
		return;
	end

	if (not itemName) then
		local line = this;

		if (gHentryTryAgain) then
			line = gHentryTryAgain;
			gHentryTryAgain = nil;
		end

		local _, itemLink;
		local entryIndex = line:GetID();
		
		itemName = gHistoryItemList[entryIndex];
	end

	if (IsAltKeyDown() and Atr_IsModeActiveAuctions()) then
		Atr_Cancel_Undercuts_OnClick (itemName)
		return;
	end
	
	if (AUCTIONATOR_PRICING_HISTORY[itemName]) then
		local itemId, suffixId, uniqueId = strsplit(":", AUCTIONATOR_PRICING_HISTORY[itemName]["is"])

		local itemId	= tonumber(itemId);

		if (suffixId == nil) then	suffixId = 0;
		else		 				suffixId = tonumber(suffixId);
		end

		if (uniqueId == nil) then	uniqueId = 0;
		else		 				uniqueId = tonumber(suffixId);
		end

		local itemString = "item:"..itemId..":0:0:0:0:0:"..suffixId..":"..uniqueId;

		_, itemLink = GetItemInfo(itemString);

		if (itemLink == nil) then		-- pull it into the cache and go back to the idle loop to wait for it to appear
			AtrScanningTooltip:SetHyperlink(itemString);
			gHentryTryAgain = line;
			zc.msg_dev ("pulling "..itemName.." into the local cache");
			return;
		end
	end
	
	gCurrentPane.UINeedsUpdate = true;
	
	Atr_ClearAll();
	
	local cacheHit = gCurrentPane:DoSearch (itemName, true, 300);

	Atr_Process_Historydata ();
	Atr_FindBestHistoricalAuction ();

	Atr_DisplayHlist();	 -- for the highlight

	if (cacheHit) then
		Atr_OnSearchComplete();
	end

	PlaySound ("igMainMenuOptionCheckBoxOn");
end

-----------------------------------------

function Atr_ShowWhichRB (id)

	if (gCurrentPane.activeSearch and gCurrentPane.activeSearch.processing_state ~= KM_NULL_STATE) then		-- if we're scanning auctions don't respond
		return;
	end

	PlaySound("igMainMenuOptionCheckBoxOn");

	if (id == 1) then
		gCurrentPane:SetToShowCurrent();
	elseif (id == 2) then
		gCurrentPane:SetToShowHistory();
	else
		gCurrentPane:SetToShowHints();
	end
	
	gCurrentPane.UINeedsUpdate = true;
	Atr_UpdateUI();

end


-----------------------------------------

function Atr_RedisplayAuctions ()

	if (Atr_ShowingSearchSummary()) then
		Atr_ShowSearchSummary();
	elseif (Atr_ShowingCurrentAuctions()) then
		Atr_ShowCurrentAuctions();
	elseif Atr_ShowingHistory() then
		Atr_ShowHistory();
	else
		Atr_ShowHints();
	end
end

-----------------------------------------

function Atr_BuildHistItemText(data)

	local stacktext = "";
--	if (data.stackSize > 1) then
--		stacktext = " (stack of "..data.stackSize..")";
--	end

	local now		= time();
	local nowtime	= date ("*t");

	local when		= data.when;
	local whentime	= date ("*t", when);

	local numauctions = data.stackSize;

	local datestr = "";

	if (data.type == "hy") then
		return ZT("average of your auctions for").." "..whentime.year;
	elseif (data.type == "hm") then
		if (nowtime.year == whentime.year) then
			return ZT("average of your auctions for").." "..date("%B", when);
		else
			return ZT("average of your auctions for").." "..date("%B %Y", when);
		end
	elseif (data.type == "hd") then
		return ZT("average of your auctions for").." "..monthDay(whentime);
	else
		return ZT("your auction on").." "..monthDay(whentime)..date(" at %I:%M %p", when);
	end
end

-----------------------------------------

function monthDay (when)

	local t = time(when);

	local s = date("%b ", t);

	return s..when.day;

end

-----------------------------------------

function Atr_ShowLineTooltip (self)

	local itemLink = self.itemLink;
		
	if (itemLink) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -280);
		GameTooltip:SetHyperlink (itemLink, 1);
	end
end

-----------------------------------------

function Atr_HideLineTooltip (self)
	GameTooltip:Hide();
end


-----------------------------------------

function Atr_Onclick_Back ()

	gCurrentPane.activeScan = Atr_FindScan (nil);
	gCurrentPane.UINeedsUpdate = true;

end

-----------------------------------------



-----------------------------------------

function Atr_Onclick_Col1 ()

	if (gCurrentPane.activeSearch) then
		gCurrentPane.activeSearch:ClickPriceCol();
		gCurrentPane.UINeedsUpdate = true;
	elseif (gCurrentPane.sortedHist) then
		if (gCurrentPane.activeSearch.sortHow == ATR_SORTBY_PRICE_ASC) then
			gCurrentPane.activeSearch.sortHow = ATR_SORTBY_PRICE_DES;
		else
			gCurrentPane.activeSearch.sortHow = ATR_SORTBY_PRICE_ASC;
		end
		table.sort(gCurrentPane.sortedHist, function(a, b)
			if (gCurrentPane.activeSearch.sortHow == ATR_SORTBY_PRICE_ASC) then
				return a.itemPrice < b.itemPrice;
			else
				return a.itemPrice > b.itemPrice;
			end
		end);
		gCurrentPane.UINeedsUpdate = true;
	end

end

-----------------------------------------

function Atr_Onclick_Col3 ()

	if (gCurrentPane.activeSearch) then
		gCurrentPane.activeSearch:ClickNameCol();
		gCurrentPane.UINeedsUpdate = true;
	elseif (gCurrentPane.sortedHist) then
		if (gCurrentPane.activeSearch.sortHow == ATR_SORTBY_NAME_ASC) then
			gCurrentPane.activeSearch.sortHow = ATR_SORTBY_NAME_DES;
		else
			gCurrentPane.activeSearch.sortHow = ATR_SORTBY_NAME_ASC;
		end
		table.sort(gCurrentPane.sortedHist, function(a, b)
			if (gCurrentPane.activeSearch.sortHow == ATR_SORTBY_NAME_ASC) then
				return string.lower(a.itemName) < string.lower(b.itemName);
			else
				return string.lower(a.itemName) > string.lower(b.itemName);
			end
		end);
		gCurrentPane.UINeedsUpdate = true;
	end

end

-----------------------------------------

function Atr_ShowSearchSummary()
       Atr_HideAllColumns();
	if (gCurrentPane.activeSearch) then
		gCurrentPane.activeSearch:UpdateArrows();
	end

	local numrows = gCurrentPane.activeSearch:NumScans();

	local highIndex  = 0;
	local line		 = 0;															-- 1 through 12 of our window to scroll
	local dataOffset = FauxScrollFrame_GetOffset (AuctionatorScrollFrame);			-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (AuctionatorScrollFrame, numrows, 12, 16);

	while (line < 12) do

		dataOffset	= dataOffset + 1;
		line		= line + 1;

		local lineEntry = getglobal ("AuctionatorEntry"..line);

		lineEntry:SetID(dataOffset);

		local scn;
		
		if (gCurrentPane.activeSearch and gCurrentPane.activeSearch:NumSortedScans() > 0) then
			scn = gCurrentPane.activeSearch.sortedScans[dataOffset];
		end
		
		if (dataOffset > numrows or not scn) then

			lineEntry:Hide();

		else
			local data = scn.absoluteBest;

			local lineEntry_item_tag = "AuctionatorEntry"..line.."_PerItem_Price";

			local lineEntry_item		= getglobal(lineEntry_item_tag);
			local lineEntry_itemtext	= getglobal("AuctionatorEntry"..line.."_PerItem_Text");
			local lineEntry_text		= getglobal("AuctionatorEntry"..line.."_EntryText");
			local lineEntry_stack		= getglobal("AuctionatorEntry"..line.."_StackPrice");

			lineEntry_itemtext:SetText	("");
			lineEntry_text:SetText	("");
			lineEntry_stack:SetText	("");

			lineEntry_text:GetParent():SetPoint ("LEFT", 157, 0);
			
			Atr_SetMFcolor (lineEntry_item_tag);
			
			lineEntry:Show();

			lineEntry.itemLink = scn.itemLink;
			
			local r = scn.itemTextColor[1];
			local g = scn.itemTextColor[2];
			local b = scn.itemTextColor[3];
			
			lineEntry_text:SetTextColor (r, g, b);
			lineEntry_stack:SetTextColor (1, 1, 1);
			
			local icon = Atr_GetUCIcon (scn.itemName);
			
			lineEntry_text:SetText (icon.."  "..scn.itemName);
			lineEntry_stack:SetText (scn:GetNumAvailable().." "..ZT("available"));
			
			if (data == nil or data.buyoutPrice == 0) then
				lineEntry_item:Hide();
				lineEntry_itemtext:Show();
				lineEntry_itemtext:SetText (ZT("no buyout price"));
			else
				lineEntry_item:Show();
				lineEntry_itemtext:Hide();
				MoneyFrame_Update (lineEntry_item_tag, zc.round(data.buyoutPrice/data.stackSize) );
			end
			
			if (zc.StringSame (scn.itemName , gCurrentPane.SS_hilite_itemName)) then
				highIndex = dataOffset;
			end


		end
	end
	
	Atr_HighlightEntry (highIndex);		-- need this for when called from onVerticalScroll

end

-----------------------------------------

function Atr_ShowCurrentAuctions()
       Atr_HideAllColumns();

       local numrows = #gCurrentPane.activeScan.sortedData;

       if (numrows > 0) then
               Atr_ShowAllColumns();
               Atr_UpdateBrowseArrows();

               if (gCurrentPane.activeSearch) then
                       gCurrentPane.activeSearch:UpdateArrows();
               end
       end

	local line		 = 0;															-- 1 through 12 of our window to scroll
	local dataOffset = FauxScrollFrame_GetOffset (AuctionatorScrollFrame);			-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (AuctionatorScrollFrame, numrows, 12, 16);

	while (line < 12) do

		dataOffset	= dataOffset + 1;
		line		= line + 1;

		local lineEntry = getglobal ("AuctionatorEntry"..line);

		lineEntry:SetID(dataOffset);

		lineEntry.itemLink = nil;

		if (dataOffset > numrows or not gCurrentPane.activeScan.sortedData[dataOffset]) then

			lineEntry:Hide();

		else
			local data = gCurrentPane.activeScan.sortedData[dataOffset];

			local lineEntry_item_tag = "AuctionatorEntry"..line.."_PerItem_Price";

			local lineEntry_item		= getglobal(lineEntry_item_tag);
			local lineEntry_itemtext	= getglobal("AuctionatorEntry"..line.."_PerItem_Text");
			local lineEntry_bid			= getglobal("AuctionatorEntry"..line.."_CurrentBid_Price");

			lineEntry_itemtext:SetText	("");

			Atr_SetMFcolor (lineEntry_item_tag);

			if (data.type == "n") then

				lineEntry:Show();
								
				local lineEntry_quantity	= getglobal("AuctionatorEntry"..line.."_Quantity_Text");
				--local quantity_text = string.format ("%i = %i %s %i", data.count * data.stackSize, data.count, ZT ("stacks of"), data.stackSize);			
				local quantity_text = string.format ("%i %s %i = %i", data.count, ZT ("stacks of"), data.stackSize, data.count * data.stackSize);			
				lineEntry_quantity:SetText(quantity_text);

				-- Show buyout price per item
				if (data.buyoutPrice == 0) then
					lineEntry_item:Hide();
					lineEntry_itemtext:Show();
					lineEntry_itemtext:SetText (ZT("no buyout price"));
				else
					lineEntry_item:Show();
					lineEntry_itemtext:Hide();
					MoneyFrame_Update(lineEntry_item_tag, zc.round(data.buyoutPrice/data.stackSize));
				end

				-- Show next possible bid per item
				if (data.nextBidPerItem) then
					lineEntry_bid:Show();
					MoneyFrame_Update(lineEntry_bid, zc.round(data.nextBidPerItem));
					-- if (data.hasActiveBids) then
					-- 	lineEntry_bid:SetAlpha(1.0); -- Full opacity for active auctions
					-- else
					-- 	lineEntry_bid:SetAlpha(0.6); -- Dimmed for starting bid
					-- end
				else
					lineEntry_bid:Hide();
				end

				local lineEntry_timeLeft	= getglobal("AuctionatorEntry"..line.."_TimeLeft_Text");
				lineEntry_timeLeft:SetText(data.timeLeftStr);

				local lineEntry_owner	= getglobal("AuctionatorEntry"..line.."_Owner_Text");
				lineEntry_owner:SetText(data.owner);

				lineEntry:SetBackdropColor(0, 0, 0, 0)
				if data.yours then
				    lineEntry:SetBackdropColor(0.3, 0.3, 1.0, 0.5)
				elseif data.highBidder then
				    lineEntry:SetBackdropColor(0.3, 1.0, 0.3, 0.5)
				end

			else
				zc.msg_red ("Unknown datatype:");
				zc.msg_red (data.type);
			end
		end
	end
	
	Atr_HighlightEntry (gCurrentPane.currIndex);		-- need this for when called from onVerticalScroll
end

-----------------------------------------

function Atr_ShowHistory ()

	if (gCurrentPane.sortedHist == nil) then
		Atr_Process_Historydata ();
		Atr_FindBestHistoricalAuction ();
	end
		
	Atr_HideAllColumns();

	local stacksCol = BROWSE_COLUMNS[#BROWSE_COLUMNS];
	if stacksCol and stacksCol.button then
		stacksCol.button:SetText (ZT("History"));
	end

	local numrows = gCurrentPane.sortedHist and #gCurrentPane.sortedHist or 0;

	if (numrows > 0) then
		local bidCol = BROWSE_COLUMNS[1];
		if bidCol and bidCol.button then bidCol.button:Show(); end
		if stacksCol and stacksCol.button then stacksCol.button:Show(); end

		if (not gCurrentPane.activeSearch) then
			gCurrentPane.activeSearch = {};
			gCurrentPane.activeSearch.sortHow = ATR_SORTBY_PRICE_ASC;
			gCurrentPane.activeSearch.UpdateArrows = AtrSearch.UpdateArrows;
		end
		gCurrentPane.activeSearch:UpdateArrows();
	end

	local line;							-- 1 through 12 of our window to scroll
	local dataOffset;					-- an index into our data calculated from the scroll offset

	FauxScrollFrame_Update (AuctionatorScrollFrame, numrows, 12, 16);

	for line = 1,12 do

		dataOffset = line + FauxScrollFrame_GetOffset (AuctionatorScrollFrame);

		local lineEntry = getglobal ("AuctionatorEntry"..line);

		lineEntry:SetID(dataOffset);

		if (dataOffset <= numrows and gCurrentPane.sortedHist[dataOffset]) then

			local data = gCurrentPane.sortedHist[dataOffset];

			local lineEntry_item_tag = "AuctionatorEntry"..line.."_PerItem_Price";

			local lineEntry_item		= getglobal(lineEntry_item_tag);
			local lineEntry_itemtext	= getglobal("AuctionatorEntry"..line.."_PerItem_Text");
			local lineEntry_text		= getglobal("AuctionatorEntry"..line.."_EntryText");
			local lineEntry_stack		= getglobal("AuctionatorEntry"..line.."_StackPrice");

			if lineEntry_item then
				lineEntry_item:Show();
			end
			if lineEntry_itemtext then
				lineEntry_itemtext:Hide();
			end
			if lineEntry_stack then
				lineEntry_stack:SetText	("");
			end

			Atr_SetMFcolor (lineEntry_item_tag);

			MoneyFrame_Update (lineEntry_item_tag, zc.round(data.itemPrice) );

			lineEntry_text:SetText (Atr_BuildHistItemText (data));
			lineEntry_text:SetTextColor (0.8, 0.8, 1.0);

			lineEntry:Show();
		else
			lineEntry:Hide();
		end
	end

	if (Atr_IsTabSelected (SELL_TAB)) then
		Atr_HighlightEntry (gCurrentPane.histIndex);		-- need this for when called from onVerticalScroll
	else
		Atr_HighlightEntry (-1);
	end
end


-----------------------------------------

function Atr_FindBestCurrentAuction()

	local scan = gCurrentPane.activeScan;
	
	if		(Atr_IsModeCreateAuction()) then	gCurrentPane.currIndex = scan:FindCheapest ();
	elseif	(Atr_IsModeBuy()) then				gCurrentPane.currIndex = scan:FindCheapest ();
	else										gCurrentPane.currIndex = scan:FindMatchByYours ();
	end

end

-----------------------------------------

function Atr_FindBestHistoricalAuction()

	gCurrentPane.histIndex = nil;

	if (gCurrentPane.sortedHist and #gCurrentPane.sortedHist > 0) then
		gCurrentPane.histIndex = 1;
	end
end

-----------------------------------------

function Atr_HighlightEntry(entryIndex)

	local line;				-- 1 through 12 of our window to scroll

	for line = 1,12 do

		local lineEntry = getglobal ("AuctionatorEntry"..line);

		if (lineEntry:GetID() == entryIndex) then
			lineEntry:SetButtonState ("PUSHED", true);
		else
			lineEntry:SetButtonState ("NORMAL", false);
		end
	end

	local doEnableCancel = false;
	local doEnableBuy = false;
	local data;
	
	if (Atr_ShowingCurrentAuctions() and entryIndex ~= nil and entryIndex > 0 and entryIndex <= #gCurrentPane.activeScan.sortedData) then
		data = gCurrentPane.activeScan.sortedData[entryIndex];
		if (data.yours) then
			doEnableCancel = true;
		end
		
		if (not data.yours and not data.altname and data.buyoutPrice > 0) then
			doEnableBuy = true;
		end
	end

	Atr_Buy1_Button:Disable();
	Atr_CancelSelectionButton:Disable();
	
	if (doEnableCancel) then
		Atr_CancelSelectionButton:Enable();

		if (data.count == 1) then
			Atr_CancelSelectionButton:SetText (CANCEL_AUCTION);
		else
			Atr_CancelSelectionButton:SetText (ZT("Cancel Auctions"));
		end
	end

	if (doEnableBuy) then
		Atr_Buy1_Button:Enable();
	end
	
end

-----------------------------------------

function Atr_EntryOnClick()

	local entryIndex = this:GetID();

	if     (Atr_ShowingSearchSummary()) 	then	
	elseif (Atr_ShowingCurrentAuctions())	then		gCurrentPane.currIndex = entryIndex;
	elseif (Atr_ShowingHistory())			then		gCurrentPane.histIndex = entryIndex;
	else												gCurrentPane.hintsIndex = entryIndex;
	end

	if (Atr_ShowingSearchSummary()) then
		local scn = gCurrentPane.activeSearch.sortedScans[entryIndex];

		FauxScrollFrame_SetOffset (AuctionatorScrollFrame, 0);
		gCurrentPane.activeScan = scn;
		gCurrentPane.currIndex = scn:FindMatchByYours ();
		gCurrentPane.SS_hilite_itemName = scn.itemName;
		gCurrentPane.UINeedsUpdate = true;
	else
		Atr_HighlightEntry (entryIndex);
		Atr_UpdateRecommendation(true);
	end

	PlaySound ("igMainMenuOptionCheckBoxOn");
end

-----------------------------------------

function AuctionatorMoneyFrame_OnLoad()

	this.small = 1;
	MoneyFrame_SetType(this, "AUCTION");
end


-----------------------------------------

function Atr_GetNumItemInBags (theItemName)

	local numItems = 0;
	local b, bagID, slotID, numslots;
	
	for b = 1, #kBagIDs do
		bagID = kBagIDs[b];
		
		numslots = GetContainerNumSlots (bagID);
		for slotID = 1,numslots do
			local itemLink = GetContainerItemLink(bagID, slotID);
			if (itemLink) then
				local itemName				= GetItemInfo(itemLink);
				local texture, itemCount	= GetContainerItemInfo(bagID, slotID);

				if (itemName == theItemName) then
					numItems = numItems + itemCount;
				end
			end
		end
	end

	return numItems;

end

-----------------------------------------

function Atr_CancelAuction(x, itemLink, stackSize, buyoutPrice)
	CancelAuction(x);
	
	local SSstring = "";
	if (stackSize and stackSize > 1) then
		SSstring = "|cff00ddddx"..stackSize;
	end
	
	zc.msg_yellow (ZT("Auction cancelled for ")..itemLink..SSstring);
end

-----------------------------------------

function Atr_CancelSelection_OnClick()

	if (not Atr_ShowingCurrentAuctions()) then
		return;
	end
	
	Atr_CancelAuction_ByIndex (gCurrentPane.currIndex);
end

-----------------------------------------

function Atr_CancelAuction_ByIndex(index)

	local data = gCurrentPane.activeScan.sortedData[index];

	if (not data.yours) then
		return;
	end

	local i = 1;

	while (true) do
		local name, texture, count, quality, canUse, level,
		minBid, minIncrement, buyoutPrice, bidAmount,
		highBidder, owner = GetAuctionItemInfo ("owner", i);

		if (name == nil) then
			break;
		end

		if (name == gCurrentPane.activeScan.itemName and buyoutPrice == data.buyoutPrice and count == data.stackSize) then
			Atr_CancelAuction (i, gCurrentPane.activeScan.itemLink, data.stackSize, data.buyoutPrice);
			AuctionatorSubtractFromScan (name, count, buyoutPrice);
			gJustPosted_ItemName = nil;
		end

		i = i + 1;
	end

end

-----------------------------------------

function Atr_StackingPrefs_Init ()

	AUCTIONATOR_STACKING_PREFS = {};                
end

-----------------------------------------

function Atr_Has_StackingPrefs (key)

	local lkey = key:lower();

	return (AUCTIONATOR_STACKING_PREFS[lkey] ~= nil);            
end

-----------------------------------------

function Atr_Clear_StackingPrefs (key)

	local lkey = key:lower();

	AUCTIONATOR_STACKING_PREFS[lkey] = nil;            
end

-----------------------------------------

function Atr_Get_StackingPrefs (key)

	local lkey = key:lower();

	if (Atr_Has_StackingPrefs(lkey)) then
		return AUCTIONATOR_STACKING_PREFS[lkey].numstacks, AUCTIONATOR_STACKING_PREFS[lkey].stacksize;            
	end

	return nil, nil;

end

-----------------------------------------

function Atr_Set_StackingPrefs_numstacks (key, numstacks)

	local lkey = key:lower();

	if (not Atr_Has_StackingPrefs(lkey)) then
		AUCTIONATOR_STACKING_PREFS[lkey] = { stacksize = 0 };
	end

	AUCTIONATOR_STACKING_PREFS[lkey].numstacks = zc.Val (numstacks, 1);            
end

-----------------------------------------

function Atr_Set_StackingPrefs_stacksize (key, stacksize)

	local lkey = key:lower();

	if (not Atr_Has_StackingPrefs(lkey)) then
		AUCTIONATOR_STACKING_PREFS[lkey] = { numstacks = 0};
	end

	AUCTIONATOR_STACKING_PREFS[lkey].stacksize = zc.Val (stacksize, 1);            
end

-----------------------------------------

function Atr_GetStackingPrefs_ByItem (itemLink)

	if (itemLink) then
	
		local itemName = GetItemInfo (itemLink);
		local text, spinfo;
		
		for text, spinfo in pairs (AUCTIONATOR_STACKING_PREFS) do

			if (zc.StringContains (itemName, text)) then
				return spinfo.numstacks, spinfo.stacksize;
			end
		end
		
		if		(Atr_IsGlyph (itemLink))								then		return Atr_Special_SP (ATR_SK_GLYPHS, 0, 1);
		elseif	(Atr_IsCutGem (itemLink))								then		return Atr_Special_SP (ATR_SK_GEMS_CUT, 0, 1);
		elseif	(Atr_IsGem (itemLink))									then		return Atr_Special_SP (ATR_SK_GEMS_UNCUT, 1, 0);
		elseif	(Atr_IsItemEnhancement (itemLink))						then		return Atr_Special_SP (ATR_SK_ITEM_ENH, 0, 1);
		elseif	(Atr_IsPotion (itemLink) or Atr_IsElixir (itemLink))	then		return Atr_Special_SP (ATR_SK_POT_ELIX, 1, 0);
		elseif	(Atr_IsFlask (itemLink))								then		return Atr_Special_SP (ATR_SK_FLASKS, 1, 0);
		elseif	(Atr_IsHerb (itemLink))									then		return Atr_Special_SP (ATR_SK_HERBS, 1, 0);
		end
	end
	
	return nil, nil;
end

-----------------------------------------

function Atr_Special_SP (key, numstack, stacksize)

	if (Atr_Has_StackingPrefs (key)) then
		return Atr_Get_StackingPrefs(key);
	end
	
	return numstack, stacksize;
end

-----------------------------------------

function Atr_GetSellStacking (itemLink, numDragged, numTotal)

	local prefNumStacks, prefStackSize = Atr_GetStackingPrefs_ByItem (itemLink);
	
	if (prefNumStacks == nil) then
		return 1, numDragged;
	end
	
	if (prefNumStacks <= 0 and prefStackSize <= 0) then		-- shouldn't happen but just in case
		prefStackSize = 1;
	end

--zc.msg (prefNumStacks, prefStackSize);

	local numStacks = prefNumStacks;
	local stackSize = prefStackSize;
	local numToSell = numDragged;
	
	if (numStacks == -1) then		-- max number of stacks
		numToSell = numTotal;

	elseif (stackSize == 0) then		-- auto stacksize
		stackSize = math.floor (numDragged / numStacks);
	
	elseif (numStacks > 0) then
		numToSell = math.min (numStacks * stackSize, numTotal);
	end

	numStacks = math.floor (numToSell / stackSize);

--zc.msg_pink (numStacks, stackSize);
	
	if (numStacks == 0) then
		numStacks = 1;
		stackSize = numToSell;
--zc.msg_red (numStacks, stackSize);
	end
	
	return numStacks, stackSize;

end



-----------------------------------------

local gInitial_NumStacks;
local gInitial_StackSize;

-----------------------------------------

function Atr_SetInitialStacking (numStacks, stackSize)

	gInitial_NumStacks = numStacks;
	gInitial_StackSize = stackSize;

	Atr_Batch_NumAuctions:SetText (numStacks);
	Atr_SetStackSize (stackSize);
end

-----------------------------------------

function Atr_Memorize_Stacking_If ()

	local newNumStacks = Atr_Batch_NumAuctions:GetNumber();
	local newStackSize = Atr_StackSize();
	
	local numStacksChanged = (tonumber (gInitial_NumStacks) ~= newNumStacks);
	local stackSizeChanged = (tonumber (gInitial_StackSize) ~= newStackSize);

	if (stackSizeChanged) then
	
		local itemName = string.lower(gCurrentPane.activeScan.itemName);

		if (itemName) then

			-- see if user is trying to set it back to default
			
			if (newNumStacks == 1) then
				local _, _, auctionCount = GetAuctionSellItemInfo();
				if (auctionCount == newStackSize) then
					Atr_Clear_StackingPrefs (itemName);
					return;
				end
			end
			
			-- else remember the new stack size
			
			Atr_Set_StackingPrefs_stacksize (itemName, Atr_StackSize());
		end
	end
end




-----------------------------------------

function Atr_Duration_OnLoad(self)
	UIDropDownMenu_Initialize (self, Atr_Duration_Initialize);
	UIDropDownMenu_SetSelectedValue (Atr_Duration, 1);
end

-----------------------------------------

function Atr_Duration_Initialize()

	local info = UIDropDownMenu_CreateInfo();

	info.text = AUCTION_DURATION_ONE;
	info.value = 1;
	info.checked = nil;
	info.func = Atr_Duration_OnClick;
	UIDropDownMenu_AddButton(info);

	info.text = AUCTION_DURATION_TWO;
	info.value = 2;
	info.checked = nil;
	info.func = Atr_Duration_OnClick;
	UIDropDownMenu_AddButton(info);

	info.text = AUCTION_DURATION_THREE;
	info.value = 3;
	info.checked = nil;
	info.func = Atr_Duration_OnClick;
	UIDropDownMenu_AddButton(info);

end

-----------------------------------------

function Atr_Duration_OnClick(self)

	UIDropDownMenu_SetSelectedValue(Atr_Duration, self.value);
	Atr_SetDepositText();
end

-----------------------------------------

function Atr_DropDown1_OnLoad (self)
	UIDropDownMenu_Initialize(self, Atr_DropDown1_Initialize);
	UIDropDownMenu_SetSelectedValue(Atr_DropDown1, MODE_LIST_ACTIVE);
	Atr_DropDown1:Show();
end

-----------------------------------------

function Atr_DropDown1_Initialize()
	local info = UIDropDownMenu_CreateInfo();
	
	info.text = ZT("Active Items");
	info.value = MODE_LIST_ACTIVE;
	info.func = Atr_DropDown1_OnClick;
	info.owner = this:GetParent();
	info.checked = nil;
	UIDropDownMenu_AddButton(info);

	info.text = ZT("All Items");
	info.value = MODE_LIST_ALL;
	info.func = Atr_DropDown1_OnClick;
	info.owner = this:GetParent();
	info.checked = nil;
	UIDropDownMenu_AddButton(info);

end

-----------------------------------------

function Atr_DropDown1_OnClick(self)
	
	UIDropDownMenu_SetSelectedValue(self.owner, self.value);
	
	local mode = self.value;
	
	if (mode == MODE_LIST_ALL) then
		Atr_DisplayHlist();
	end
	
	if (mode == MODE_LIST_ACTIVE) then
		Atr_DisplayHlist();
	end
	
end



-----------------------------------------

function Atr_AddMenuPick (info, text, value, func)

	info.text			= text;
	info.value			= value;
	info.func			= func;
	info.checked		= nil;
	info.owner			= this:GetParent();
	UIDropDownMenu_AddButton(info);

end



-----------------------------------------

function Atr_IsTabSelected(whichTab)

	if (not AuctionFrame or not AuctionFrame:IsShown()) then
		return false;
	end

	if (not whichTab) then
		return (Atr_IsTabSelected(SELL_TAB) or Atr_IsTabSelected(MORE_TAB) or Atr_IsTabSelected(BUY_TAB));
	end

	return (PanelTemplates_GetSelectedTab (AuctionFrame) == Atr_FindTabIndex(whichTab));
end

-----------------------------------------

function Atr_IsAuctionatorTab (tabIndex)

	if (tabIndex == Atr_FindTabIndex(SELL_TAB) or tabIndex == Atr_FindTabIndex(MORE_TAB) or tabIndex == Atr_FindTabIndex(BUY_TAB) ) then

		return true;

	end

	return false;
end

-----------------------------------------

function Atr_Confirm_Yes()

	if (Atr_Confirm_Proc_Yes) then
		Atr_Confirm_Proc_Yes();
		Atr_Confirm_Proc_Yes = nil;
	end

	Atr_Confirm_Frame:Hide();

end


-----------------------------------------

function Atr_Confirm_No()

	Atr_Confirm_Frame:Hide();

end


-----------------------------------------

function Atr_AddHistoricalPrice (itemName, price, stacksize, itemLink, testwhen)

	if (not AUCTIONATOR_PRICING_HISTORY[itemName] ) then
		AUCTIONATOR_PRICING_HISTORY[itemName] = {};
	end

	local itemId, suffixId, uniqueId = zc.ItemIDfromLink (itemLink);

	local is = itemId;

	if (suffixId ~= 0) then
		is = is..":"..suffixId;
		if (tonumber(suffixId) < 0) then
			is = is..":"..uniqueId;
		end
	end

	AUCTIONATOR_PRICING_HISTORY[itemName]["is"]  = is;

	local hist = tostring (zc.round (price))..":"..stacksize;

	local roundtime = floor (time() / 60) * 60;		-- so multiple auctions close together don't generate too many entries

	local tag = tostring(ToTightTime(roundtime));

	if (testwhen) then
		tag = tostring(ToTightTime(testwhen));
	end

	AUCTIONATOR_PRICING_HISTORY[itemName][tag] = hist;

	gCurrentPane.sortedHist = nil;

end

-----------------------------------------

function Atr_HasHistoricalData (itemName)

	if (AUCTIONATOR_PRICING_HISTORY[itemName] ) then
		return true;
	end

	return false;
end


-----------------------------------------

function Atr_BuildGlobalHistoryList(full)

	gHistoryItemList	= {};
	
	local n = 1;

	if (full) then
		for name,hist in pairs (AUCTIONATOR_PRICING_HISTORY) do
			gHistoryItemList[n] = name;
			n = n + 1;
		end
	else
		if (zc.tableIsEmpty (gActiveAuctions)) then
			Atr_BuildActiveAuctions();
		end

		local name;
		for name, count in pairs (gActiveAuctions) do
			if (name and count ~= 0) then
				gHistoryItemList[n] = name;
				n = n + 1;
			end
		end
	end
	
	table.sort (gHistoryItemList);
end



-----------------------------------------

function Atr_FindHListIndexByName (itemName)

	local x;
	
	for x = 1, #gHistoryItemList do
		if (itemName == gHistoryItemList[x]) then
			return x;
		end
	end

	return 0;
	
end

-----------------------------------------

local gAtr_CheckingActive_State			= ATR_CACT_NULL;
local gAtr_CheckingActive_Index;
local gAtr_CheckingActive_NextItemName;
local gAtr_CheckingActive_AndCancel		= false;

gAtr_CheckingActive_NumUndercuts	= 0;


-----------------------------------------

function Atr_CheckActive_OnClick (andCancel)

	if (gAtr_CheckingActive_State == ATR_CACT_NULL) then
	
		Atr_CheckActiveList (andCancel);
--[[
		if (andCancel == nil) then
			Atr_CheckActives_Frame:Show();
		else
			Atr_CheckActives_Frame:Hide();
			Atr_CheckActiveList (andCancel);
		end
]]--
	else		-- stop checking
		Atr_CheckingActive_Finish ();
		gCurrentPane.activeSearch:Abort();
		gCurrentPane:ClearSearch();
		Atr_SetMessage(ZT("Checking stopped"));
	end
	
end


-----------------------------------------

function Atr_CheckActiveList (andCancel)

	gAtr_CheckingActive_State			= ATR_CACT_READY;
	gAtr_CheckingActive_NextItemName	= gHistoryItemList[1];
	gAtr_CheckingActive_AndCancel		= andCancel;
	gAtr_CheckingActive_NumUndercuts	= 0;
	
	gCurrentPane:SetToShowCurrent();

	Atr_CheckingActiveIdle ();
	
end

-----------------------------------------

function Atr_CheckingActive_Finish()

	gAtr_CheckingActive_State = ATR_CACT_NULL;		-- done
	
	Atr_CheckActiveButton:SetText(ZT("Check for Undercuts"));

end



-----------------------------------------

function Atr_CheckingActiveIdle()

	if (gAtr_CheckingActive_State == ATR_CACT_READY) then
	
		if (gAtr_CheckingActive_NextItemName == nil) then
		
			Atr_CheckingActive_Finish ();

			if (gAtr_CheckingActive_NumUndercuts > 0) then
				Atr_CheckActives_Frame:Show();
			end
			
		else
			gAtr_CheckingActive_State = ATR_CACT_PROCESSING;

			Atr_CheckActiveButton:SetText(ZT("Stop Checking"));

			local itemName = gAtr_CheckingActive_NextItemName;

			local x = Atr_FindHListIndexByName (itemName);
			gAtr_CheckingActive_NextItemName = (x > 0 and #gHistoryItemList >= x+1) and gHistoryItemList[x+1] or nil;

			local cacheHit = gCurrentPane:DoSearch (itemName, true, 300);
			
			Atr_Hilight_Hentry (itemName);
			
			if (cacheHit) then
				Atr_CheckingActive_OnSearchComplete();
			end
		end
	end
end


-----------------------------------------

function Atr_CheckActive_IsBusy()

	return (gAtr_CheckingActive_State ~= ATR_CACT_NULL);
	
end

-----------------------------------------

function Atr_CheckingActive_OnSearchComplete()

	if (gAtr_CheckingActive_State == ATR_CACT_PROCESSING) then
		
		if (gAtr_CheckingActive_AndCancel) then
			zc.AddDeferredCall (0.1, "Atr_CheckingActive_CheckCancel");		-- need to defer so UI can update and show auctions about to be canceled
		else
			zc.AddDeferredCall (0.1, "Atr_CheckingActive_Next");			-- need to defer so UI can update
		end
	end
end

-----------------------------------------

function Atr_CheckingActive_CheckCancel()

	if (gAtr_CheckingActive_State == ATR_CACT_PROCESSING) then

		Atr_CancelUndercuts_CurrentScan(false);

		if (gAtr_CheckingActive_State ~= ATR_CACT_WAITING_ON_CANCEL_CONFIRM) then
			zc.AddDeferredCall (0.1, "Atr_CheckingActive_Next");		-- need to defer so UI can update
		end
	end
	
end

-----------------------------------------

function Atr_CheckingActive_Next ()

	if (gAtr_CheckingActive_State == ATR_CACT_PROCESSING) then
		gAtr_CheckingActive_State = ATR_CACT_READY;
	end
end


-----------------------------------------

function Atr_CancelUndercut_Confirm (yesCancel)
	gAtr_CheckingActive_State = ATR_CACT_PROCESSING;
	Atr_CancelAuction_Confirm_Frame:Hide();
	if (yesCancel) then
		Atr_CancelUndercuts_CurrentScan(true);
	end
	zc.AddDeferredCall (0.1, "Atr_CheckingActive_Next");
end

-----------------------------------------

function Atr_CancelUndercuts_CurrentScan(confirmed)

	local scan = gCurrentPane.activeScan;

	for x = #scan.sortedData,1,-1 do
	
		local data = scan.sortedData[x];
		
		if (data.yours and data.itemPrice > scan.absoluteBest.itemPrice) then
			
			if (not confirmed) then
				gAtr_CheckingActive_State = ATR_CACT_WAITING_ON_CANCEL_CONFIRM;
				Atr_CancelAuction_Confirm_Frame_text:SetText (string.format (ZT("Your auction has been undercut:\n%s%s"), "|cffffffff", scan.itemName));
				Atr_CancelAuction_Confirm_Frame:Show ();
				return;
			end
			
			Atr_CancelAuction_ByIndex (x);
		end
	end

end


-----------------------------------------

function Atr_Cancel_Undercuts_OnClick (nameToCancel)

	local i;
	local num = GetNumAuctionItems ("owner");
	
	for i = num, 1, -1 do
		local name, _, stackSize, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo ("owner", i);

		if (name == nil) then
			break;
		end
		
		if (nameToCancel == nil or zc.StringSame (name, nameToCancel)) then
			local scan = Atr_FindScan (name);
			if (scan and scan.absoluteBest and scan.whenScanned ~= 0 and scan.yourBestPrice and scan.yourWorstPrice) then
				
				local absBestPrice = scan.absoluteBest.itemPrice;
				
				local itemPrice = math.floor (buyoutPrice / stackSize);
		
				--	zc.msg_dev (i, name, "itemPrice: ", itemPrice, "absBestPrice: ", absBestPrice);

				if (itemPrice > absBestPrice) then

					Atr_CancelAuction (i, scan.itemLink, stackSize, buyoutPrice);
					
					if (scan.yourBestPrice > absBestPrice) then
						gActiveAuctions[name] = nil;
					end

					AuctionatorSubtractFromScan (name, stackSize, buyoutPrice);
					gJustPosted_ItemName = nil;
				end
			end
		end
	end

	Atr_DisplayHlist();
	Atr_CheckActives_Frame:Hide();
end

-----------------------------------------

function Atr_Hilight_Hentry(itemName)

	for line = 1,ITEM_HIST_NUM_LINES do

		dataOffset = line + FauxScrollFrame_GetOffset (Atr_Hlist_ScrollFrame);

		local lineEntry = getglobal ("AuctionatorHEntry"..line);

		if (dataOffset <= #gHistoryItemList and gHistoryItemList[dataOffset]) then

			if (gHistoryItemList[dataOffset] == itemName) then
				lineEntry:SetButtonState ("PUSHED", true);
			else
				lineEntry:SetButtonState ("NORMAL", false);
			end
		end
	end
end

-----------------------------------------

function Atr_Item_Autocomplete(self)

	local text = self:GetText();
	local textlen = strlen(text);
	local name;

	-- first search shopping lists

	local numLists = #AUCTIONATOR_SHOPPING_LISTS;
	local n;
	
	for n = 1,numLists do
		local slist = AUCTIONATOR_SHOPPING_LISTS[n];

		local numItems = #slist.items;

		if ( numItems > 0 ) then
			for i=1, numItems do
				name = slist.items[i];
				if ( name and text and (strfind(strupper(name), strupper(text), 1, 1) == 1) ) then
					self:SetText(name);
					if ( self:IsInIMECompositionMode() ) then
						self:HighlightText(textlen - strlen(arg1), -1);
					else
						self:HighlightText(textlen, -1);
					end
					return;
				end
			end
		end
	end
	

	-- next search history list

	numItems = #gHistoryItemList;

	if ( numItems > 0 ) then
		for i=1, numItems do
			name = gHistoryItemList[i];
			if ( name and text and (strfind(strupper(name), strupper(text), 1, 1) == 1) ) then
				self:SetText(name);
				if ( self:IsInIMECompositionMode() ) then
					self:HighlightText(textlen - strlen(arg1), -1);
				else
					self:HighlightText(textlen, -1);
				end
				return;
			end
		end
	end
end

-----------------------------------------

function Atr_GetCurrentPane ()			-- so other modules can use gCurrentPane
	return gCurrentPane;
end

-----------------------------------------

function Atr_SetUINeedsUpdate ()			-- so other modules can easily set
	gCurrentPane.UINeedsUpdate = true;
end


-----------------------------------------

function Atr_CalcUndercutPrice (price)

	if	(price > 5000000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._5000000);	end;
	if	(price > 1000000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._1000000);	end;
	if	(price >  200000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._200000);	end;
	if	(price >   50000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._50000);	end;
	if	(price >   10000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._10000);	end;
	if	(price >    2000)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._2000);	end;
	if	(price >     500)	then return roundPriceDown (price, AUCTIONATOR_SAVEDVARS._500);		end;
	if	(price >       0)	then return math.floor (price - 1);	end;

	return 0;
end

-----------------------------------------

function Atr_CalcStartPrice (buyoutPrice)

	local discount = 1.00 - (AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT / 100);

	local newStartPrice = Atr_CalcUndercutPrice(math.floor(buyoutPrice * discount));
	
	if (AUCTIONATOR_SAVEDVARS.STARTING_DISCOUNT == 0) then		-- zero means zero
		newStartPrice = buyoutPrice;
	end
	
	return newStartPrice;

end

-----------------------------------------

function Atr_AbbrevItemName (itemName)

	return string.gsub (itemName, "Scroll of Enchant", "SoE");

end

-----------------------------------------

function Atr_IsMyToon (name)

	if (name and (AUCTIONATOR_TOONS[name] or AUCTIONATOR_TOONS[string.lower(name)])) then
		return true;
	end
	
	return false;
end

-----------------------------------------

function Atr_Error_Display (errmsg)
	if (errmsg) then
		Atr_Error_Text:SetText (errmsg);
		Atr_Error_Frame:Show ();
		return;
	end
end

-----------------------------------------

function Atr_PollWho(s)

	gSendZoneMsgs = true;
	gQuietWho = time();

	SetWhoToUI(1);
	
	zc.msg_dev (s);
	
	SendWho (s);
end

-----------------------------------------

function Atr_FriendsFrame_OnEvent(self, event, ...)

	if (event == "WHO_LIST_UPDATE" and gQuietWho > 0 and time() - gQuietWho < 10) then
		return;
	end

	if (gQuietWho > 0) then
		SetWhoToUI(0);
	end
	
	gQuietWho = 0;
	
	return auctionator_orig_FriendsFrame_OnEvent (self, event, ...);

end



-----------------------------------------
-- roundPriceDown - rounds a price down to the next lowest multiple of a.
--				  - if the result is not at least a/2 lower, rounds down by a/2.
--
--	examples:  	(128790, 500)  ->  128500
--				(128700, 500)  ->  128000
--				(128400, 500)  ->  128000
-----------------------------------------

function roundPriceDown (price, a)

	if (a == 0) then
		return price;
	end

	local newprice = math.floor((price-1) / a) * a;

	if ((price - newprice) < a/2) then
		newprice = newprice - (a/2);
	end

	if (newprice == price) then
		newprice = newprice - 1;
	end

	return newprice;

end

-----------------------------------------

function ToTightHour(t)

	return floor((t - gTimeTightZero)/3600);

end

-----------------------------------------

function FromTightHour(tt)

	return (tt*3600) + gTimeTightZero;

end


-----------------------------------------

function ToTightTime(t)

	return floor((t - gTimeTightZero)/60);

end

-----------------------------------------

function FromTightTime(tt)

	return (tt*60) + gTimeTightZero;

end


--[[

- fix the bug in roundPriceDown when undercut = 0
- fix background graphic on sell pane
- update to changes in auction house API

]]--

-- =============================================
-- Debug commands
-- =============================================

function Atr_ShowDebugMessages()
	if (AtrL["Debug messages"]) then
		print("=== Отладочные сообщения ===");
		for i, msg in ipairs(AtrL["Debug messages"]) do
			print(i .. ": " .. msg);
		end
		print("=== Конец отладочных сообщений ===");
	else
		print("Нет отладочных сообщений");
	end
end

-- Register slash command
SLASH_AUCTIONATORDEBUG1 = "/atrdebug";
SlashCmdList["AUCTIONATORDEBUG"] = Atr_ShowDebugMessages;




