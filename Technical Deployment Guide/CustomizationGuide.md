# Pricing Analytics Solution: Implementor's  Guide
This document is aimed at the technical specialist that is implementing and 
customizing the pre-configured solution for specific customer's need.

## Introduction

Please first deploy the default solution from the Cortana Intelligence Gallery.

## Configuration

To set the parameters, update the table <tt>dbo.Parameters</tt> in the Solution's 
SQL database. These parameters are configurable:

* Lead-time (days before start of pricing period) for producing the pricing suggestions. 
  Insert the key-value pair ('sugLeadTime', '[n]') into the table, replacing [n] 
  by the number of days in advance. The default value is '1'. 
* Maximum allowed deviation of suggested price from current price (percentage).
  Please insert the key-value pair ('maxPriceDeviation', '[x.x]') into the table, 
  replacing [x.x] by the desired fraction. The default value is '0.2', representing
  a maximum deviation of 20 percent.

###	Prerequisities and inputs

The main prerequisite is the sales history.

The solution expects sales history data in the table <tt>dbo.pricingdata</tt>, with the folllowing schema:

```sql
CREATE TABLE dbo.pricingdata (	
	SalesDate		date not null,
	Item 			varchar(100) not null,
	SiteName		varchar(100) not null,
	ChannelName		varchar(100) not null,	
	ItemHierarchy		varchar(500) not null,
	UnitPrice		float not null,
	UnitCost		float null,
	Quantity		float not null,
	CustomerSegment		varchar(100) not null
)
```

* Data can be aggregated weekly or left in the original one-row-per-transaction state, in which case the system will be aggregate it to weekly quantities.
* If you aggregate the transactions, we recommend against defining the price as a weekly average of prices.
  Instead, we recommend you group by distinct discrete prices if possible.
* ItemHierarchy must be provided as a comma-separated list of categories, highest level first, for example "Cosmetics, Soap, Coconut Soap".
   If your items are not organized in a product hierarchy, use a single string like "Products".
* SiteName, ChannelName, CustomerSegment also must be provided, if your data does not break down along these
  dimensions, use "All" or a similar constant as well.

###	Outputs

These four SQL tables are the output tables of the solution. you can expect them to be populated weekly.
They underlie the Solution dashboard and can be used to create other visuals as well.

* Elasticities
* Cross-elasticities
* Forecasts
* PromotionImpact

Current run outputs are appended to these tables: Each has a RunDate column, corresponding to the date on which
the data was inserted. The schemas are as follows:

```sql
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
```

The Cross-Elasticities table stores all the cross-elasticities that were estimated.
RunDate doubles as an identifier of the model run.


```sql
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
  CrossElasticity       float not null,
  CrossElasticity90LB   float not null,
  CrossElasticity90UB   float not null,
)
```

The Forecasts table stores all the forecasts the model has made.
RunDate doubles as an identifier of the forecast run.

```sql
CREATE TABLE dbo.Forecasts (	
  RunDate               date not null,
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,	
  LastDayOfData         date not null,  -- forecast made using data up and including this
  ForecastPeriodStart   date not null,  -- start of the period whose demand is forecasted
  UnitPrice             float not null, -- forecast is conditional on this price  
  Demand                float not null
  Demand90LB            float not null
  Demand90UB            float not null
)
```

PromotionImpact tracks the impact of promotions the user confirmed.
We report actual demand for the periods before, during, and after the promotion period.
We report forecasted (counterfactual) demand for the periods during, and after promotion period.
The impact is the difference between actual and forecasted demand.
We include counterfactual demand for the post-promotion period because 
"pull-forward" may occur as demands shifts in time, which may offset
the desired demand effect 


```sql
CREATE TABLE dbo.PromotionImpact (	
  PromotionID           date not null,
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,	
  PromotionPeriodStart  date not null,       -- start of the promotion week
  PromotionPeriodEnd    date not null,         
  -- previous period of same length in days as promotion period
  PreviousUnitPrice     float not null,      
  ActualPreviousDemand  float not null,     -- actual demand seen at pre-promotion price  
  -- promotion period
  PromotionUnitPrice    float not null,         
  ForecastedPromoDemand float not null,      -- demand forecasted if previous price held
  ActualPromotionDemand float not null,      -- actual demand seen at promotion price
  -- post-promotion period of same length in days as promotion period
  FollowingUnitPrice    float null,          -- may be null if post-promo period did not end yet
  ForecastedFollowingDemand float not null,
  ActualFollowingDemand float null,          -- actual demand seen at post-promotion price
)
```

For filtering purposes, 
Auxiliary tables are provided to enable filtering
- categories - maps items to category hierarchy [Huh? TODO]

## Calling the services programmatically

If you are building a customer-specific user interface or another application,
you might want to call the web services. We first give an example of calling the 
Elasticity web service from Excel. 

### Elasticity service from Excel
You can inspect the elasticities of every product by navigating to the "Elasticities" tab of the
Promotion Suggestion report and opening the "Elasticity" service pane of the AzureML plugin.

![AzureML plugin pane for Elasticity Service](./SHTG/ElasticityAzureMLplugin.png) {style = "width: 300px"}

Because elasticities can change in time, a query date is required in cell A6 of the spreadsheet.
We recommend using the date of the most recent model. The A5:A6 range of cells is the input.

![Elasticity Input parameter](./SHTG/ElasticityInputParameter.png)

The output location should be set to a convenient location in the spreadsheet, normally Elasticities$A20.
The "datasetName" parameter is of the form "M<date>", where data refers to the day on which the model
was created, using data available up to that day. You can explore previous models as well
[Future pointer: we should offer the "list models" feature and if model isn't listed, use latest]

The output consists of a dataframe containing the estimated elasticity of every Item at every
Site, as well as the 90% confidence interval for the estimate. The range of elasticities can
be seen in one glance by clicking on the generated external figure link containing the elasticity histogram.

![Elasticity histogram](./SHTG/elasticityHistogram.png)

To get the service to behave as if it was a first-order Excel function and update
values in its output cells every time the input changes, check the Auto-predict box.

### Calling REST APIs from anywhere

The services are simply AzureML RESTful APIs. You can go to (https://services.azureml.net)
to grab sample code to consume them from R, Python, or C#. 


## Modifying the solyution
In addition, reports are generated regularly, and saved in the <tt>reports</tt> directory of the solution 
storage account, in csv format. The solution storage account is listed in the final CIQS.

#### Database

There is a database project in the PricingPCS solution file that lets you deploy the database.
Otherwise you can execute all the sql code in the that project.

#### Azure Data Factory

There is an ADf project in the sln, or manually paste ADF json into (https://portal.azure.com)

#### Web services

- BuildModel service
- Elasticities service
- CrossElasticities
- Forecast Service
- PromotionSimulation
- Upload

#### Dashboards

[TODO dashboard setup]
