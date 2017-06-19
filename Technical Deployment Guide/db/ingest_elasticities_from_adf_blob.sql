-- ###############################################################
-- Script to ingest the elasticities produced back into a database
--
-- The idea is to load into a temp table, and then do an INSERT ... SELECT transform in-database

-- the source format is described in elasticities_AzureBlobDataset.json
/*
 "structure": [
      {
        "name": "Elasticity on Date",
        "type": "String"
      },
      {
        "name": "Product",
        "type": "String"
      },
      {
        "name": "Location",
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
        "name": "Elasticity",
        "type": "Double"
      },
      {
        "name": "90% CI LB Elasticity",
        "type": "Double"
      },
      {
        "name": "90% CI UB Elasticity",
        "type": "Double"
      },
	  {
        "name": "External Figure Links",
        "type": "String"
      },
*/

-- the target format is defined in Elasticities.sql
/*
CREATE TABLE dbo.Elasticities (	
  RunDate               date not null,
  RelationValidDate     date null,
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,	
  CustomerSegment       varchar(100) not null,	
  Elasticity            float not null,
  Elasticity90LB        float not null,
  Elasticity90UB        float not null,
)
*/

-- temporary table to ingest the data, matching the input structure

DROP TABLE IF EXISTS etl.tempElasticities;
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

-- #####################################################
-- Now make it a stored proc to run the ingest at once

DROP PROCEDURE spIngestBulkElasticities;
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
