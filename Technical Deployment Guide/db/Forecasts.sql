
CREATE TABLE dbo.Forecasts (	
  RunDate               date not null,
  Source				varchar(100) not null,	-- where did the forecast come from?
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,
  CustomerSegment       varchar(100) not null,
  LastDayOfData         date not null,  -- forecast made using data up and including this  
  PeriodInDays			int not null,
  PeriodsAhead			int not null,
  ForecastPeriodStart	date not null,
  ForecastPeriodEnd		date not null,  -- end of the period whose demand is forecasted
  UnitPrice             float, -- forecast is conditional on this price. Should be decimal (6,2), but that's pulling the ADF tiger's tail.
  Demand                float not null,
  Demand90LB            float not null,
  Demand90UB            float not null,
  ActualSales			float null,
  sAPE					float null,
  qBar					float null
  primary key (RunDate, Item, SiteName, ChannelName, 
				LastDayOfData, ForecastPeriodStart, ForecastPeriodEnd)
)