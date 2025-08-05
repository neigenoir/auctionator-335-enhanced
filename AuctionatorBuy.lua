-- AuctionatorBuy.lua - part of Auctionator addon

local addonName, addonTable = ...; 
local zc = addonTable.zc;


local ATR_BUY_NULL						= 0;
local ATR_BUY_QUERY_SENT				= 1;
local ATR_BUY_JUST_BOUGHT				= 2;
local ATR_BUY_PROCESSING_QUERY_RESULTS	= 3;
local ATR_BUY_WAITING_FOR_AH_CAN_SEND	= 4;

local gBuyState = ATR_BUY_NULL;

-----------------------------------------

local gAtr_Buy_BuyoutPrice;
local gAtr_Buy_ItemName;
local gAtr_Buy_StackSize;
local gAtr_Buy_NumBought;
local gAtr_Buy_NumUserWants;
local gAtr_Buy_MaxCanBuy;
local gAtr_Buy_CurPage;
local gAtr_Buy_Waiting_Start;
local gAtr_Buy_Query;
local gAtr_Buy_Pass;

-----------------------------------------

-- Prints internal state information for debugging the buy logic.
function Atr_Buy_Debug1 (yellow)

	if (gBuyState == ATR_BUY_NULL)										then asstr = "ATR_BUY_NULL"; end;
	if (gBuyState == ATR_BUY_QUERY_SENT)								then asstr = "ATR_BUY_QUERY_SENT"; end;
	if (gBuyState == ATR_BUY_PROCESSING_QUERY_RESULTS)					then asstr = "ATR_BUY_PROCESSING_QUERY_RESULTS"; end;
	if (gBuyState == ATR_BUY_JUST_BOUGHT)								then asstr = "ATR_BUY_JUST_BOUGHT"; end;
	if (gBuyState == ATR_BUY_WAITING_FOR_AH_CAN_SEND)					then asstr = "ATR_BUY_WAITING_FOR_AH_CAN_SEND"; end;

	if (gBuyState ~= ATR_BUY_NULL) then
		if (yellow) then
			zc.msg (asstr, "curpage: ", gAtr_Buy_CurPage, "   gAtr_Buy_NumBought: ", gAtr_Buy_NumBought);
		else
			zc.msg_pink (asstr, "curpage: ", gAtr_Buy_CurPage, "   gAtr_Buy_NumBought: ", gAtr_Buy_NumBought);
		end
	end
	
end

-----------------------------------------

-- Resets the buying process to its initial state.
function Atr_ClearBuyState()

	gBuyState = ATR_BUY_NULL;

end


-----------------------------------------

-- Starts the buyout workflow for the selected auction listing.
function Atr_Buy1_Onclick ()
	gAtr_Buy_IsBid = false

	if (not Atr_ShowingCurrentAuctions()) then
		return;
	end
	
	gAtr_Buy_Query			= Atr_NewQuery();
	gAtr_Buy_NumUserWants	= -1;
	gAtr_Buy_NumBought		= 0;
	
	local currentPane = Atr_GetCurrentPane();
	
	local scan = currentPane.activeScan;
	
	local data = scan.sortedData[currentPane.currIndex];

	gAtr_Buy_BuyoutPrice	= data.buyoutPrice;
	gAtr_Buy_ItemName		= scan.itemName;
	gAtr_Buy_StackSize		= data.stackSize;
	gAtr_Buy_MaxCanBuy		= data.count;
	gAtr_Buy_Pass			= 1;		-- - first pass
	
	Atr_Buy_Confirm_ItemName:SetText (gAtr_Buy_ItemName.." x"..gAtr_Buy_StackSize);
	Atr_Buy_Confirm_Numstacks:SetNumber(gAtr_Buy_MaxCanBuy);
	Atr_Buy_Confirm_Max_Text:SetText (ZT("max")..": "..gAtr_Buy_MaxCanBuy);
	
	Atr_Buy_Part1:Show();
	Atr_Buy_Part2:Hide();
	
	Atr_Buy_Confirm_OKBut:SetText (ZT("Buy"))
	Atr_Buy_Confirm_OKBut:Disable();
	Atr_Buy_Confirm_Frame:Show();

	if (scan.searchWasExact and data.minpage ~= nil) then
		Atr_Buy_QueueQuery(data.minpage);
	else
		Atr_Buy_QueueQuery(0);
	end


end

-----------------------------------------

-- Starts the bidding workflow for the selected auction listing.
function Atr_Bid_Onclick()

	if not Atr_ShowingCurrentAuctions() then return end

	gAtr_Buy_IsBid        = true
	gAtr_Buy_Query        = Atr_NewQuery()
	gAtr_Buy_NumUserWants = -1
	gAtr_Buy_NumBought    = 0

	local currentPane = Atr_GetCurrentPane()
	local scan        = currentPane.activeScan
	local data        = scan.sortedData[currentPane.currIndex]

	local nextBid = data.nextBid           -- берём готовую цену из scan
	if not nextBid or nextBid == 0 then    -- защита
		Atr_Error_Text:SetText(ZT("Нельзя сделать ставку – у лота нет стартовой цены"))
		Atr_Error_Frame:Show()
		return
	end
	
	gAtr_Buy_BuyoutPrice = nextBid          -- теперь точно число
	
	gAtr_Buy_BuyoutPrice = nextBid              -- главное отличие от buyout
	gAtr_Buy_ItemName    = scan.itemName
	gAtr_Buy_StackSize   = data.stackSize
	gAtr_Buy_MaxCanBuy   = data.count
	gAtr_Buy_Pass        = 1

	Atr_Buy_Confirm_ItemName:SetText(gAtr_Buy_ItemName.." x"..gAtr_Buy_StackSize)
	Atr_Buy_Confirm_Numstacks:SetNumber(gAtr_Buy_MaxCanBuy)
	Atr_Buy_Confirm_Max_Text:SetText(ZT("max")..": "..gAtr_Buy_MaxCanBuy)

	Atr_Buy_Part1:Show()
	Atr_Buy_Part2:Hide()

	Atr_Buy_Confirm_OKBut:SetText(ZT("Bid"))
	Atr_Buy_Confirm_OKBut:Disable()
	Atr_Buy_Confirm_Frame:Show()

	if scan.searchWasExact and data.minpage ~= nil then
		Atr_Buy_QueueQuery(data.minpage)
	else
		Atr_Buy_QueueQuery(0)
	end
end


-----------------------------------------

-- Stores the page to query and waits until the AH can accept it.
function Atr_Buy_QueueQuery (page)

	gAtr_Buy_CurPage = page;

--zc.msg_pink ("Queuing query for page ", page);

	gBuyState = ATR_BUY_WAITING_FOR_AH_CAN_SEND;
	gAtr_Buy_Waiting_Start = time();
	
	Atr_Buy_SendQuery();		-- give it a shot
end

-----------------------------------------

-- Sends the previously queued query to the auction house.
function Atr_Buy_SendQuery ()

	if (CanSendAuctionQuery()) then

		gBuyState = ATR_BUY_QUERY_SENT;

		local queryString = zc.UTF8_Truncate (gAtr_Buy_ItemName,63);	-- attempting to reduce number of disconnects

		QueryAuctionItems (queryString, "", "", nil, 0, 0, gAtr_Buy_CurPage, nil, nil);
	end
		
end

-----------------------------------------
local prevBuyState;

-----------------------------------------

-- Waits for the AH throttle before sending the next query.
function Atr_Buy_Idle ()

	if (gBuyState ~= prevBuyState) then
		prevBuyState = gBuyState;
--		Atr_Buy_Debug1 (true);
	end
	
	if (gBuyState == ATR_BUY_WAITING_FOR_AH_CAN_SEND) then
		if not gAtr_Buy_BuyoutPrice then
			Atr_Buy_Cancel(ZT("Цена ставки не определена"))
			return
		end
		
--		zc.msg_dev ("WAITING_FOR_AH_CAN_SEND: ", time() - gAtr_Buy_Waiting_Start);
		
		if (GetMoney() < gAtr_Buy_BuyoutPrice) then
			Atr_Buy_Cancel (ZT("You do not have enough gold\n\nto make any more purchases."));
		elseif (time() - gAtr_Buy_Waiting_Start > 10) then
			Atr_Buy_Cancel (ZT("Auction House timed out"));
		else	
			Atr_Buy_SendQuery ();
		end
		
	elseif (gBuyState == ATR_BUY_JUST_BOUGHT) then

--		zc.msg_pink ("ATR_BUY_JUST_BOUGHT: ",  time() - gAtr_Buy_Waiting_Start);

		local queueIf = (time() - gAtr_Buy_Waiting_Start > 2);		-- wait a few seconds for Auction List to Update after buys
		
		Atr_Buy_NextPage_Or_Cancel (queueIf);
		
	end

end

-----------------------------------------

-- Responds to AUCTION_ITEM_LIST_UPDATE events during the buy process.
function Atr_Buy_OnAuctionUpdate()

--	Atr_Buy_Debug1();

	if (gBuyState == ATR_BUY_QUERY_SENT) then
		Atr_Buy_CheckForMatches ();
	end

	return (gBuyState ~= ATR_BUY_NULL);
end

-----------------------------------------

-- Scans query results to identify auctions matching the desired item.
function Atr_Buy_CheckForMatches ()

	gBuyState = ATR_BUY_PROCESSING_QUERY_RESULTS;
	
	if (gAtr_Buy_Query:CheckForDuplicatePage(gAtr_Buy_CurPage)) then
		Atr_Buy_QueueQuery (gAtr_Buy_CurPage);
		return;
	end

	local isLastPage = gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage);
	
	local numMatches = Atr_Buy_CountMatches();
	
	if (numMatches > 0) then		-- update the confirmation screen
	
		Atr_Buy_Confirm_OKBut:Enable();

		if (gAtr_Buy_NumUserWants ~= -1) then		
			Atr_Buy_Continue_Text:SetText (string.format (ZT("%d of %d bought so far"), gAtr_Buy_NumBought, gAtr_Buy_NumUserWants));
			Atr_Buy_Part1:Hide();
			Atr_Buy_Part2:Show();
			Atr_Buy_Confirm_OKBut:SetText (ZT("Continue"))
		end

	else
		Atr_Buy_NextPage_Or_Cancel();
	end

end


-----------------------------------------

-- Purchases matching auctions once they are identified.
function Atr_Buy_BuyMatches ()
	return Atr_Buy_CountMatches (true);
end

-----------------------------------------

-- Updates cached scan data after a bid is placed.
local function AuctionatorUpdateBidInScan(itemName, stackSize,
	oldNextBid, minIncrement)
	local scan = Atr_FindScan(itemName)
	if not scan then return end

	for _, row in ipairs(scan.sortedData) do
		if row.stackSize == stackSize and row.nextBid == oldNextBid then
			row.hasActiveBids  = true           -- теперь в группе есть ставки
			row.nextBid        = oldNextBid + (minIncrement or 0)
			row.nextBidPerItem = row.nextBid / stackSize
			break                               -- нашли ─ выходим из цикла
		end
	end
end

-- Counts matching auctions and optionally buys them.
function Atr_Buy_CountMatches(andBuy)

	local numMatches		= 0;
	local numBoughtThisPage	= 0;
	local i = 1;

	while (true) do

		local name, _, count, _, _, _, minBid, minIncrement, buyoutPrice, bidAmount = GetAuctionItemInfo("list", i)
		if name == nil then break end

		local nextBid = (bidAmount and bidAmount > 0)
		                and (bidAmount + minIncrement)
		                or  minBid

		local nameMatch  = zc.StringSame(name, gAtr_Buy_ItemName)
		local stackMatch = (count == gAtr_Buy_StackSize)

		local priceMatch
		if gAtr_Buy_IsBid then
			priceMatch = (nextBid ~= nil and nextBid == gAtr_Buy_BuyoutPrice)
		else
			priceMatch = (buyoutPrice ~= nil and buyoutPrice == gAtr_Buy_BuyoutPrice)
		end

		if nameMatch and stackMatch and priceMatch then
			numMatches = numMatches + 1
			if andBuy and gAtr_Buy_NumUserWants > gAtr_Buy_NumBought then
				
				PlaceAuctionBid("list", i, gAtr_Buy_BuyoutPrice)

				local pane = Atr_GetCurrentPane()               -- вместо прямого gCurrentPane
				if pane and pane.activeScan and pane.currIndex then
				  local scan = pane.activeScan
				  local sel  = scan.sortedData[pane.currIndex]   -- выбранный лот
				  local sSz  = sel.stackSize
				  local sPr  = sel.buyoutPrice
				
				  local function mark(list)
					if not list then return end
					for _, d in ipairs(list) do
					  if not d.yours
						 and d.stackSize  == sSz
						 and d.buyoutPrice == sPr then
						d.highBidder = 1          -- отмечаем нашу ставку
					  end
					end
				  end
				
				  mark(scan.sortedData)
				  mark(scan.scanData)
				  mark(scan.rawScan)				
				end

				pane.UINeedsUpdate = true       -- перерисовать таблицу

				numBoughtThisPage  = numBoughtThisPage + 1
				gAtr_Buy_NumBought = gAtr_Buy_NumBought + 1
				local pane = gCurrentPane
				if type(pane) == "table" then
					Atr_ShowCurrentAuctions()
					Atr_HighlightEntry(pane.currIndex)
				end				
			end			
		end

		i = i + 1
	end

	return numMatches, numBoughtThisPage
end

-----------------------------------------

-- Updates the confirmation dialog with current match counts and pricing.
function Atr_Buy_Confirm_Update()
    if not gAtr_Buy_BuyoutPrice then return end   -- ← добавьте проверку

    local num = Atr_Buy_Confirm_Numstacks:GetNumber()

    Atr_Buy_Confirm_Text2:SetText(num == 1 and ZT("stack for") or ZT("stacks for"))
    MoneyFrame_Update("Atr_Buy_Confirm_TotalPrice", gAtr_Buy_BuyoutPrice * num)
end


-----------------------------------------

-- Either queues the next page query or cancels depending on auction data.
function Atr_Buy_NextPage_Or_Cancel ( queueIf )

	if (Atr_Buy_IsComplete()) then
	
		Atr_Buy_Cancel();
		
	elseif (queueIf == nil or queueIf == true) then
	
		if (Atr_Buy_IsFirstPassComplete()) then
			gAtr_Buy_Pass = 2;
			Atr_Buy_QueueQuery(0);
		else
			Atr_Buy_QueueQuery(gAtr_Buy_CurPage + 1);
		end
	end
end

-----------------------------------------

-- Determines if the desired quantity has been purchased.
function Atr_Buy_IsComplete ()

	if (gAtr_Buy_NumUserWants ~= -1 and gAtr_Buy_NumUserWants <= gAtr_Buy_NumBought) then
		return true;
	end

	if (gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage) and gAtr_Buy_Pass == 2) then
		return true;
	end

	return false;

end

-----------------------------------------

-- Checks if the first scan through available pages is done.
function Atr_Buy_IsFirstPassComplete ()

	if (gAtr_Buy_Query:IsLastPage(gAtr_Buy_CurPage) and gAtr_Buy_Pass == 1) then
		return true;
	end

	return false;

end

-----------------------------------------

-- Executes the purchase when the user confirms the transaction.
function Atr_Buy_Confirm_OK ()

	if (gAtr_Buy_NumUserWants == -1) then
		local numToBuy = Atr_Buy_Confirm_Numstacks:GetNumber();

		if (numToBuy > gAtr_Buy_MaxCanBuy) then
			Atr_Error_Text:SetText (string.format (ZT("You can buy at most %d auctions"), gAtr_Buy_MaxCanBuy));
			Atr_Error_Frame:Show ();
			return;
		end
		
		gAtr_Buy_NumUserWants = numToBuy;
	end
	
	local _, numJustBought = Atr_Buy_BuyMatches ();

	if (numJustBought > 0) then

--zc.msg (numJustBought, " from page ", gAtr_Buy_CurPage);
	
		AuctionatorSubtractFromScan (gAtr_Buy_ItemName, gAtr_Buy_StackSize, gAtr_Buy_BuyoutPrice, gAtr_Buy_NumBought);
		gBuyState = ATR_BUY_JUST_BOUGHT;
		gAtr_Buy_Waiting_Start = time();
		Atr_Buy_Confirm_OKBut:Disable();
	else
		Atr_Buy_NextPage_Or_Cancel();
	end
	
end

-----------------------------------------

-- Waits for bought auctions to disappear from the listing before continuing.
function Atr_Buy_Wait_For_Bought_To_Clear ()

	zc.msg_dev ("Atr_Buy_Wait_For_Bought_To_Clear: ", time() - gAtr_Buy_Waiting_Start);
	
end

-----------------------------------------

-- Cancels the buying process and optionally displays an error message.
function Atr_Buy_Cancel (msg)
	
	gBuyState = ATR_BUY_NULL;

	Atr_Buy_Confirm_Frame:Hide();
	
	Atr_Error_Display(msg);
end


