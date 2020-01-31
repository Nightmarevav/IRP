Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	StandardProcessing = False;
	If Not Parameters.Filter.Property("Item") Then
		ChoiceData = New ValueList();
		Return;
	EndIf;
	
	ChoiceData = New ValueList();
	ChoiceData.LoadValues(GetRefsBySearchString(Parameters.Filter.Item, Parameters.SearchString));
EndProcedure

Function GetRefsBySearchString(Item, SearchString) Export
	Query = New Query();
	Query.Text =
		
		"SELECT
		|	Table.Attribute AS Property,
		|	Items.Ref AS Item
		|INTO tmp
		|FROM
		|	Catalog.ItemTypes.AvailableAttributes AS Table
		|		INNER JOIN Catalog.Items AS Items
		|		ON Items.ItemType = Table.Ref
		|		AND Items.Ref = &Item
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ItemKeys.Ref AS ItemKey,
		|	ItemKeys.Specification AS Specification
		|INTO tmp2
		|FROM
		|	Catalog.ItemKeys AS ItemKeys
		|WHERE
		|	ItemKeys.Specification <> VALUE(Catalog.Specifications.EmptyRef)
		|	AND ItemKeys.Item = &Item
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 50
		|	ItemKeys.ItemKey AS ItemKey
		|FROM
		|	tmp2 AS ItemKeys
		|		INNER JOIN Catalog.Specifications.DataSet AS DataSet
		|		ON ItemKeys.Specification = DataSet.Ref
		|		AND CASE
		|			WHEN VALUETYPE(DataSet.Value) = TYPE(Catalog.AddAttributeAndPropertyValues)
		|				THEN DataSet.Value.Description_en
		|			ELSE CAST(DataSet.Value AS STRING(200))
		|		END LIKE ""%"" + &SearchString + ""%""
		|
		|UNION
		|
		|SELECT
		|	Table.Ref
		|FROM
		|	Catalog.ItemKeys.AddAttributes AS Table
		|		INNER JOIN tmp AS tmp
		|		ON Table.Property = tmp.Property
		|		AND Table.Ref.Item = tmp.Item
		|		AND CASE
		|			WHEN VALUETYPE(Table.Value) = TYPE(Catalog.AddAttributeAndPropertyValues)
		|				THEN Table.Value.Description_en
		|			WHEN VALUETYPE(Table.Value) = TYPE(NUMBER)
		|				THEN Table.SearchLiteral
		|			ELSE CAST(Table.Value AS STRING(200))
		|		END LIKE ""%"" + &SearchString + ""%""
		|GROUP BY
		|	Table.Ref";
	
	Query.Text = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(Query.Text, "Table.Value");
	Query.Text = LocalizationEvents.ReplaceDescriptionLocalizationPrefix(Query.Text, "DataSet.Value");
	
	Query.SetParameter("Item", Item);
	Query.SetParameter("SearchString", SearchString);
	Return Query.Execute().Unload().UnloadColumn("ItemKey");
EndFunction

Function GetRefsByProperties(TableOfProperties, Item, AddInfo = Undefined) Export
	If Not TableOfProperties.Count() Then
		Query = New Query();
		Query.Text =
			"SELECT
			|	ItemKeys.Ref
			|FROM
			|	Catalog.ItemKeys AS ItemKeys
			|WHERE
			|	ItemKeys.Item = &Item";
		Query.SetParameter("Item", Item);
		Return Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	ArrayOfFoundedItemKeys = New Array();
	For Each PropertiesRow In TableOfProperties Do
		ArrayOfFoundedItemKeys = GetRefsByOneProperty(ArrayOfFoundedItemKeys
				, Item
				, PropertiesRow.Attribute
				, PropertiesRow.Value);
		If Not ArrayOfFoundedItemKeys.Count() Then
			Return ArrayOfFoundedItemKeys;
		EndIf;
	EndDo;
	Return ArrayOfFoundedItemKeys;
EndFunction

Function GetRefsByOneProperty(ArrayOfFoundedItemKeys, Item, Attribute, Value)
	Query = New Query();
	Query.Text =
		"SELECT
		|	ItemKeysAddAttributes.Ref
		|FROM
		|	Catalog.ItemKeys.AddAttributes AS ItemKeysAddAttributes
		|WHERE
		|	&Attribute = ItemKeysAddAttributes.Property
		|	AND &Value = ItemKeysAddAttributes.Value
		|	AND &Item = ItemKeysAddAttributes.Ref.Item
		|	AND CASE
		|		WHEN &FilterByResults
		|			THEN ItemKeysAddAttributes.Ref IN (&ArrayOfResults)
		|		ELSE TRUE
		|	END
		|GROUP BY
		|	ItemKeysAddAttributes.Ref";
	
	Query.SetParameter("Attribute", Attribute);
	Query.SetParameter("Value", Value);
	Query.SetParameter("Item", Item);
	Query.SetParameter("ArrayOfResults", ArrayOfFoundedItemKeys);
	Query.SetParameter("FilterByResults", ArrayOfFoundedItemKeys.Count() > 0);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
EndFunction

Function GetRefsByPropertiesWithSpecifications(TableOfProperties, Item, AddInfo = Undefined) Export
	If Not TableOfProperties.Count() Then
		Query = New Query();
		Query.Text =
			"SELECT
			|	ItemKeys.Ref
			|FROM
			|	Catalog.ItemKeys AS ItemKeys
			|WHERE
			|	ItemKeys.Item = &Item";
		Query.SetParameter("Item", Item);
		Return Query.Execute().Unload().UnloadColumn("Ref");
	EndIf;
	
	ArrayOfFoundedItemKeys = New Array();
	For Each PropertiesRow In TableOfProperties Do
		ArrayOfFoundedItemKeys = GetRefsByOnePropertyWithSpecifications(ArrayOfFoundedItemKeys
				, Item
				, PropertiesRow.Attribute
				, PropertiesRow.Value);
		If Not ArrayOfFoundedItemKeys.Count() Then
			Return ArrayOfFoundedItemKeys;
		EndIf;
	EndDo;
	Return ArrayOfFoundedItemKeys;
EndFunction

Function GetRefsByOnePropertyWithSpecifications(ArrayOfFoundedItemKeys, Item, Attribute, Value)
	Query = New Query(
			"SELECT
			|	Table.Ref,
			|	Table.Specification,
			|	CASE
			|		WHEN Table.Specification = VALUE(Catalog.Specifications.EmptyRef)
			|			THEN FALSE
			|		ELSE TRUE
			|	END AS IsSpecification
			|INTO tItemKeys
			|FROM
			|	Catalog.ItemKeys AS Table
			|WHERE
			|	&Item = Table.Item
			|	AND CASE
			|		WHEN &FilterByResults
			|			THEN Table.Ref IN (&ArrayOfResults)
			|		ELSE TRUE
			|	END
			|;
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	tItemKeys.Ref
			|FROM
			|	tItemKeys AS tItemKeys
			|		INNER JOIN Catalog.ItemKeys.AddAttributes AS ItemKeysAddAttributes
			|		ON tItemKeys.Ref = ItemKeysAddAttributes.Ref
			|			AND NOT tItemKeys.IsSpecification
			|			AND &Attribute = ItemKeysAddAttributes.Property
			|			AND &Value = ItemKeysAddAttributes.Value
			|
			|UNION
			|
			|SELECT
			|	tItemKeys.Ref
			|FROM
			|	tItemKeys AS tItemKeys
			|		INNER JOIN Catalog.Specifications.DataSet AS SpecificationsDataSet
			|		ON tItemKeys.Specification = SpecificationsDataSet.Ref
			|			AND tItemKeys.IsSpecification
			|			AND &Attribute = SpecificationsDataSet.Attribute
			|			AND &Value = SpecificationsDataSet.Value");
	
	Query.SetParameter("Attribute", Attribute);
	Query.SetParameter("Value", Value);
	Query.SetParameter("Item", Item);
	Query.SetParameter("ArrayOfResults", ArrayOfFoundedItemKeys);
	Query.SetParameter("FilterByResults", ArrayOfFoundedItemKeys.Count() > 0);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
EndFunction

Function GetUniqItemKeyByItem(Item) Export
	Query = New Query(
			"SELECT TOP 2
			|	Table.Ref
			|FROM
			|	Catalog.ItemKeys AS Table
			|WHERE
			|	&Item = Table.Item
			|	AND NOT Table.DeletionMark");
	Query.SetParameter("Item", Item);
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 1 Then
		Selection.Next();
		Return Selection.Ref;
	EndIf;
	Return Catalogs.ItemKeys.EmptyRef();
EndFunction

#Region Bundling

Function FindOrCreateRefByProperties(TableOfProperties, Item, AddInfo = Undefined) Export
	ArrayOfRefs = GetRefsByProperties(TableOfProperties, Item, AddInfo);
	If ArrayOfRefs.Count() Then
		Return ArrayOfRefs;
	Else
		ArrayOfResults = New Array();
		ArrayOfResults.Add(CreateRefByProperties(TableOfProperties, Item, AddInfo));
		Return ArrayOfResults;
	EndIf;
EndFunction

Function CreateRefByProperties(TableOfProperties, Item, AddInfo = Undefined) Export
	NewObject = Catalogs.ItemKeys.CreateItem();
	NewObject.Item = Item;
	For Each TableOfPropertiesRow In TableOfProperties Do
		NewRowAddAttributes = NewObject.AddAttributes.Add();
		NewRowAddAttributes.Property = TableOfPropertiesRow.Attribute;
		NewRowAddAttributes.Value = TableOfPropertiesRow.Value;
	EndDo;
	NewObject.Write();
	Return NewObject.Ref;
EndFunction

Function FindOrCreateRefBySpecification(Specification, Item, AddInfo = Undefined) Export
	ItemKeyRef = GetRefsBySpecification(Specification, Item, AddInfo);
	If Not ValueIsFilled(ItemKeyRef) Then
		Return CreateRefsBySpecification(Specification, Item, AddInfo);
	Else
		Return ItemKeyRef;
	EndIf;
EndFunction

Function CreateRefsBySpecification(Specification, Item, AddInfo = Undefined) Export
	NewObject = Catalogs.ItemKeys.CreateItem();
	NewObject.Item = Item;
	NewObject.Specification = Specification;
	NewObject.Write();
	Return NewObject.Ref;
EndFunction

Function GetRefsBySpecification(Specification, Item, AddInfo = Undefined) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	ItemKeys.Ref
		|FROM
		|	Catalog.ItemKeys AS ItemKeys
		|WHERE
		|	ItemKeys.Item = &Item
		|	AND ItemKeys.Specification = &Specification
		|GROUP BY
		|	ItemKeys.Ref";
	Query.SetParameter("Item", Item);
	Query.SetParameter("Specification", Specification);
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	If QuerySelection.Next() Then
		Return QuerySelection.Ref;
	Else
		Return Catalogs.ItemKeys.EmptyRef();
	EndIf;
EndFunction

Function GetWaysToFillItemListByBundle(ItemKeyBundle, AddInfo = Undefined) Export
	Result = New Structure("BySpecification, ByBundling", False, False);
	If Not ValueIsFilled(ItemKeyBundle) Then
		Return Result;
	EndIf;
	
	If ValueIsFilled(ItemKeyBundle.Specification) Then
		Result.BySpecification = True;
	EndIf;
	
	Query = New Query();
	Query.Text =
		"SELECT TOP 1
		|	BundleContentsSliceLast.ItemKeyBundle
		|FROM
		|	InformationRegister.BundleContents.SliceLast AS BundleContentsSliceLast
		|WHERE
		|	BundleContentsSliceLast.ItemKeyBundle = &ItemKeyBundle";
	Query.SetParameter("ItemKeyBundle", ItemKeyBundle);
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	If QuerySelection.Next() Then
		Result.ByBundling = True;
	EndIf;
	
	Return Result;
EndFunction

Function GetTableByBundleContent(ItemKeyBundle, AddInfo = Undefined) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	BundleContentsSliceLast.ItemKeyBundle,
		|	BundleContentsSliceLast.ItemKey,
		|	BundleContentsSliceLast.Quantity,
		|	CASE
		|		WHEN BundleContentsSliceLast.ItemKey.Unit <> VALUE(Catalog.Units.EmptyRef)
		|			THEN BundleContentsSliceLast.ItemKey.Unit
		|		ELSE BundleContentsSliceLast.ItemKey.Item.Unit
		|	END AS Unit
		|FROM
		|	InformationRegister.BundleContents.SliceLast(, ItemKeyBundle = &ItemKeyBundle) AS BundleContentsSliceLast";
	Query.SetParameter("ItemKeyBundle", ItemKeyBundle);
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	Return QueryTable;
EndFunction

Function GetTableBySpecification(ItemKeyBundle, AddInfo = Undefined) Export
	ResultTable = New ValueTable();
	ResultTable.Columns.Add("ItemKeyBundle", New TypeDescription("CatalogRef.ItemKeys"));
	ResultTable.Columns.Add("ItemKey", New TypeDescription("CatalogRef.ItemKeys"));
	ResultTable.Columns.Add("Quantity", New TypeDescription("Number"));
	ResultTable.Columns.Add("Unit", New TypeDescription("CatalogRef.Units"));
	
	Query = New Query();
	Query.Text =
		"SELECT
		|	CASE
		|		WHEN SpecificationsDataSet.Ref.Type = VALUE(Enum.SpecificationType.Bundle)
		|			THEN SpecificationsDataSet.Item
		|		ELSE &ItemKeyBundle_ItemKey
		|	END AS Item,
		|	SpecificationsDataSet.Attribute,
		|	SpecificationsDataSet.Value,
		|	SpecificationsDataQuantity.Quantity,
		|	SpecificationsDataSet.Key
		|FROM
		|	Catalog.Specifications.DataSet AS SpecificationsDataSet
		|		INNER JOIN Catalog.Specifications.DataQuantity AS SpecificationsDataQuantity
		|		ON SpecificationsDataQuantity.Ref = SpecificationsDataSet.Ref
		|		AND SpecificationsDataQuantity.Key = SpecificationsDataSet.Key
		|		AND SpecificationsDataQuantity.Ref = &ItemKeyBundle_Specification
		|		AND SpecificationsDataSet.Ref = &ItemKeyBundle_Specification";
	
	Query.SetParameter("ItemKeyBundle_Specification", ItemKeyBundle.Specification);
	Query.SetParameter("ItemKeyBundle_ItemKey", ItemKeyBundle.Item);
	
	QueryResult = Query.Execute();
	
	QueryTable = QueryResult.Unload();
	QueryTableCopy = QueryTable.Copy();
	QueryTableCopy.GroupBy("Key");
	
	For Each QueryTableCopyRow In QueryTableCopy Do
		Filter = New Structure("Key", QueryTableCopyRow.Key);
		TableOfProperties = QueryTable.Copy(Filter);
		Quantity = TableOfProperties[0].Quantity;
		Item = TableOfProperties[0].Item;
		TableOfProperties.GroupBy("Attribute, Value");
		
		ArrayOfItemKeys = FindOrCreateRefByProperties(TableOfProperties
				, Item
				, AddInfo);
		
		ItemKey = Undefined;
		If Not ArrayOfItemKeys.Count() Then
			Continue;
		EndIf;
		
		ItemKey = ArrayOfItemKeys[0];
		
		NewRowResultTable = ResultTable.Add();
		NewRowResultTable.ItemKeyBundle = ItemKeyBundle;
		NewRowResultTable.ItemKey = ItemKey;
		NewRowResultTable.Quantity = Quantity;
		NewRowResultTable.Unit = ?(ValueIsFilled(ItemKey.Unit), ItemKey.Unit, ItemKey.Item.Unit);
	EndDo;
	
	Return ResultTable;
EndFunction

#EndRegion

#Region Boxing

Function FindOrCreateRefByBoxing(BoxingRef, ItemBox, AddAttributesTable, AddInfo = Undefined) Export
	Result = Undefined;
	If Not TransactionActive() Then
		BeginTransaction(DataLockControlMode.Managed);
		Try
			Result = FindOrCreateRefByBoxingExecution(BoxingRef, ItemBox, AddAttributesTable, AddInfo);
			If TransactionActive() Then
				CommitTransaction();
			EndIf;
		Except
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
		EndTry;
	Else
		Result = FindOrCreateRefByBoxingExecution(BoxingRef, ItemBox, AddAttributesTable, AddInfo);
	EndIf;
	
	Return Result;	
EndFunction

Function FindOrCreateRefByBoxingExecution(BoxingRef, ItemBox, AddAttributesTable, AddInfo = Undefined)
	DataSource = New ValueTable();
	DataSource.Columns.Add("Boxing", New TypeDescription("DocumentRef.Boxing"));
	DataSource.Add().Boxing = BoxingRef;
	
	DataLock = New DataLock();
	ItemLock = DataLock.Add("InformationRegister.BoxingItemKeys");
	ItemLock.Mode = DataLockMode.Exclusive;
	ItemLock.DataSource = DataSource;
	ItemLock.UseFromDataSource("Boxing", "Boxing");
	DataLock.Lock();
	
	ItemKeyBox = GetRefByBoxing(BoxingRef, ItemBox, AddInfo);
	If ValueIsFilled(ItemKeyBox) Then
		ItemKeyBox = UpdateRefByBoxing(ItemKeyBox, BoxingRef, ItemBox, AddAttributesTable, AddInfo);
	Else
		ItemKeyBox = CreateRefByBoxing(BoxingRef, ItemBox, AddAttributesTable, AddInfo);
	EndIf;
	
	Return ItemKeyBox;
EndFunction
	

Function GetRefByBoxing(BoxingRef, ItemBox, AddInfo = Undefined) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	BoxingItemKeys.ItemKey
		|FROM
		|	InformationRegister.BoxingItemKeys AS BoxingItemKeys
		|WHERE 
		|	BoxingItemKeys.Boxing = &Boxing
		|	AND BoxingItemKeys.Box = &ItemBox";
	Query.SetParameter("Boxing", BoxingRef);
	Query.SetParameter("ItemBox", ItemBox);
	QueryResult = Query.Execute();
	QuerySelection = QueryResult.Select();
	If QuerySelection.Next() Then
		Return QuerySelection.ItemKey;
	Else
		Return Catalogs.ItemKeys.EmptyRef();
	EndIf;
EndFunction

Function UpdateRefByBoxing(ItemKeyBox, BoxingRef, ItemBox, AddAttributesTable, AddInfo = Undefined)
	If AddAttributesTable.Count() Then
		ItemKeyObject = ItemKeyBox.GetObject();
		ItemKeyObject.AddAttributes.Clear();
		ItemKeyObject.AddAttributes.Load(AddAttributesTable);
		ItemKeyObject.Write();
	EndIf;
	
	Return ItemKeyBox;
EndFunction

Function CreateRefByBoxing(BoxingRef, ItemBox, AddAttributesTable, AddInfo = Undefined)
	ItemKeyObject = Catalogs.ItemKeys.CreateItem();
	ItemKeyObject.Item = ItemBox;
	If AddAttributesTable.Count() Then
		ItemKeyObject.AddAttributes.Clear();
		ItemKeyObject.AddAttributes.Load(AddAttributesTable);
	EndIf;
	ItemKeyObject.Write();
	ItemKeyRef = ItemKeyObject.Ref;
	
	RecordSet = InformationRegisters.BoxingItemKeys.CreateRecordSet();
	RecordSet.Filter.Boxing.Set(BoxingRef);
	RecordSet.Filter.Box.Set(ItemBox);
	
	NewRecord = RecordSet.Add();
	NewRecord.Boxing = BoxingRef;
	NewRecord.Box = ItemBox;
	NewRecord.ItemKey = ItemKeyRef;
	
	RecordSet.Write();
	
	Return ItemKeyRef;
EndFunction

Function GetTableByBoxContent(ItemKeyBox, AddInfo = Undefined) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	BoxContentsSliceLast.ItemKeyBox,
		|	BoxContentsSliceLast.ItemKey,
		|	BoxContentsSliceLast.Quantity,
		|	CASE
		|		WHEN BoxContentsSliceLast.ItemKey.Unit <> VALUE(Catalog.Units.EmptyRef)
		|			THEN BoxContentsSliceLast.ItemKey.Unit
		|		ELSE BoxContentsSliceLast.ItemKey.Item.Unit
		|	END AS Unit
		|FROM
		|	InformationRegister.BoxContents.SliceLast(, ItemKeyBox = &ItemKeyBox) AS BoxContentsSliceLast";
	Query.SetParameter("ItemKeyBox", ItemKeyBox);
	QueryResult = Query.Execute();
	QueryTable = QueryResult.Unload();
	Return QueryTable;
EndFunction

#EndRegion

#Region AffectPricingMD5

Procedure SynhronizeAffectPricingMD5ByItemType(ItemType) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	ItemKeys.Ref AS ItemKey,
		|	ItemKeys.Item AS Item,
		|	ItemKeys.Item.ItemType AS ItemType,
		|	ItemKeys.AffectPricingMD5,
		|	ItemKeys.Specification AS Specification,
		|	ItemKeys.Specification.Type AS SpecificationType
		|FROM
		|	Catalog.ItemKeys AS ItemKeys
		|WHERE
		|	ItemKeys.Item.ItemType = &ItemType";
	Query.SetParameter("ItemType", ItemType);
	QueryResult = Query.Execute();
	SynhronizeAffectPricingMD5(QueryResult.Select());
EndProcedure

Procedure SynhronizeAffectPricingMD5BySpecification(Specification) Export
	Query = New Query();
	Query.Text =
		"SELECT
		|	ItemKeys.Ref AS ItemKey,
		|	ItemKeys.Item AS Item,
		|	ItemKeys.Item.ItemType AS ItemType,
		|	ItemKeys.AffectPricingMD5,
		|	ItemKeys.Specification AS Specification,
		|	ItemKeys.Specification.Type AS SpecificationType
		|FROM
		|	Catalog.ItemKeys AS ItemKeys
		|WHERE
		|	ItemKeys.Specification = &Specification";
	Query.SetParameter("Specification", Specification);
	QueryResult = Query.Execute();
	SynhronizeAffectPricingMD5(QueryResult.Select());
EndProcedure

Procedure SynhronizeAffectPricingMD5(QuerySelection)
	
	While QuerySelection.Next() Do
		NeedWrite = False;
		AffectPricingMD5 = Undefined;
		TableOfAffectPricingMD5 = Undefined;
		
		If ValueIsFilled(QuerySelection.Specification) Then
			If QuerySelection.SpecificationType = Enums.SpecificationType.Set Then
				TableOfAffectPricingMD5 = CalculateMD5ForSet(QuerySelection.Specification.DataQuantity.Unload()
						, QuerySelection.Specification.DataSet.Unload()
						, QuerySelection.Item
						, QuerySelection.ItemType);
			EndIf;
			If QuerySelection.SpecificationType = Enums.SpecificationType.Bundle Then
				TableOfAffectPricingMD5 = CalculateMD5ForBundle(QuerySelection.Specification.DataQuantity.Unload()
						, QuerySelection.Specification.DataSet.Unload()
						, QuerySelection.Item
						, QuerySelection.ItemType);
			EndIf;
			
			ExistTableOfAffectPricingMD5 = GetResultTableMD5ForSpecification();
			For Each Row In QuerySelection.ItemKey.SpecificationAffectPricingMD5 Do
				FillPropertyValues(ExistTableOfAffectPricingMD5.Add(), Row);
			EndDo;
			
			If TableOfAffectPricingMD5 <> Undefined
				And AddAttributesAndPropertiesServer.GetMD5ForValueTable(TableOfAffectPricingMD5)
				<> AddAttributesAndPropertiesServer.GetMD5ForValueTable(ExistTableOfAffectPricingMD5) Then
				NeedWrite = True;
			EndIf;
			
		Else
			AffectPricingMD5
			= AddAttributesAndPropertiesServer.GetAffectPricingMD5(QuerySelection.Item
					, QuerySelection.ItemType
					, QuerySelection.ItemKey.AddAttributes.Unload());
			If AffectPricingMD5 <> QuerySelection.AffectPricingMD5 Then
				NeedWrite = True;
			EndIf;
		EndIf;
		
		If NeedWrite Then
			ItemKeyObject = QuerySelection.ItemKey.GetObject();
			ItemKeyObject.AdditionalProperties.Insert("SynhronizeAffectPricingMD5", True);
			If AffectPricingMD5 <> Undefined Then
				ItemKeyObject.AdditionalProperties.Insert("AffectPricingMD5", AffectPricingMD5);
			EndIf;
			If TableOfAffectPricingMD5 <> Undefined Then
				ItemKeyObject.AdditionalProperties.Insert("TableOfAffectPricingMD5", TableOfAffectPricingMD5);
			EndIf;
			ItemKeyObject.Write();
		EndIf;
	EndDo;
EndProcedure

Function CalculateMD5ForSet(TableOfDataQuantity, TableOfDataSet, Item, ItemType) Export
	Return CalculateMD5ForSpecification(TableOfDataQuantity
		, TableOfDataSet
		, Item
		, ItemType);
EndFunction

Function CalculateMD5ForBundle(TableOfDataQuantity, TableOfDataSet, Item, ItemType) Export
	Return CalculateMD5ForSpecification(TableOfDataQuantity
		, TableOfDataSet
		, Undefined
		, Undefined);
EndFunction

Function CalculateMD5ForSpecification(TableOfDataQuantity, TableOfDataSet, Item = Undefined, ItemType = Undefined)
	TableOfResult = GetResultTableMD5ForSpecification();
	For Each Row In TableOfDataQuantity Do
		TableOfAddAttributes = TableOfDataSet.Copy(New Structure("Key", Row.Key));
		If TableOfAddAttributes.Count() Then
			NewRow = TableOfResult.Add();
			NewRow.Key = Row.Key;
			TableOfAddAttributes.Columns.Attribute.Name = "Property";
			If Item <> Undefined And ItemType <> Undefined Then
				NewRow.AffectPricingMD5 =
					AddAttributesAndPropertiesServer.GetAffectPricingMD5(Item
						, ItemType
						, TableOfAddAttributes);
			Else
				NewRow.AffectPricingMD5 =
					AddAttributesAndPropertiesServer.GetAffectPricingMD5(TableOfAddAttributes[0].Item
						, TableOfAddAttributes[0].Item.ItemType
						, TableOfAddAttributes);
			EndIf;
		EndIf;
	EndDo;
	Return TableOfResult;
EndFunction

Function GetResultTableMD5ForSpecification()
	TableOfResult = New ValueTable();
	TableOfResult.Columns.Add("Key");
	TableOfResult.Columns.Add("AffectPricingMD5");
	Return TableOfResult;
EndFunction

#EndRegion
