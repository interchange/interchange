Database  recurring_items  recurring_items.txt __SQLDSN__
#ifdef SQLUSER
Database  recurring_items  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  recurring_items  PASS         __SQLPASS__
#endif
Database  recurring_items  COLUMN_DEF   "code=char(14) NOT NULL PRIMARY KEY"
Database  recurring_items  COLUMN_DEF   "username=CHAR(20) default '' NOT NULL"
Database  recurring_items  COLUMN_DEF   "sku=CHAR(14) NOT NULL"
Database  recurring_items  COLUMN_DEF   "quantity=CHAR(9) NOT NULL"
Database  recurring_items  COLUMN_DEF   "ship_to=text"
Database  recurring_items  COLUMN_DEF   "ship_method=text"
