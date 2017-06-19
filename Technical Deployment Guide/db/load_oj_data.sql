/*

cd BizOpsEcon-PricingPCS\data\

bcp pricingdemo.etl.oj_data_raw in 'oj_raw.csv' -S tosingli-sql.database.windows.net -U tosingli@tosingli-sql -c -F 2 -t `, -P

*/

-- Now populate the pricingdata table from that, fixing a date for a week
-- so that the whole thing takes place in 2017


-- #################################################################################
-- What data shift should we make?

select min(week), max(week) from etl.oj_data_raw;
-- week 160 should be about Dec 2017
-- 16o weeks is 3 years
-- week 0 should be Dec 2014 or Jan 1st, 2015

-- #################################################################################
-- What Unit Cost should we assume?

select Item, 0.8 * avg(UnitPrice)
from pricingdata
group by Item;

/* Let's do these:
tropicana	2.29
minute.maid	1.79
dominicks	1.39
*/

-- #################################################################################
-- Load the data

truncate table pricingdata;

insert into pricingdata
select 
	dateadd(week, [week], '2015-01-01') as SalesDate,
	replace(brand,'.','_') as Item,
	store as SiteName,
	'Retail' as ChannelName,
	'all' as CustomerSegment,	
	'OJ' as ItemHierarchy,
	price as UnitPrice,
	((	-- generate some non-constant unit price
		(0.03 * ABS(MONTH(dateadd(week, [week], '2015-01-01'))  - 6) - 0.15) -- cheapest in June		
		+ 0.001	* [week] -- inflation		
		+ 0.002 * (ABS(CHECKSUM(NewId())) % 100 - 50) -- noise for this week
	) + 1.0 )
	* 
	case	-- baseline cost for each brand
		when brand='tropicana' then 2.29
		when brand='minute.maid' then 1.79
		when brand='dominicks' then 1.39
		else 'Cause Error'
	end as UnitCost,
	exp(logmove) as Quantity
from etl.oj_data_raw;

update statistics pricingdata;

select min(SalesDate), max(SalesDate)
from pricingdata;
