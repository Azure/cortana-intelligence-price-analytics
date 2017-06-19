CREATE TABLE [etl].[oj_data_raw]
(
	store		int not null,
	brand		varchar(100) not null,
	week		int not null,
	logmove		float not null,
	feat		smallint NOT NULL,
	price		float NOT NULL,
	AGE60		float NULL,
	EDUC		float,
	ETHNIC		float,
	INCOME		float,
	HHLARGE		float,
	WORKWOM		float,
	HVAL150		float,
	SSTRDIST	float,
	SSTRVOL		float,
	CPDIST5		float,
	CPWVOL5		float,
	primary key (store, brand, week)
);
