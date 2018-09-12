This solution brings price elasticity modeling and pricing recommendations to any business with an Azure subscription. 
It alleviates confounding by the "Double-ML" approach, which subtracts out the predictable components such as 
seasonal confounding 
of price and demand variation before estimating the elasticity due to exogenous price changes.
Additionally, the solution can be customized to use data reflecting other 
potential external demand drivers.

Additionally, estimating demand for item, sites, and channels with sparse demand is a challenge,
and existing pricing solutions often only give estimates at product category level. Our pricing solution
uses "hierarchical regularization" to produce consistent estimates 
down to the individual product level in such data-poor situations. 
Simply put, in absence of strong evidence, the model borrows information from other items in the same category, 
same items in other sites, and so on. As data for an item increases, its elasticity estimate will be
fine-tuned more specifically.

The services this solution consists of include

* showing you in one glance how elastic your product demand is,
* providing pricing recommendations for every product in your item catalog,
* discovering which products are related as substitutes and complements,
* simulating promotional pricing scenarios.

All information is provided at the level at which you need for detailed control of your price and inventory.

Additional detail on the data science of prices are in our 
[blog post](https://blogs.msdn.microsoft.com/intel/archives/1015).

# Estimated cost
The estimated cost for the solution is approximately $10/day ($300/month)

* $100 for S1 standard ML service plan
* $75 for an S2 SQL database
* $75 for app hosting plan  
* $50 in miscellaneous ADF data activities and storage costs

If you are just exploring the solution, you can delete it in a few days or hours.
The costs are pro-rated and will cease to be charged when you delete the Azure components.

# Getting Started

You can install a running copy of this solution in your existing Azure subscription.
Deploy the solution with the button on the right. 
Instructions at the end of the deployment will have important configuration information.
Please leave them open.

The solution deploys with the same example data set of orange juice prices
that you find behind the Try-It-Now button on the right.

While the solution is deploying, you can get a head start and                           

* see what is available in the Try-It-Now dashboard
* peruse the [User Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/User%20Guide/UserGuide.md) for usage instructions from the perspective of a pricing analyst (MSFT login required)
* review the [Technical Deployment Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/Technical%20Deployment%20Guide/TechnicalDeploymentGuide.md) for a technical implementation view (MSFT login required)
* download the [interactive Excel Worksheet](https://aka.ms/pricingxls)

After the solution deploys, complete the [first walkthrough](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/Walkthrough%201%20-%20Promotion%20Simulation/PromoSimulationWalkthrough.md)
(MSFT login required).

# Solution Dashboard 

The solution dashboard's most actionable part is the Pricing Suggestion tab. It tells you which of your 
items are underpriced, overpriced, and suggests an optimal price for each item, as well as the predicted
impact of adopting the suggestion. The suggestions are prioritized by the largest opportunity to earn
incremental gross margin.

![Suggestion Tab of Dashboard]({PatternAssetBaseUrl}/images/dashboard_pricing_suggestions.png)

Other tabs provide supplemental information illuminating how the system arrived at the suggestions
and are discussed in more detail in the [User Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/User%20Guide/UserGuide.md).
(You must be logged into Github with a MSFT Azure account while solution is in private preview.)

# Solution Architecture

Azure Solutions are composed of cloud-based analytics services for data ingestion, data storage, scheduling and advanced analytics components. These services can be integrated with your current production systems. This Solution combines these Azure services:

* A SQL server to store your transactional data and the generated model predictions.
* Azure Data Factory, which schedules weekly model refreshes. 
* There are more than 10 elasticity modeling core services, which are exposed by AzureML.
* The provided Excel spreadsheets run the predictive Web Services.
* The results display in a PowerBI dashboard.

![Solution Architecture]({PatternAssetBaseUrl}/images/pcsArchitectureStandard.jpeg)

Please read the 
[Technical Deployment Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/Technical%20Deployment%20Guide/TechnicalDeploymentGuide.md) 
for a more detailed discussion of the architecture, connecting your own data and customization (Github login required).

# Additional use terms
Reverse engineering of solution components provided in bytecode (.pyc) is prohibited.