Database  shipping  shipping.txt __SQLDSN__
#ifdef SQLUSER
Database  shipping  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  shipping  PASS         __SQLPASS__
#endif
Database  shipping  COLUMN_DEF   "code=VARCHAR(18) NOT NULL PRIMARY KEY"
Database  shipping  COLUMN_DEF   "description=VARCHAR(64)"
Database  shipping  COLUMN_DEF   "criteria=VARCHAR(128)"
Database  shipping  COLUMN_DEF   "min=VARCHAR(7)"
Database  shipping  COLUMN_DEF   "max=VARCHAR(9)"
Database  shipping  COLUMN_DEF   "formula=VARCHAR(128)"
Database  shipping  COLUMN_DEF   "query=TEXT"
Database  shipping  COLUMN_DEF   "opt=TEXT"
Database  shipping  ChopBlanks   1
