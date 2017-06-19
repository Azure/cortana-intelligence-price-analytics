--########################################################################
-- generate product recommendations, wrapped in sql stored procedure


-- ##########################################################################
-- start by generating, for each product, location, etc, 
-- the Lerner index and percentage under/over.

/*
drop table dbo.UnderOver;
create table dbo.UnderOver
(
	Item 				varchar(100) not null,
	SiteName			varchar(100) not null,
	ChannelName			varchar(100) not null,
	CustomerSegment		varchar(100) not null,
	RunDate				date not null,
	ValidDate			date not null,
	LastPrice			float not null,
	LastCost			float null,
	Elasticity			float not null,
	MarginOptimalPrice		float null,
	Deviation			float null
	primary key (Item, SiteName, ChannelName, CustomerSegment, RunDate, ValidDate)
);

insert into dbo.UnderOver
select e.Item, e.SiteName, e.ChannelName, e.CustomerSegment, 
		RunDate, RelationValidDate as RelationValidDate,
		avg(UnitPrice) as LastPrice,
		avg(UnitCost)  as LastCost,
		avg(Elasticity) as Elasticity,
		avg(UnitCost) * avg(Elasticity) / (avg(Elasticity) + 1) as MarginOptimalPrice,
		(avg(UnitPrice) - avg(UnitCost) * avg(Elasticity) / (avg(Elasticity) + 1)) / avg(UnitPrice) as Deviation
from	Elasticities e join pricingdata p 
		on (e.Item = p.Item and p.ChannelName = e.ChannelName and p.SiteName=e.SiteName and p.CustomerSegment=e.CustomerSegment
		and p.SalesDate between dateadd(day, 1, dateadd(week, -1, RelationValidDate)) and RelationValidDate)
group by e.Item, e.SiteName, e.ChannelName, e.CustomerSegment, RunDate, RelationValidDate;

update statistics dbo.UnderOver;
*/

-- ##########################################################################
/*

-- schema in which to place things
create schema sug;
go

-- parameters for suggestion generation
drop table sug.suggestion_params;
create table sug.suggestion_params
(	
	suggestionRunID			varchar(200) not null primary key,
	lastDayOfData			date not null,			-- the "past period" will be of the same length as suggestion period, going back from lastDayOfData
	suggestionPeriodStart	date not null,
	suggestionPeriodEnd		date not null,
	minOrders				float not null,		-- min Sales in max channel to include a product	
);

-- default values
insert into sug.suggestion_params
VALUES ('S2017-05-30',
		'2017-05-01',
		'2017-05-28',
		'2017-06-01',
		'2017-06-28',
		0);

-- default values as described in the configuration guide
truncate table sug.suggestion_params;

insert into sug.suggestion_params
select	concat('M', today) as SuggestionRunID,
		dateadd(day, -7, today) as pastPeriodStart,
		dateadd(day,  0, today) as pastPeriodEnd,
		dateadd(day,  convert(int, coalesce(p1.paramValue, '1')), today) as suggestionPeriodStart,
		dateadd(day,  7, today) as suggestionPeriodEnd,
		0 as minOrders
from ( select convert(date, getdate()) as today ) t
	 left join Parameters p1 on paramName = 'sugLeadTime';

update statistics sug.suggestion_params;

select * from sug.suggestion_params;

-- ##########################################################################
-- Selection of individual candidate pool for suggestion
drop table sug.individual_selection;
select	suggestionRunID, pastPeriodStart, pastPeriodEnd, suggestionPeriodStart, suggestionPeriodEnd, minOrders,
		lastPeriod.Item, lastPeriod.SiteName, lastPeriod.ChannelName, lastPeriod.CustomerSegment,  
		Orders as OrdersLastPeriod, UnitsLastPeriod, 
		UnitsLastPeriod as BaselineForecast,
		avgSaleUnitPrice, avgCostUnitPrice, RevenueLastPeriod, MarginLastPeriod,			
		Elasticity,
		round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2) as marginOptimalPrice,
		round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01 as marginOptimalPriceRounded,
		exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2)) - log(avgSaleUnitPrice)) * elasticity) as multToOptimal,
		exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01) - log(avgSaleUnitPrice)) * elasticity) as multToRounded
		-- TODO: the rounding should be towards higher margin, not arbitrary arithmetic rounding
into sug.individual_selection
from (
	select par.*
		, Item, SiteName, ChannelName, CustomerSegment
		, count(1) as Orders
		, round(sum(Quantity),0) as UnitsLastPeriod
		, sum(Quantity * UnitPrice) as RevenueLastPeriod
		, sum(Quantity * (UnitPrice - coalesce(UnitCost,0))) as MarginLastPeriod
		, sum(Quantity * UnitPrice) / sum(Quantity) as avgSaleUnitPrice
		, sum(Quantity * coalesce(UnitCost,0)) / sum(Quantity) as avgCostUnitPrice
	from sug.suggestion_params par
		 cross join pricingdata p	 			 
	where SalesDate between pastPeriodStart and pastPeriodEnd
	group by suggestionRunID, pastPeriodStart, pastPeriodEnd, suggestionPeriodStart, suggestionPeriodEnd, minOrders,
			 Item, SiteName, ChannelName, CustomerSegment, minOrders
	having count(1) >= minOrders
	) lastPeriod
	join Elasticities e on (lastPeriod.Item=e.Item
						and lastPeriod.SiteName = e.SiteName 
						and lastPeriod.ChannelName = e.ChannelName 
						and lastPeriod.CustomerSegment = e.CustomerSegment
						and e.RelationValidDate = (select max(RelationValidDate)				-- use elasticity run closest to the time
												   from Elasticities cross join sug.suggestion_params
													where RelationValidDate <= pastPeriodEnd)
						and e.RunDate = (select max(RunDate) from Elasticities)					-- use latest elasticity run available 
							)		-- end join condition
;

-- select * from sug.individual_selection;

-- ########################################################################
-- Adding predicted outcomes to the data 

drop table sug.selection_with_outcomes;

select	suggestionRunID, pastPeriodStart, pastPeriodEnd, suggestionPeriodStart, suggestionPeriodEnd, minOrders,
		Item, SiteName, ChannelName, CustomerSegment,
		UnitsLastPeriod, 
		round(avgSaleUnitPrice, 2) as avgSaleUnitPrice,
		round(avgCostUnitPrice, 2) as avgCostUnitPrice,
		OrdersLastPeriod,
		round(RevenueLastPeriod,2) as RevenueLastPeriod, 
		round(MarginLastPeriod,2) as MarginLastPeriod,
		Elasticity,
		marginOptimalPrice,
		marginOptimalPriceRounded,
		round(100.0 * (marginOptimalPriceRounded - avgSaleUnitPrice) / avgSaleUnitPrice,0) as percentDeviation,
		round(multToOptimal * BaselineForecast,0) as forecastedDemandAtOptimum,
		round(multToRounded * BaselineForecast,0) as forecastedDemandAtRounded,
		round(multToRounded * BaselineForecast * marginOptimalPriceRounded, 0) as forecastedRevenueAtRounded,
		round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice), 2) as forecastedMarginAtRounded,
		round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice)	-- predicted margin
			 - BaselineForecast * (avgSaleUnitPrice - avgCostUnitPrice)							-- counterfactual margin		
			  , 2) as incrementalMargin
into sug.selection_with_outcomes
from sug.individual_selection;

select * from sug.selection_with_outcomes;

-- ########################################################################
go;

*/

DROP PROCEDURE [dbo].[spRecommendProducts];

go

CREATE PROCEDURE [dbo].[spRecommendProducts] (
	@SliceEnd				date,
	@lastDayOfData			date,
	@suggestionPeriodStart	date,
	@suggestionPeriodEnd	date,
	@minOrders				int
	)
AS
BEGIN
	
	DECLARE @runID				varchar(100);
	DECLARE @pastPeriodEnd		date;
	DECLARE @pastPeriodStart	date;

	SET @runID = concat('S', @SliceEnd);
	SET @pastPeriodEnd = @lastDayOfData;
	SET @pastPeriodStart = DATEADD(day, - DATEDIFF(day,@suggestionPeriodStart, @suggestionPeriodEnd), @lastDayOfData);

	-- ##########################################################################
	-- Selection of individual candidate pool for suggestion
	drop table if exists sug.individual_selection;
	select	@runID as suggestionRunID, 
			@pastPeriodStart as pastPeriodStart, 
			@pastPeriodEnd as pastPeriodEnd, 
			@suggestionPeriodStart as suggestionPeriodStart, 
			@suggestionPeriodEnd as suggestionPeriodEnd, 
			@minOrders as minOrders,
			lastPeriod.Item, lastPeriod.SiteName, lastPeriod.ChannelName, lastPeriod.CustomerSegment,  
			Orders as OrdersLastPeriod, UnitsLastPeriod, 
			UnitsLastPeriod as BaselineForecast,
			avgSaleUnitPrice, avgCostUnitPrice, RevenueLastPeriod, MarginLastPeriod,			
			Elasticity,
			round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2) as marginOptimalPrice,
			round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01 as marginOptimalPriceRounded,
			exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice, 2)) - log(avgSaleUnitPrice)) * elasticity) as multToOptimal,
			exp((log(round(Elasticity / (1 + Elasticity) * avgCostUnitPrice + 0.01,1) - 0.01) - log(avgSaleUnitPrice)) * elasticity) as multToRounded
			-- TODO: the rounding should be towards higher margin, not arbitrary arithmetic rounding
	into sug.individual_selection
	from (
		select Item, SiteName, ChannelName, CustomerSegment
			, count(1) as Orders
			, round(sum(Quantity),0) as UnitsLastPeriod
			, sum(Quantity * UnitPrice) as RevenueLastPeriod
			, sum(Quantity * (UnitPrice - coalesce(UnitCost,0))) as MarginLastPeriod
			, sum(Quantity * UnitPrice) / sum(Quantity) as avgSaleUnitPrice
			, sum(Quantity * coalesce(UnitCost,0)) / sum(Quantity) as avgCostUnitPrice
		from pricingdata p	 			 
		where SalesDate between @pastPeriodStart and @pastPeriodEnd
		group by Item, SiteName, ChannelName, CustomerSegment
		having count(1) >= @minOrders
		) lastPeriod
		join Elasticities e on (lastPeriod.Item=e.Item
							and lastPeriod.SiteName = e.SiteName 
							and lastPeriod.ChannelName = e.ChannelName 
							and lastPeriod.CustomerSegment = e.CustomerSegment
							and e.RelationValidDate = (select max(RelationValidDate)				-- use elasticity run closest to the time
													   from Elasticities cross join sug.suggestion_params
														where RelationValidDate <= pastPeriodEnd)
							and e.RunDate = (select max(RunDate) from Elasticities)					-- use latest elasticity run available 
							)		-- end join condition
	;

	-- ########################################################################
	-- Adding predicted outcomes to the data 

	drop table if exists sug.selection_with_outcomes;

	select	suggestionRunID, pastPeriodStart, pastPeriodEnd, suggestionPeriodStart, suggestionPeriodEnd, minOrders,
			Item, SiteName, ChannelName, CustomerSegment,
			UnitsLastPeriod, 
			round(avgSaleUnitPrice, 2) as avgSaleUnitPrice,
			round(avgCostUnitPrice, 2) as avgCostUnitPrice,
			OrdersLastPeriod,
			round(RevenueLastPeriod,2) as RevenueLastPeriod, 
			round(MarginLastPeriod,2) as MarginLastPeriod,
			Elasticity,
			marginOptimalPrice,
			marginOptimalPriceRounded,
			round(100.0 * (marginOptimalPriceRounded - avgSaleUnitPrice) / avgSaleUnitPrice,0) as percentDeviation,
			round(multToOptimal * BaselineForecast,0) as forecastedDemandAtOptimum,
			round(multToRounded * BaselineForecast,0) as forecastedDemandAtRounded,
			round(multToRounded * BaselineForecast * marginOptimalPriceRounded, 0) as forecastedRevenueAtRounded,
			round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice), 2) as forecastedMarginAtRounded,
			round(multToRounded * BaselineForecast * (marginOptimalPriceRounded - avgCostUnitPrice)	-- predicted margin
				 - BaselineForecast * (avgSaleUnitPrice - avgCostUnitPrice)							-- counterfactual margin		
				  , 2) as incrementalMargin
	into sug.selection_with_outcomes
	from sug.individual_selection;

	-- ########################################################################
	-- Creating/ recordig in  the Suggestion Table 

	DELETE FROM SuggestionRuns
	WHERE SuggestionRunID = @runID;
	
	insert into dbo.SuggestionRuns
	select * 
	from sug.selection_with_outcomes;

	update statistics SuggestionRuns;

	-- ########################################################################
	-- All done

	RETURN 0
END

-- #########################################################################
-- Did it work?

/*
exec spRecommendProducts '2017-05-30', '2017-05-28', '2017-06-01', '2017-06-28', 0;

select *
from dbo.SuggestionRuns;

SELECT *
FROM sug.individual_selection;
*/