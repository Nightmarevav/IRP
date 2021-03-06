
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	If DataExchange.Load Then
		Return;
	EndIf;	

	ThisObject.DocumentAmount = ThisObject.ItemList.Total("TotalAmount");
EndProcedure

Procedure OnWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;	
EndProcedure

Procedure BeforeDelete(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
EndProcedure

Procedure Posting(Cancel, PostingMode)
	PostingServer.Post(ThisObject, Cancel, PostingMode, ThisObject.AdditionalProperties);
EndProcedure

Procedure UndoPosting(Cancel)
	UndopostingServer.Undopost(ThisObject, Cancel, ThisObject.AdditionalProperties);
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	If TypeOf(FillingData) = Type("Structure") Then
		If FillingData.Property("BasedOn") And FillingData.BasedOn = "PurchaseOrder" Then
			Filling_BasedOnPurchaseOrder(FillingData);
		EndIf;
		If FillingData.Property("BasedOn") And FillingData.BasedOn = "SalesOrder" Then
			Filling_BasedOnPurchaseOrder(FillingData);
		EndIf;
	EndIf;
EndProcedure

Procedure Filling_BasedOnPurchaseOrder(FillingData)
	FillPropertyValues(ThisObject, FillingData,
		"Company,Partner,LegalName,Agreement,Currency,PriceIncludeTax");
	
	For Each Row In FillingData.ItemList Do
		NewRow = ThisObject.ItemList.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	For Each Row In FillingData.TaxList Do
		NewRow = ThisObject.TaxList.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	For Each Row In FillingData.SpecialOffers Do
		NewRow = ThisObject.SpecialOffers.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	For Each Row In FillingData.GoodsReceipts Do
		NewRow = ThisObject.GoodsReceipts.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;	
EndProcedure

Procedure OnCopy(CopiedObject)
	LinkedTables = New Array();
	LinkedTables.Add(SpecialOffers);
	LinkedTables.Add(TaxList);
	LinkedTables.Add(Currencies);
	DocumentsServer.SetNewTableUUID(ItemList, LinkedTables);
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If DocumentsServer.CheckItemListStores(ThisObject) Then
		Cancel = True;	
	EndIf;
	
	For Each Row In ThisObject.ItemList Do
		ItemKeyRow = New Structure();
		ItemKeyRow.Insert("LineNumber"  , Row.LineNumber);
		ItemKeyRow.Insert("Key"         , Row.Key);
		ItemKeyRow.Insert("Item"        , Row.ItemKey.Item);
		ItemKeyRow.Insert("ItemKey"     , Row.ItemKey);
		ItemKeyRow.Insert("QuantityUnit", Row.Unit);
		ItemKeyRow.Insert("Unit"        , ?(ValueIsFilled(Row.ItemKey.Unit), Row.ItemKey.Unit, Row.ItemKey.Item.Unit));
		ItemKeyRow.Insert("Quantity"    , Row.Quantity);
		
		DocumentsServer.RecalculateQuantityInRow(ItemKeyRow);
		
		ArrayOfRows = ThisObject.GoodsReceipts.FindRows(New Structure("Key", ItemKeyRow.Key));
		If Not ArrayOfRows.Count() Then
			Continue;
		EndIf;
		TotalQuantity_GoodsReceipt = 0;
		For Each ItemOfArray In ArrayOfRows Do
			If ItemOfArray.Quantity > ItemOfArray.QuantityInGoodsReceipt Then
				Cancel = True;
				CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_080, ItemKeyRow.LineNumber,
					ItemOfArray.GoodsReceipt, ItemOfArray.Quantity, ItemOfArray.QuantityInGoodsReceipt), "ItemList["
					+ Format((ItemKeyRow.LineNumber - 1), "NZ=0; NG=0;") + "].Quantity", ThisObject);
			EndIf;
			TotalQuantity_GoodsReceipt = TotalQuantity_GoodsReceipt + ItemOfArray.Quantity;
		EndDo;

		If TotalQuantity_GoodsReceipt < ItemKeyRow.Quantity Then
			Cancel = True;
			CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_081, ItemKeyRow.LineNumber, ItemKeyRow.Item,
				ItemKeyRow.ItemKey, ItemKeyRow.Quantity, TotalQuantity_GoodsReceipt), "ItemList[" + Format((ItemKeyRow.LineNumber - 1),
				"NZ=0; NG=0;") + "].Quantity", ThisObject);
		EndIf;

		If TotalQuantity_GoodsReceipt > ItemKeyRow.Quantity Then
			Cancel = True;
			CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_082, ItemKeyRow.LineNumber, ItemKeyRow.Item,
				ItemKeyRow.ItemKey, ItemKeyRow.Quantity, TotalQuantity_GoodsReceipt), "ItemList[" + Format((ItemKeyRow.LineNumber - 1),
				"NZ=0; NG=0;") + "].Quantity", ThisObject);

		EndIf;
	EndDo;
EndProcedure
