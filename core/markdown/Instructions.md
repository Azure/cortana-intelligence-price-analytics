## Your solution has been successfully deployed!

Your Interactive Price Analytics solution is now ready to use.

Azure resources:
* Azure Machine Learning Webservices (listed below)	
* A [SQL Server]({Outputs.sqlServerUrl}) for persistent storage of historic data, forecasts, and recommendations
* A [Data Factory]({Outputs.dataFactoryUrl}) for orchestrating data movement and transformation activities

You can view all the provisioned resources in your [Azure portal]({Outputs.resourceGroupUrl}). 

## Next steps
* Download a sample Power BI desktop **.pbix** file [**here**]({PatternAssetBaseUrl}/pricingDashboard.pbix). (*Edge might change the extension to .zip*)
* Instructions on how to connect to data source in Power BI desktop is available [**here**](https://github.com/Azure/Azure-CloudIntelligence-SolutionAuthoringWorkspace/blob/master/docs/powerbi-configurations.md).
* Download the [Excel spreadsheet](https://aka.ms/pricingxls) to run the interactive services like promotion simulation.
* Read through the [User Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/User%20Guide/UserGuide.md)
  and complete the [simple promotion scenario walkthrough](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/Walkthrough%201%20-%20Promotion%20Simulation/PromoSimulationWalkthrough.md).
* If you implement BI solutions, please read the [Technical Deployment Guide](https://github.com/Azure/cortana-intelligence-price-analytics/blob/master/Technical%20Deployment%20Guide/TechnicalDeploymentGuide.md).

### Keys and URLs for Excel services

You will need the following URLs and keys within the Excel spreadsheet.
Please paste them into the Azure Machine Learning plugin to connect to the services.
Follow the detailed setup and use instructions in the [spreadsheet](https://aka.ms/pricingxls). 

#### BuildModel Service

* URL: {Outputs.mlBuildModelEndpointUrl}
* API Key: {Outputs.mlBuildModelApiKey}

#### Interactive Services

```
{Outputs.mlRRSCredentials}
```
	
