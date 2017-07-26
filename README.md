# Pricing Analytics

# Summary

This solution on Pricing Analytics uses your sales history transactional data to show you how the demand 
for your products responds to the prices you offer. This way you can recommend pricing changes, and  
 simulate how changes in price would affect your demand, at the level of individual products.

The core of the solution is the ability to
 estimate price elasticities for every product, site, channel and customer segment
in your business. These elasticity models avoid most common confounding effects by using an advanced modeling 
approach combining the strengths of machine learning and econometrics.

The solution has visualization components both in Power BI and for interactive simulation, in Excel.

# Description

#### Estimated Provisioning time: 20 minutes

This solution brings price elasticity modeling and pricing recommendations to any business with an Azure subscription. 
It alleviates confounding by the "Double-ML" approach, which subtracts out the predictable components
of price and demand variation before estimating the elasticity. This immunizes the estimates from most forms of seasonal confounding.
Additionally, the solution can be customized by an implementation partner to use data reflecting other 
potential external demand drivers.

Additionally, estimating demand for item, sites, and channels with sparse demand is a challenge
and pricing solutions often only give estimates at product category level. Our pricing solution
uses "hierarchical regularization" to produce consistent estimates down to the product level in such data-poor situations. 
Simply put, in absence of strong evidence, the model borrows information from other items in the same category, 
same items in other sites, and so on. As data for an item increases, its elasticity estimate will be
fine-tuned more specifically.

This solution analyzes your prices and 

* shows you in one glance how elastic your product demand is,
* provides pricing recommendations for every product in your item catalog,
* discovers related products (substitutes and complements),
* lets you simulate promotional scenarios.

All information is provided at the level at which you need for detailed control of your price and inventory.

Additional detail on the data science of prices are in our 
[blog post](https://blogs.msdn.microsoft.com/intel/archives/1015).

# Solution Architecture

Azure Solutions are composed of cloud-based analytics tools for data ingestion, data storage, scheduling and advanced analytics components in a way that can be integrated with your current production systems. This Solution combines these Azure services:

* A SQL server to store your transactional data and the generated model predictions.
* Azure Data Factory, which schedules weekly model refreshes. 
* There are more than 10 elasticity modeling core services, which are exposed by AzureML.
* The provided Excel spreadsheets run the predictive Web Services.
* The results display in a PowerBI dashboard.

![Solution Architecture](images/pcsArchitectureDiagram.png)

Please read the [Technical Deployment Guide](Technical%20Deployment%20Guide/TechnicalDeploymentGuide.md) 
for a more detailed discussion.

# Getting Started

[Deploy the solution from the Cortana Intelligence Quick Start Page](https://aka.ms/pricingciqs).
Instructions at the end of the deployment will guide you further.

The solution deploys with an example data set of orange juice prices.

While the solution is deploying, get a head start and 
* peruse the [User Guide](User%20Guide/UserGuide.md) for a full set of usage instruction
* download the [interactive Excel Worksheet](https://aka.ms/pricingxls)

For technical problems or questions about deploying this solution, 
please post in the issues tab of the repository.

# Solution Dashboard 

The solution dashboard's most actionable tab is the Pricing Suggestion tab. It tells you which of your 
items are underpriced, overpriced, and suggests an optimal price for each item, as well as the predicted
impact of adopting the suggestion. The suggestions are prioritized by the largest opportunity to earn
incremental gross margin.

![Suggestion Tab of Dashboard](images/dashboard_pricing_suggestions.png)

Other tabs provide supplemental information illuminating how the system arrived at the suggestions
and are discussed in more detail in the [User Guide](User%20Guide/UserGuide.md).
