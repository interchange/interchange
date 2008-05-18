Database options options.txt  __SQLDSN__
Database options DEFAULT_TYPE text
Database options AUTO_NUMBER  100001
Database options NO_SEARCH    1
Database options ChopBlanks   1

Database options COLUMN_DEF   "code=varchar(64) primary key NOT NULL"
Database options COLUMN_DEF   "sku=varchar(64) NOT NULL DEFAULT ''"
Database options COLUMN_DEF   "o_group=varchar(64) NOT NULL DEFAULT ''"
Database options COLUMN_DEF   "o_sort=varchar(16) NOT NULL DEFAULT ''"
Database options COLUMN_DEF   "o_default=varchar(128)"
Database options COLUMN_DEF   "o_height=integer"
Database options COLUMN_DEF   "o_width=integer"
Database options COLUMN_DEF   "price=varchar(250)"
Database options COLUMN_DEF   "wholesale=varchar(250)"

Database options PREFER_NULL  o_height o_width
Database options NUMERIC      o_height o_width
Database options INDEX        sku o_group o_sort
