-- ###############################################################
-- Script to ingest the bul forecasts produced back into a database
--
-- The idea is to load into a temp table, 
-- and then do an INSERT ... SELECT transform in-database

-- the source format is described in elasticities_AzureBlobDataset.json
/*
 "structure": [
   {
                "name": "Periods Ahead",
                "type": "Int32"
            },
            {
                "name": "Forecast From Date",
                "type": "Datetime"
            },
            {
                "name": "Sale Date",
                "type": "Datetime"
            },
            {
                "name": "Location",
                "type": "String"
            },
            {
                "name": "Product",
                "type": "String"
            },
            {
                "name": "Channel",
                "type": "String"
            },
            {
                "name": "Segment",
                "type": "String"
            },
            {
                "name": "Forecast",
                "type": "Double"
            },
            {
                "name": "CI LB",
                "type": "Double"
            },
            {
                "name": "CI UB",
                "type": "Double"
            },
            {
                "name": "Actual Sales",
                "type": "Double"
            },
            {
                "name": "sAPE",
                "type": "Double"
            },
            {
                "name": "qBar",
                "type": "Double"
            }     
*/

-- the target format is defined in Forecasts.sql
/*
DROP TABLE dbo.Forecasts;
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
  ForecastPeriodEnd		date not null,  -- end of the period whose demand is forecasted
  UnitPrice             float, -- forecast is conditional on this price. Should be decimal (6,2), but that's pulling the ADF tiger's tail.
  Demand                float not null,
  Demand90LB            float not null,
  Demand90UB            float not null,
  ActualSales			float null,
  sAPE					float null,
  qBar					float null
  primary key (RunDate, Item, SiteName, ChannelName, CustomerSegment,
				LastDayOfData, ForecastPeriodStart, ForecastPeriodEnd)
)

*/

-- temporary table to ingest the data, matching the input structure

DROP TABLE IF EXISTS etl.tempForecasts;
go

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

-- #####################################################
-- Now make it a stored proc to run the ingest at once

DROP PROCEDURE spIngestBulkForecasts;
go

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

/*

select *
from dbo.Forecasts;

select count(1)
from etl.tempForecasts;

select *
from etl.tempForecasts
where Product='dominicks'
  and SaleDate = '2016-01-07'
  and Location = 100;
  
  */
