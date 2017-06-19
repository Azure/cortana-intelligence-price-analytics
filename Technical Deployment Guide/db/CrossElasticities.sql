CREATE TABLE dbo.CrossElasticities (	
  RunDate               date not null,
  RelationValidDate     date not null,
  CustomerSegment       varchar(100) not null,	
  DrivingItemKey        varchar(100) not null,
  DrivingSiteName       varchar(100) not null,
  DrivingChannelName    varchar(100) not null,	
  ImpactedItemKey       varchar(100) not null,
  ImpactedSiteName      varchar(100) not null,
  ImpactedChannelName   varchar(100) not null,	   
  CrossElasticity       float not null,
  primary key (RunDate, RelationValidDate, CustomerSegment, DrivingItemKey, DrivingSiteName, DrivingChannelName, ImpactedItemKey, ImpactedSiteName, ImpactedChannelName)
)