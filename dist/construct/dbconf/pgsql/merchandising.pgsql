Database  merchandising  merchandising.txt __SQLDSN__
#ifdef SQLUSER
Database  merchandising  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  merchandising  PASS         __SQLPASS__
#endif
Database  merchandising  DEFAULT_TYPE text
Database  merchandising  COLUMN_DEF   "sku=char(20) NOT NULL PRIMARY KEY"
Database  merchandising  COLUMN_DEF   "featured=CHAR(32)"
Database  merchandising  COLUMN_DEF   "start=CHAR(24)"
Database  merchandising  COLUMN_DEF   "finish=CHAR(24)"
Database  merchandising  COLUMN_DEF   "cross_category=CHAR(64)"
