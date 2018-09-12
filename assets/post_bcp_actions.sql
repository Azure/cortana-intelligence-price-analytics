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

----------------------------------------------------

truncate table Parameters;

INSERT INTO Parameters
VALUES 
('BulkElasticities_DeltaX', '-0.1'),
('BulkElasticities_WeekJump', '1'),
('BulkForecasts_periodsAhead', '1'),
('BulkCrossPrice_WeekJump', '1');