
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
		If FillingData.Property("BasedOn") And FillingData.BasedOn = "SalesOrder" Then
			Filling_BasedOnSalesOrder(FillingData);
		ElsIf FillingData.Property("BasedOn") And FillingData.BasedOn = "ShipmentConfirmation" Then
			Filling_BasedOnShipmentConfirmation(FillingData);
		EndIf;
	EndIf;
EndProcedure

Procedure Filling_BasedOnSalesOrder(FillingData)
	FillPropertyValues(ThisObject, FillingData,
		"Partner, Company, Currency, Agreement, PriceIncludeTax, ManagerSegment, LegalName");
	
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
	For Each Row In FillingData.ShipmentConfirmations Do
		NewRow = ThisObject.ShipmentConfirmations.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
EndProcedure

Procedure Filling_BasedOnShipmentConfirmation(FillingData)
	FillPropertyValues(ThisObject, FillingData, 
		"Partner, Company, Currency, Agreement, PriceIncludeTax, ManagerSegment, LegalName");
	
	For Each Row In FillingData.ItemList Do
		NewRow = ThisObject.ItemList.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	For Each Row In FillingData.ShipmentConfirmations Do
		NewRow = ThisObject.ShipmentConfirmations.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
EndProcedure

Procedure OnCopy(CopiedObject)
	LinkedTables = New Array();
	LinkedTables.Add(SpecialOffers);
	LinkedTables.Add(TaxList);
	LinkedTables.Add(Currencies);
	LinkedTables.Add(SerialLotNumbers);
	DocumentsServer.SetNewTableUUID(ItemList, LinkedTables);
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If DocumentsServer.CheckItemListStores(ThisObject) Then
		Cancel = True;	
	EndIf;
	
	If Not SerialLotNumbersServer.CheckFilling(ThisObject) Then
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
		
		ArrayOfRows = ThisObject.ShipmentConfirmations.FindRows(New Structure("Key", ItemKeyRow.Key));
		If Not ArrayOfRows.Count() Then
			Continue;
		EndIf;
		TotalQuantity_ShipmentConfirmations = 0;
		For Each ItemOfArray In ArrayOfRows Do
			If ItemOfArray.Quantity > ItemOfArray.QuantityInShipmentConfirmation Then
				Cancel = True;
				CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_080, ItemKeyRow.LineNumber,
					ItemOfArray.ShipmentConfirmation, ItemOfArray.Quantity, ItemOfArray.QuantityInShipmentConfirmation), "ItemList["
					+ Format((ItemKeyRow.LineNumber - 1), "NZ=0; NG=0;") + "].Quantity", ThisObject);
			EndIf;
			TotalQuantity_ShipmentConfirmations = TotalQuantity_ShipmentConfirmations + ItemOfArray.Quantity;
		EndDo;

		If TotalQuantity_ShipmentConfirmations < ItemKeyRow.Quantity Then
			Cancel = True;
			CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_081, ItemKeyRow.LineNumber, ItemKeyRow.Item,
				ItemKeyRow.ItemKey, ItemKeyRow.Quantity, TotalQuantity_ShipmentConfirmations), "ItemList[" + Format((ItemKeyRow.LineNumber - 1),
				"NZ=0; NG=0;") + "].Quantity", ThisObject);
		EndIf;

		If TotalQuantity_ShipmentConfirmations > ItemKeyRow.Quantity Then
			Cancel = True;
			CommonFunctionsClientServer.ShowUsersMessage(StrTemplate(R().Error_082, ItemKeyRow.LineNumber, ItemKeyRow.Item,
				ItemKeyRow.ItemKey, ItemKeyRow.Quantity, TotalQuantity_ShipmentConfirmations), "ItemList[" + Format((ItemKeyRow.LineNumber - 1),
				"NZ=0; NG=0;") + "].Quantity", ThisObject);

		EndIf;
	EndDo;
EndProcedure
