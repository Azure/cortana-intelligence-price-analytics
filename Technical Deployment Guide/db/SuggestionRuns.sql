USE [pricingdemo]
GO

/****** Object: Table [dbo].[SuggestionRuns] Script Date: 6/13/2017 2:55:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SuggestionRuns] (
    [suggestionRunID]            VARCHAR (200) NOT NULL,
    [pastPeriodStart]            DATE          NOT NULL,
    [pastPeriodEnd]              DATE          NOT NULL,
    [suggestionPeriodStart]      DATE          NOT NULL,
    [suggestionPeriodEnd]        DATE          NOT NULL,
    [minOrders]                  FLOAT (53)    NOT NULL,
    [Item]                       VARCHAR (100) NOT NULL,
    [SiteName]                   VARCHAR (100) NOT NULL,
    [ChannelName]                VARCHAR (100) NOT NULL,
    [CustomerSegment]            VARCHAR (100) NOT NULL,
    [UnitsLastPeriod]            FLOAT (53)    NULL,
    [avgSaleUnitPrice]           FLOAT (53)    NULL,
    [avgCostUnitPrice]           FLOAT (53)    NULL,
    [Orders]                     INT           NULL,
    [RevenueLastPeriod]          FLOAT (53)    NULL,
    [MarginLastPeriod]           FLOAT (53)    NULL,
    [Elasticity]                 FLOAT (53)    NOT NULL,
    [marginOptimalPrice]         FLOAT (53)    NULL,
    [marginOptimalPriceRounded]  FLOAT (53)    NULL,
    [percentChange]              FLOAT (53)    NULL,
    [forecastedDemandAtOptimum]  FLOAT (53)    NULL,
    [forecastedDemandAtRounded]  FLOAT (53)    NULL,
    [forecastedRevenueAtRounded] FLOAT (53)    NULL,
    [forecastedMarginAtRounded]  FLOAT (53)    NULL,
    [incrementalMargin]          FLOAT (53)    NULL
);
