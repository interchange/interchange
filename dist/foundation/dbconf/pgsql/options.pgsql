Database options options.txt SQL
Database options DSN	__SQLDSN__
Database options DEFAULT_TYPE text
#Database options NUMERIC  price wholesale
Database options AUTO_NUMBER  100001
Database options NO_SEARCH    1

Database options COLUMN_DEF "code=char(64) primary key NOT NULL"
Database options COLUMN_DEF "description=text"
Database options COLUMN_DEF "differential=varchar(20)"
Database options COLUMN_DEF "mv_shipmode=varchar(128)"
Database options COLUMN_DEF "o_default=char(64)"
Database options COLUMN_DEF "o_enable=char(1) NOT NULL DEFAULT '', index(o_enable)"
Database options COLUMN_DEF "o_group=char(20) NOT NULL DEFAULT '', index(o_group)"
Database options COLUMN_DEF "o_height=int"
Database options COLUMN_DEF "o_label=text"
Database options COLUMN_DEF "o_master=varchar(64) NOT NULL DEFAULT '', index(o_master)"
Database options COLUMN_DEF "o_matrix=char(1)"
Database options COLUMN_DEF "o_modular=char(1)"
Database options COLUMN_DEF "o_sort=char(16) NOT NULL DEFAULT '', index(o_sort)"
Database options COLUMN_DEF "o_value=text"
Database options COLUMN_DEF "o_width=int"
Database options COLUMN_DEF "phantom=char(1)"
Database options COLUMN_DEF "price=varchar(20)"
Database options COLUMN_DEF "sku=char(64) NOT NULL DEFAULT '', index(sku)"
Database options COLUMN_DEF "volume=varchar(20)"
Database options COLUMN_DEF "weight=varchar(20)"
Database options COLUMN_DEF "wholesale=varchar(20)"
Database options POSTCREATE "create index options_o_group on options (o_group)"
Database options POSTCREATE "create index options_o_master on options (o_master)"
Database options POSTCREATE "create index options_o_sort on options (o_sort)"
Database options POSTCREATE "create index options_sku on options (sku)"
