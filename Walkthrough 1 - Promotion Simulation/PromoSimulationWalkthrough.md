# Price Analytics - Promotion Simulation Scenario

## Pre-requisites

* A deployed Interactive Price Analytics solution
* Excel of a recent vintage

## Introduction

In this walk-through, you will simulate the effect of a promotion.
A "promotion" means simply changing the price of an item for a specified amount of time.

## Setup

If you haven't downloaded the [interactive Excel Worksheet](https://aka.ms/pricingxls) yet,
please download it now. It contains an Instructions tab that will help you with most
common setup issues.

Open the AzureML plugin pane on the right and delete the example web services (Titanic Survival
and Text Sentiment Analysis). 

Click Add and paste the URL and API key of the PromotionSimulation
web service from the Instructions page at the end of the deployment. 
If you closed that page, you can come back to it from the 
[Deployments section of Cortana Intelligence Quick Starts](https://start.cortanaintelligence.com/Deployments).

## Promotion Simulation

In the spreadsheet, find the Simulate Promotion tab. It has a yellow box with instructions.
You have already completed the first step of those instructions (set up web service).

Follow the instructions in the spreadsheet, but choose A18 as the destination (output) cell. 
As <tt>datasetName</tt> parameter of the service, you can use 'latestDemoBuild'
if the solution has run for a while and a model has been generated.
For forecastPeriod, choose 3. 

If the table at A18 fills out successfully, then your model has already been built by Azure Data Factory. 
If you get an error, please build a model according to the instructions in the next section.

Experiment with the price of Minute Maid on week 2. Note that both the sales
of tropicana and dominicks are affected the same week (cannibalization)
and sales of the same product are affected in the next week (pull-forward).

## Building a model interactively

If your solution is newly deployed, the modeling pipeline may not have run
and the model names 'latestDemoBuild' does not exist.

In this case, build a model from your data ad-hoc.

To build a model, open the Excel template and navigate to the Data and Model tab.
Follow the instructions on the spreadsheet, choosing some name other than
'latestDemoBuild' for the datasetName.

Creating the model will take about 3 minutes for the OJ dataset and produces
as output the lists of valid values for Products, Locations, etc. that the model
recognizes. 

Now repeat the instructions in the Promotion Simulation exercise with the 
datasetName being your chosen one.

## Building a model from your own data

If you have other pricing data you would like to try your model on,
please format it to the same schema as the Orange Juice data and
repeat the Build Model step. 

The dashboards will not update (they are pointed to the 'latestDemoBuild' 
model and run weekly), but you can explore the elasticities, product relations 
and forecasts from Excel. We will introduce dashboarding of results from 
bring-your-own data in a future release.


