-- ###############################################################
-- Script to ingest the cross-elasticities produced back into a database
--
-- The idea is to load into a temp table, and then do an INSERT ... SELECT transform in-database

-- the source format is described in cross_els_AzureBlobDataset.json
/*
 "structure": [
            {
                "name": "Location",
                "type": "String"
            },
            {
                "name": "Current Date",
                "type": "Datetime"
            },
            {
                "name": "Segment",
                "type": "String"
            },
            {
                "name": "Impacting Product",
                "type": "String"
            },
            {
                "name": "Impacting Channel",
                "type": "String"
            },
            {
                "name": "Impacted Product",
                "type": "String"
            },
            {
                "name": "Impacted Channel",
                "type": "String"
            },
            {
                "name": "Cross-Price Elasticity",
                "type": "Double"
            },
            {
                "name": "External Figure Links",
                "type": "String"
            },
            {
                "name": "ADF Unescaped Comma Junk",
                "type": "String"
            }
  ]
*/

		-- the target format is defined in CrossElasticities.sql
/*
CREATE TABLE dbo.CrossElasticities (	
  RunDate               date not null,
  RelationValidDate     date null,
  CustomerSegment       varchar(100) not null,	
  DrivingItemKey        varchar(100) not null,
  DrivingSiteName       varchar(100) not null,
  DrivingChannelName    varchar(100) not null,	
  ImpactedItemKey       varchar(100) not null,
  ImpactedSiteName      varchar(100) not null,
  ImpactedChannelName   varchar(100) not null,	   
  CrossElasticity       float not null
)
*/

-- temporary table to ingest the data, matching the input structure

DROP TABLE IF EXISTS etl.tempCrossElasticities;
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

-- #####################################################
-- Now make it a stored proc to run the ingest at once

DROP PROCEDURE spIngestBulkCrossPrice;
go

CREATE PROCEDURE spIngestBulkCrossPrice (
		@SliceEnd varchar(100)
	)
AS
BEGIN

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

END

go 
