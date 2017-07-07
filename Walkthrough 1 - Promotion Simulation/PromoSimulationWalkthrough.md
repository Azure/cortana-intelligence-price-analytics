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
web service from the Instructions at the end of the deployment. If you closed that page, you
can come back to it from the 
[Deployments section of Cortana Intelligence Quick Starts](https://start.cortanaintelligence.com/Deployments).


## Promotion Simulation

In the spreadsheet, find the Simulate Promotion tab. It has a yellow box with instructions.
You have already completed the first step.

Follow the instructions, but choose A18 as the destination cell. 
As <tt>datasetName</tt> parameter of the service, you can use 'latestDemoBuild'
if the solution has run for a while and a model has been generated.

Experiment with the price of Minute Maid on week 2. Note that both the sales
of tropicana and dominicks are affected the same week (cannibalization)
and sales of the same product are affected in the next week (pull-forward)
