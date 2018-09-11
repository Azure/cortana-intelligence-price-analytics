-- ###########################################################
-- Schemas


CREATE SCHEMA [etl];
go

-- ###########################################################
-- Create tables

----------------------------------------------------
-- Create permanent tables

CREATE TABLE dbo.pricingdata (	
	SalesDate		date not null,
	Item 			varchar(100) not null,
	SiteName		varchar(100) not null,
	ChannelName		varchar(100) not null,
	CustomerSegment	varchar(100) not null,	
	ItemHierarchy	varchar(500) not null,
	UnitPrice		float not null,
	UnitCost		float null,
	Quantity		float not null,
	primary key (SalesDate, Item, SiteName, ChannelName, CustomerSegment)
);
go


CREATE TABLE [dbo].[Parameters]
(
    [paramName] VARCHAR(50) NOT NULL, 
    [paramValue] VARCHAR(MAX) NULL, 
    PRIMARY KEY ([paramName])
);
go

CREATE TABLE dbo.Elasticities (	
  RunDate               date not null,
  RelationValidDate     date not null,
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,	
  CustomerSegment       varchar(100) not null,	
  Elasticity            float not null,
  Elasticity90LB        float not null,
  Elasticity90UB        float not null,
  primary key (RunDate, RelationValidDate, Item, SiteName, ChannelName, CustomerSegment)
);
go


CREATE TABLE dbo.Forecasts (	
  RunDate               date not null,
  Source				varchar(100) not null,	-- where did the forecast come from?
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,
  CustomerSegment       varchar(100) not null,
  LastDayOfData         date not null,  -- forecast made using data up and including this  
  PeriodInDays			int not null,
  PeriodsAhead			int not null,
  ForecastPeriodStart	date not null,
  ForecastPeriodEnd		date not null,  -- end of the period in which demand is forecasted
  UnitPrice             float null, 
  Demand                float not null,
  Demand90LB            float not null,
  Demand90UB            float not null,
  ActualSales			float null,
  sAPE					float null,
  qBar					float null,
  primary key (RunDate, Item, SiteName, ChannelName, 
				LastDayOfData, ForecastPeriodStart, ForecastPeriodEnd)
);
go

CREATE TABLE dbo.CrossElasticities (	
  RunDate               date not null,
  RelationValidDate     date not null,
  CustomerSegment       varchar(100) not null,	
  DrivingItemKey        varchar(100) not null,
  DrivingSiteName       varchar(100) not null,
  DrivingChannelName    varchar(100) not null,	
  ImpactedItemKey       varchar(100) not null,
  ImpactedSiteName      varchar(100) not null,
  ImpactedChannelName   varchar(100) not null,	   
  CrossElasticity       float not null,
  primary key (RunDate, RelationValidDate, CustomerSegment, DrivingItemKey, DrivingSiteName, DrivingChannelName, ImpactedItemKey, ImpactedSiteName, ImpactedChannelName)
);
GO

create table dbo.UnderOver
(
       Item                       varchar(100) not null,
       SiteName                   varchar(100) not null,
       ChannelName                varchar(100) not null,
       CustomerSegment            varchar(100) not null,
       RunDate                           date not null,
       ValidDate                  date not null,
       LastPrice                  float not null,
       LastCost                   float null,
       Elasticity                 float not null,
       MarginOptimalPrice         float null,
       Deviation                  float null
       primary key (Item, SiteName, ChannelName, CustomerSegment, RunDate, ValidDate)
);
go

CREATE TABLE [dbo].[SuggestionRuns] (
    [suggestionRunID]            VARCHAR (200) NOT NULL,
    [pastPeriodStart]            DATE          NOT NULL,
    [pastPeriodEnd]              DATE          NOT NULL,
    [suggestionPeriodStart]      DATE          NOT NULL,
    [suggestionPeriodEnd]        DATE          NOT NULL,
    [minOrders]                  FLOAT (53)    NOT NULL,
    [Item]                       VARCHAR (100) NOT NULL,
    [SiteName]                   VARCHAR (100) NOT NULL,
    [ChannelName]                VARCHAR (100) NOT NULL,
    [CustomerSegment]            VARCHAR (100) NOT NULL,
    [UnitsLastPeriod]            FLOAT (53)    NULL,
    [avgSaleUnitPrice]           FLOAT (53)    NULL,
    [avgCostUnitPrice]           FLOAT (53)    NULL,
    [Orders]                     INT           NULL,
    [RevenueLastPeriod]          FLOAT (53)    NULL,
    [MarginLastPeriod]           FLOAT (53)    NULL,
    [Elasticity]                 FLOAT (53)    NOT NULL,
    [marginOptimalPrice]         FLOAT (53)    NULL,
    [marginOptimalPriceRounded]  FLOAT (53)    NULL,
    [percentChange]              FLOAT (53)    NULL,
    [forecastedDemandAtOptimum]  FLOAT (53)    NULL,
    [forecastedDemandAtRounded]  FLOAT (53)    NULL,
    [forecastedRevenueAtRounded] FLOAT (53)    NULL,
    [forecastedMarginAtRounded]  FLOAT (53)    NULL,
    [incrementalMargin]          FLOAT (53)    NULL
);
go

-----------------------------------------------------
-- Temp tables for ETL

CREATE TABLE etl.tempForecasts (
 PeriodsAhead		int not null,
 ForecastFromDate	date not null,
 SaleDate			date not null,
 Location			varchar(200) not null,
 Product			varchar(200) not null,
 Channel			varchar(200) not null,
 Segment			varchar(200) not null,
 Forecast			float not null,
 CILB				float not null,
 CIUB				float not null,
 ActualSales		float null,
 sAPE				float null,
 qBar				float null
);

go

CREATE TABLE etl.tempElasticities (	
  ElasticityOnDate		date null,
  Product               varchar(100) not null,
  Location              varchar(100) not null,
  Channel				varchar(100) not null,	
  Segment				varchar(100) not null,	
  Elasticity            float not null,
  Elasticity90LB        float not null,
  Elasticity90UB        float not null,
  ExternalFigureLinks	varchar(1000) null,
  UnescapedCommaJunk	varchar(1000) null
);
go

CREATE TABLE etl.tempCrossElasticities (	
  Location              varchar(100) not null,
  CurrentDate			date not null,
  Segment				varchar(100) not null,
  ImpactingProduct      varchar(100) not null,
  ImpactingChannel		varchar(100) not null,
  ImpactedProduct      varchar(100) not null,
  ImpactedChannel		varchar(100) not null,
  CrossElasticity       float not null,
  ExternalFigureLinks	varchar(1000) null,
  UnescapedCommaJunk	varchar(1000) null
);
go

-- ###########################################################
-- Stored procs acting as ADF steps

CREATE PROCEDURE spIngestBulkForecasts (
		@SliceEnd	varchar(100),
		@Source		varchar(100)
	)
AS
BEGIN

	DELETE f
	FROM dbo.Forecasts f
	INNER JOIN etl.tempForecasts t
		on	f.RunDate = convert(date, @SliceEnd)
		and f.Source = @Source
		and f.Item = t.Product
		and f.SiteName = t.Location
		and f.ChannelName = t.Channel
		and f.CustomerSegment = t.Segment;

	INSERT INTO dbo.Forecasts
	SELECT 
		convert(date, @SliceEnd) as RunDate,
		@Source as Source,		
		Product as Item,
		Location as SiteName,
		Channel as ChannelName,
		Segment as CustomerSegment,
		ForecastFromDate as LastDayOfData,
		datediff(day, ForecastFromDate, SaleDate)/PeriodsAhead as PeriodInDays,
		PeriodsAhead,
		dateadd(day, - datediff(day, ForecastFromDate, SaleDate)/PeriodsAhead, SaleDate) as ForecastPeriodStart,		
		SaleDate as ForecastPeriodEnd,
		null as UnitPrice,
		Forecast, CILB, CIUB,		-- forecasts
		ActualSales, sAPE, qBar		-- accuracy metrics on forecasts
	FROM etl.tempForecasts;
	
	-- when done uploading, truncate the temporary table
	truncate table etl.tempForecasts;

	update statistics dbo.Forecasts;

END
go 

CREATE PROCEDURE spIngestBulkElasticities (
		@SliceEnd varchar(100)
	)
AS
BEGIN

	DELETE e
	FROM dbo.Elasticities e
	INNER JOIN etl.tempElasticities t
		on	e.RunDate = convert(date, @SliceEnd)
		and e.Item = t.Product
		and e.SiteName = t.Location
		and e.ChannelName = t.Channel
		and e.CustomerSegment = t.Segment;

	INSERT INTO dbo.Elasticities
	SELECT convert(date, @SliceEnd) as RunDate,
		ElasticityOnDate as RelationValidDate,
		Product as item,
		Location as SiteName,
		Channel as ChannelName,
		Segment as CustomerSegment,
		Elasticity, Elasticity90LB, Elasticity90UB
	FROM etl.tempElasticities;

	-- when done uploading, truncate the temporary table
	truncate table etl.tempElasticities;

	update statistics dbo.Elasticities;

END
go 

CREATE PROCEDURE spIngestBulkCrossPrice (
		@SliceEnd varchar(100)
	)
AS
BEGIN
	BEGIN TRANSACTION
	DELETE c
	FROM dbo.CrossElasticities c
	INNER JOIN etl.tempCrossElasticities t
		on	c.RunDate = convert(date, @SliceEnd)
		and c.DrivingItemKey = t.ImpactingProduct
		and c.DrivingSiteName = t.Location		
		and c.ImpactedItemKey = t.ImpactedProduct
		and c.ImpactedSiteName = t.Location
		and c.ImpactedChannelName = t.ImpactedChannel
		and c.CustomerSegment = t.Segment;

	INSERT INTO dbo.CrossElasticities
	SELECT convert(date, @SliceEnd) as RunDate,
		CurrentDate as RelationValidDate,
		Segment as CustomerSegment,
		ImpactingProduct as DrivingItemKey,
		Location as DrivingSiteName,
		ImpactingChannel as DrivingChannelName,
		ImpactedProduct as ImpactedItemKey,
		Location as ImpactedSiteName,
		ImpactedChannel as ImpactedChannelName,		
		CrossElasticity
	FROM etl.tempCrossElasticities;

	-- when done uploading, truncate the temporary table
	truncate table etl.tempCrossElasticities;

	update statistics dbo.CrossElasticities;
	
	COMMIT TRANSACTION

END
go 

-- ###########################################################################
-- generate pricing suggestions

create schema sug;
go

-- ################################################################################
-- recommend new product prices

CREATE PROCEDURE [dbo].[spRecommendProducts] (
	@SliceEnd				date,
	@lastDayOfData			date,
	@suggestionPeriodStart	date,
	@suggestionPeriodEnd	date,
	@minOrders				int
	)
AS
BEGIN
	
	DECLARE @runID				varchar(100);
	DECLARE @pastPeriodEnd		date;
	DECLARE @pastPeriodStart	date;

	SET @runID = concat('S', @SliceEnd);
	SET @pastPeriodEnd = @lastDayOfData;
	SET @pastPeriodStart = DATEADD(day, - DATEDIFF(day,@suggestionPeriodStart, @suggestionPeriodEnd), @lastDayOfData);

	-- ##########################################################################
	-- populate parameters

	-- ##########################################################################
	-- Selection of individual candidate pool for suggestion
	drop table if exists sug.individual_selection;
	select	@runID as suggestionRunID, 
			@pastPeriodStart as pastPeriodStart, 
			@pastPeriodEnd as pastPeriodEnd, 
			@suggestionPeriodStart as suggestionPeriodStart, 
			@suggestionPeriodEnd as suggestionPeriodEnd, 
			@minOrders as minOrders,
			lastPeriod.Item, lastPeriod.SiteName, lastPeriod.ChannelName, lastPeriod.CustomerSegment,  
			Orders as OrdersLastPeriod, UnitsLastPeriod, 
			UnitsLastPeriod as BaselineForecast,
			avgSaleUnitPrice, avgCostUnitPrice, RevenueLastPeriod, MarginLastPeriod,			
			Elasticity,
			round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2) as marginOptimalPrice,
			round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01 as marginOptimalPriceRounded,
			exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2)) - log(avgSaleUnitPrice)) * elasticity) as multToOptimal,
			exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01) - log(avgSaleUnitPrice)) * elasticity) as multToRounded
			-- TODO: the rounding should be towards higher margin, not arbitrary arithmetic rounding
	into sug.individual_selection
	from (
		select Item, SiteName, ChannelName, CustomerSegment
			, count(1) as Orders
			, round(sum(Quantity),0) as UnitsLastPeriod
			, sum(Quantity * UnitPrice) as RevenueLastPeriod
			, sum(Quantity * (UnitPrice - coalesce(UnitCost,0))) as MarginLastPeriod
			, sum(Quantity * UnitPrice) / sum(Quantity) as avgSaleUnitPrice
			, sum(Quantity * coalesce(UnitCost,0)) / sum(Quantity) as avgCostUnitPrice
		from pricingdata p	 			 
		where SalesDate between @pastPeriodStart and @pastPeriodEnd
		group by Item, SiteName, ChannelName, CustomerSegment
		having count(1) >= @minOrders
		) lastPeriod
		join Elasticities e on (lastPeriod.Item=e.Item
							and lastPeriod.SiteName = e.SiteName 
							and lastPeriod.ChannelName = e.ChannelName 
							and lastPeriod.CustomerSegment = e.CustomerSegment
							and e.RelationValidDate = (select max(RelationValidDate)				-- use elasticity run closest to the time
													   from Elasticities
														where RelationValidDate <= @pastPeriodEnd)
							and e.RunDate = (select max(RunDate) from Elasticities)					-- use latest elasticity run available 
							)		-- end join condition
	;

	-- ########################################################################
	-- Adding predicted outcomes to the data 

	drop table if exists sug.selection_with_outcomes;

	select	suggestionRunID, pastPeriodStart, pastPeriodEnd, suggestionPeriodStart, suggestionPeriodEnd, minOrders,
			Item, SiteName, ChannelName, CustomerSegment,
			UnitsLastPeriod, 
			round(avgSaleUnitPrice, 2) as avgSaleUnitPrice,
			round(avgCostUnitPrice, 2) as avgCostUnitPrice,
			OrdersLastPeriod,
			round(RevenueLastPeriod,2) as RevenueLastPeriod, 
			round(MarginLastPeriod,2) as MarginLastPeriod,
			Elasticity,
			marginOptimalPrice,
			marginOptimalPriceRounded,
			round(100.0 * (marginOptimalPriceRounded - avgSaleUnitPrice) / avgSaleUnitPrice,0) as percentDeviation,
			round(multToOptimal * BaselineForecast,0) as forecastedDemandAtOptimum,
			round(multToRounded * BaselineForecast,0) as forecastedDemandAtRounded,
			round(multToRounded * BaselineForecast * marginOptimalPriceRounded, 0) as forecastedRevenueAtRounded,
			round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice), 2) as forecastedMarginAtRounded,
			round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice)	-- predicted margin
				 - BaselineForecast * (avgSaleUnitPrice - avgCostUnitPrice)							-- counterfactual margin		
				  , 2) as incrementalMargin
	into sug.selection_with_outcomes
	from sug.individual_selection;

	-- ########################################################################
	-- Creating/ recordig in  the Suggestion Table 

	DELETE FROM SuggestionRuns
	WHERE SuggestionRunID = @runID;
	
	insert into dbo.SuggestionRuns
	select * 
	from sug.selection_with_outcomes;

	update statistics SuggestionRuns;

	-- ########################################################################
	-- All done

	RETURN 0
END
GO

-- #######################################################
-- Loading the initial data

CREATE TABLE [etl].[oj_data_raw]
(
	store		int not null,
	brand		varchar(100) not null,
	week		int not null,
	logmove		float not null,
	feat		smallint NOT NULL,
	price		float NOT NULL,
	AGE60		float NULL,
	EDUC		float,
	ETHNIC		float,
	INCOME		float,
	HHLARGE		float,
	WORKWOM		float,
	HVAL150		float,
	SSTRDIST	float,
	SSTRVOL		float,
	CPDIST5		float,
	CPWVOL5		float,
	primary key (store, brand, week)
);

/*

cd BizOpsEcon-PricingPCS\data\

bcp pricingdemo.etl.oj_data_raw in 'oj_raw.csv' -S tosingli-sql.database.windows.net -U tosingli@tosingli-sql -c -F 2 -t `, -P ***

*/


