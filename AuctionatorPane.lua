-- AuctionatorPane.lua - part of Auctionator addon
AtrPane = {};
AtrPane.__index = AtrPane;

ATR_SHOW_CURRENT	= 1;
ATR_SHOW_HISTORY	= 2;
ATR_SHOW_HINTS		= 3;

-- Creates a new search pane instance.
function AtrPane.create ()

	local pane = {};
	setmetatable (pane,AtrPane);

	pane.fullStackSize	= 0;

	pane.totalItems		= 0;		-- total in bags for this item

	pane.UINeedsUpdate	= false;
	pane.showWhich		= ATR_SHOW_CURRENT;
	
	pane.activeSearch	= nil;
	pane.sortedHist		= nil;
	pane.hints			= nil;
	
	pane.hlistScrollOffset	= 0;
	
	pane:ClearSearch();
	
	return pane;
end


-----------------------------------------

-- Initiates a search with specified text and optional callback.
function AtrPane:DoSearch (searchText, exact, rescanThreshold, callback)

	self.currIndex			= nil;
	self.histIndex			= nil;
	self.hintsIndex			= nil;
	
	self.sortedHist			= nil;
	self.hints				= nil;
	
	self.SS_hilite_itemName	= searchText;		-- by name for search summary
	
	Atr_ClearBuyState();

	self.activeScan = Atr_FindScan (nil);
	
	Atr_ClearAll();		-- it's fast, might as well just do it now for cleaner UE
	
	self.UINeedsUpdate = false;		-- will be set when scan finishes
			
	self.activeSearch = Atr_NewSearch (searchText, exact, rescanThreshold, callback);
	
	if (exact) then
		self.activeScan = self.activeSearch:GetFirstScan();
	end
	
	local cacheHit = false;
	
	if (searchText ~= "") then
		if (self.activeScan.whenScanned == 0) then		-- check whenScanned so we don't rescan cache hits
			self.activeSearch:Start();
		else
			self.UINeedsUpdate = true;
			cacheHit = true;
		end
	end
	
	return cacheHit;
end

-----------------------------------------

-- Clears previous search results and resets the pane.
function AtrPane:ClearSearch ()
	self:DoSearch ("", true);
end

-----------------------------------------

-- Returns current processing state for the pane.
function AtrPane:GetProcessingState ()
	
	if (self.activeSearch) then
		return self.activeSearch.processing_state;
	end
	
	return KM_NULL_STATE;
end

-----------------------------------------

-- Checks if there are any results in the active scan.
function AtrPane:IsScanEmpty ()
	
	return (self.activeScan == nil or self.activeScan:IsNil());
	
end

-----------------------------------------

-- Displays the list of current auctions for the search.
function AtrPane:ShowCurrent ()
	
	return self.showWhich == ATR_SHOW_CURRENT;
	
end

-----------------------------------------

-- Displays stored price history for the item.
function AtrPane:ShowHistory ()
	
	return self.showWhich == ATR_SHOW_HISTORY;
	
end

-----------------------------------------

-- Displays search hint entries.
function AtrPane:ShowHints ()
	
	return self.showWhich == ATR_SHOW_HINTS;
	
end

-----------------------------------------

-- Sets pane state to show current auctions.
function AtrPane:SetToShowCurrent ()
	
	self.showWhich = ATR_SHOW_CURRENT;
	
end

-----------------------------------------

-- Sets pane state to show historical data.
function AtrPane:SetToShowHistory ()
	
	self.showWhich = ATR_SHOW_HISTORY;
	
	if (not self.sortedHist) then
		Atr_Process_Historydata();
		Atr_FindBestHistoricalAuction();
	end
	
end

-----------------------------------------

-- Sets pane state to show hint suggestions.
function AtrPane:SetToShowHints ()
	
	self.showWhich = ATR_SHOW_HINTS;
	
end


