
-- drop table dbo.Elasticities;

CREATE TABLE dbo.Elasticities (	
  RunDate               date not null,
  RelationValidDate     date not null,
  Item                  varchar(100) not null,
  SiteName              varchar(100) not null,
  ChannelName           varchar(100) not null,	
  CustomerSegment       varchar(100) not null,	
  Elasticity            float not null,
  Elasticity90LB        float not null,
  Elasticity90UB        float not null,
  primary key (RunDate, RelationValidDate, Item, SiteName, ChannelName, CustomerSegment)
)