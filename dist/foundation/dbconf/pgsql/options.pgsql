Database options options.txt  SQL
Database options DSN	      __SQLDSN__
ifdef SQLUSER
Database options USER         __SQLUSER__
endif
ifdef SQLPASS
Database options PASS         __SQLPASS__
endif
Database options DEFAULT_TYPE text
#Database options NUMERIC      price wholesale
Database options AUTO_NUMBER  100001
Database options NO_SEARCH    1

Database options COLUMN_DEF "code=varchar(64) primary key NOT NULL"
Database options COLUMN_DEF "description=text"
Database options COLUMN_DEF "differential=varchar(20)"
Database options COLUMN_DEF "mv_shipmode=varchar(255)"
Database options COLUMN_DEF "o_default=varchar(64)"
Database options COLUMN_DEF "o_enable=varchar(1)"
Database options COLUMN_DEF "o_group=varchar(20)"
Database options COLUMN_DEF "o_height=int"
Database options COLUMN_DEF "o_label=text"
Database options COLUMN_DEF "o_master=varchar(64)"
Database options COLUMN_DEF "o_matrix=varchar(1)"
Database options COLUMN_DEF "o_modular=varchar(1)"
Database options COLUMN_DEF "o_sort=varchar(16)"
Database options COLUMN_DEF "o_value=text"
Database options COLUMN_DEF "o_width=int"
Database options COLUMN_DEF "phantom=varchar(1)"
Database options COLUMN_DEF "price=varchar(20)"
Database options COLUMN_DEF "sku=varchar(64)"
Database options COLUMN_DEF "volume=varchar(20)"
Database options COLUMN_DEF "weight=varchar(20)"
Database options COLUMN_DEF "wholesale=varchar(20)"
Database options INDEX       o_enable
Database options INDEX       o_group
Database options INDEX       o_master
Database options INDEX       o_sort
Database options INDEX       sku
Database options ChopBlanks 1
