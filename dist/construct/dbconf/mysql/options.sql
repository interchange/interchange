Database options options.txt SQL
Database options DSN	__SQLDSN__
Database options DEFAULT_TYPE text
Database options AUTO_NUMBER  100001

Database options COLUMN_DEF "code=char(64) primary key NOT NULL"
Database options COLUMN_DEF "sku=char(64) NOT NULL DEFAULT '', index(sku)"
Database options COLUMN_DEF "o_enable=char(1)"
Database options COLUMN_DEF "o_matrix=char(1)"
Database options COLUMN_DEF "o_modular=char(1)"
Database options COLUMN_DEF "o_group=char(20)"
Database options COLUMN_DEF "o_value=text"
Database options COLUMN_DEF "o_label=text"
Database options COLUMN_DEF "o_master=varchar(255)"
Database options COLUMN_DEF "o_width=int"
Database options COLUMN_DEF "o_height=int"
Database options COLUMN_DEF "include_on=varchar(255)"
Database options COLUMN_DEF "exclude_on=varchar(255)"
Database options COLUMN_DEF "price=varchar(20)"
Database options COLUMN_DEF "wholesale=varchar(20)"
Database options COLUMN_DEF "differential=varchar(20)"
Database options COLUMN_DEF "weight=varchar(20)"
Database options COLUMN_DEF "volume=varchar(20)"
Database options COLUMN_DEF "mv_shipmode=varchar(128)"
