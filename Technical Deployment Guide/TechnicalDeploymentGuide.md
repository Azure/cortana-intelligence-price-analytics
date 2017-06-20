# Pricing Analytics Solution: Technical Deployment Guide

This document explains how to deploy the default configuration of the Pricing Analytics Solution.
It is intended for technical personnel who deploy the solution and connect it to the business data
warehouse.

## Outline

  1. [Introduction](#introduction)
  2. [Architecture](#architecture)
  3. [Automated Deployment Workflow](#automated-deployment-workflow)
  4. [Connecting Your Data](#connecting-your-data)  
  6. [Customization](#customization)
  6. [Building Applications](#building-applications)
  7. [Troubleshooting](#troublehooting)
  8. [Support and Feedback](#support-and-feedback)

## Introduction

Please understand how the solution is intended to be used in the [User Guide](UserGuide.md).

**In what context is the offered pricing solution is suitable?**
We recommend this solution for retail-like contexts where each customer segment 
faces the same price. It is not appropriate when prices are often negotiated 
individually. 

## Architecture

The architecture can be summarized in the following diagram:

![architecture diagram](../images/pcsArchitectureDiagram.png)

The solution architecture consists of the following Azure components:

* An Azure SQL DB, used to store several different types of data, pre-process the transactional data for modeling,
  and generate pricing suggestions. A premium edition (P1) is recommended as the larger tables take advantage of clustered columnstore indices.
* An Azure Storage account, used to save the model and intermediate data in Blobs and Tables.
* A model build web service 
* A collection of several interactive services for querying the model
* A PowerBI workspace collection
* Azure Data factory for scheduling regular execution

Because every business system is different, the pre-configured solution does not include data 
flows from your business system to the SQL database, or the flow of decisions pricing from 
the analyst to the business systems (e.g. ERP).

An [integration partner](https://https://appsource.microsoft.com/en-us/product/cortana-intelligence/microsoft-cortana-intelligence.demand-forecasting-for-retail) 
can connect these data paths for you.

### Known limitations

The pre-configured solution necessarily makes some simplifying assumptions.
We will describe how to modify the solution below.

The known limitations are:

* We compute short-term elasticities only. In the short term, demand is less price-elastic than in the long term.
  For example, if a grocery store raises prices mildly, customers will pay the higher price, rather than driving to another store. Demand is relatively inelastic.
  In the long run, customers may choose not to come to the more expensive store in the first place and demand will fall more.
* While the model internally works with arbitrary periods, the solution has a weekly periodicity baked into 
  how the data is aggregated in pre-processing the ADF pipeline
* We don't check any business rules, such as "the pick-up channel must be prices the same or lower as the delivery channel"
* Segmentation must be provided externally - we don't generate customer segments automatically

## Automated Deployment Workflow

To start, you will need an Azure subscription.

Go to the [CIQS solution webpage](https://aka.ms/pricingciqs) and deploy the solution.
* The name you give your solution becomes a name for the resource group for tracking your
resources and spending. 
* Choose a location that is geographically to your business users.
* Click Create

The deployment goes through several provisioning and setup steps, using a combination
 of Azure Resource Manager (ARM) templates and Azure Functions. 
 ARM templates are JSON files that define the resources you need to deploy for your solution. 
 Azure Functions is a serverless compute service that enables you to run code on-demand without 
 having to explicitly provision or manage infrastructure. We will describe ARM templates and Azure 
 Functions used in this solution in later sections.

You will need to interact with the installer once, to create a user name and pasword
for the database administrator account. Remember this password well if you want to
customize the solution. If you reset it in the [Azure portal](https://portal.azure.com),
Azure Data Factory may have trouble talking to the SQL server.

### Provisioned Resources
Once the solution is deployed to the subscription, 
you can see the services deployed by clicking the resource 
group name on the final deployment screen in the CIS.

### One-time workbook setup

<div class="todo" style="color:red; font-weight: bold;">
TODO: rewrite this to reflect the possible configuration of SQL connection
</div>

We provide an Excel template for interacting with the solution. 
It has multiple tabs for the different steps in pricing analysis.
Before the sheet can be used, it must be set up by connecting 
the appropriate web services to the workbook.
Please connect these services by pasting their request-response URL and into the AzureML plugin.
The URLs and keys are displayed at the final CIQS page, which you can access
from the [Deployments section of CIQS](https://start.cortanaintelligence.com/Deployments).
You can also see all of your services [here](https://services.azureml.net).


Detailed connection instructions are found in the worksheet, on the "Instructions" tab.
After adding the services, save the Excel spreadsheet under an appropriate name; 
we use <tt>AnalysisTemplate.xsls</tt>.
This configured workbook template will be used to load data output from the analytical pipeline.

### Step-By-Step Visual Studio Deployment

It is possible to deploy the elements of the solution with a few clicks 
from their Visual Studio solution files, using Cloud Explorer.

These instructions are currently not available because we are not ready to expose 
the AzureML services source code externally for IP reasons. 
Therefore the json for AzureML services is missing.
This is not fully secure protection and needs to be resolved before going open source.

## Connecting Your Data

This section describes the inputs and output datasets of the solution.

###	Input dataset

The main prerequisite is the sales history. 
The solution expects sales history data in the table <tt>dbo.pricingdata</tt>, 
with the folllowing schema:

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

The solution defines the data as an external ADF dataset, which means the data should "just appear" in this table. 
It is your responsibility to ensure that it does. We recommend that you use Azure Data Factory or SSIS to push 
sales data incrementally from the business data warehouse to this table. While transforming data, please consider
the following points.

* Data can be aggregated weekly or left in the original one-row-per-transaction state, in which case the system will be aggregate it to weekly quantities.
* If you aggregate the transactions, we recommend against defining the price as a weekly average of prices.
  Instead, we recommend you group by distinct discrete prices if possible.
* ItemHierarchy must be provided as a comma-separated list of categories, highest level first, for example "Cosmetics, Soap, Coconut Soap".
   If your items are not organized in a product hierarchy, use a single string like "Products".
* SiteName, ChannelName, CustomerSegment also must be provided, if your data does not break down along these
  dimensions, use "All" or a similar constant as well.

###	Outputs

These four SQL tables are the output tables of the solution. 
You can expect them to be populated weekly.
They underlie the Solution dashboard and can be used to create other visuals as well.

* Elasticities
* Cross-elasticities
* Forecasts
* SuggestionRuns

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

<div class="todo" style="color:red; font-weight: bold;">
TODO: describe the SuggestionRuns table
</div>

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

<div class="todo" style="color:red; font-weight: bold;">
TODO: describe the parameters table and check parameter names
</div>


## Building Applications

While many users find the Excel environment natural, many will also require features
that are not directly supported by our core models and pipelines.

Whether you are building a customer-specific user interface in Excel or another application,
you will want to call the web services. 

We first give an detailing example of calling the Elasticity web service from Excel
and describe its inputs and outputs. The other services operate analogously.


### Elasticity service from Excel
You can inspect the elasticities of every product by navigating to the "Elasticities" tab of the
Promotion Suggestion report and opening the "Elasticity" service pane of the AzureML plugin.

![AzureML plugin pane for Elasticity Service](../images/ElasticityAzureMLplugin.png) {style = "width: 300px"}

Because elasticities can change in time, a query date is required in cell A6 of the spreadsheet.
We recommend using the date of the most recent model. The A5:A6 range of cells is the input.

![Elasticity Input parameter](../images/ElasticityInputParameter.png)

The output location should be set to a convenient location in the spreadsheet, normally Elasticities$A20.
The "datasetName" parameter is of the form "M<date>", where data refers to the day on which the model
was created, using data available up to that day. You can explore previous models as well
[Future pointer: we should offer the "list models" feature and if model isn't listed, use latest]

The output consists of a dataframe containing the estimated elasticity of every Item at every
Site, as well as the 90% confidence interval for the estimate. The range of elasticities can
be seen in one glance by clicking on the generated external figure link containing the elasticity histogram.

![Elasticity histogram](../images/elasticityHistogram.png)

To get the service to behave as if it was a first-order Excel function and update
values in its output cells every time the input changes, check the Auto-predict box.

### Calling REST APIs from anywhere

The services are simply AzureML RESTful APIs. You can go to (https://services.azureml.net)
to grab sample code to consume them from R, Python, or C#. 

See the swagger documentation to the services to understand their input and output requirements.
The same information is reflected in the VIEW SCHEMA pane of the AzureML plugin.

### Individual Services Descriptions

There are three types of ML service in this solution, batch model build, interactive retrieval 
and bulk retrieval services. 

The batch model build service is BuildModel and is responsible for all estimation tasks.
Depending on data size, it can run minutes to hours.

The interactive services are:
* Elasticities
* CrossElasticities
* Forecasts
* PromoSimulation
* Outliers
* RetrospectiveAnalysis

These services are expected to return within a few seconds (the first query after a while may be slow
as the containers "warm up").

The bulk services are used to export the data from the model to the database.
* BulkElasticities
* BulkCrossElasticities
* BulkForecasts


## Troubleshooting

* If you are experiencing timeouts on the BuildModel service, try increasing the
  timeout period in the <tt>retrain_AzureML_Model</tt> ADF activity.
* If you get "blob does not exist" errors, open the storage account and make sure
  a model with the given datasetName exists. The name is case-sensitive.


## Support and feedback

Please contact Tomas.Singliar@microsoft.com with questions, requests or concerns about the solution.
