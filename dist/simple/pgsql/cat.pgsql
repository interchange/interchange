Database  cat  cat.txt __SQLDSN__
#ifdef SQLUSER
Database  cat  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  cat  PASS         __SQLPASS__
#endif
Database  cat  COLUMN_DEF   "code=VARCHAR(20) NOT NULL PRIMARY KEY"
Database  cat  COLUMN_DEF   "area=VARCHAR(20) NOT NULL"
Database  cat  COLUMN_DEF   "selector=VARCHAR(20)"
Database  cat  COLUMN_DEF   "name=VARCHAR(64) NOT NULL"
Database  cat  COLUMN_DEF   "banner_text=VARCHAR(64) NOT NULL"
Database  cat  COLUMN_DEF   "subs=VARCHAR(128)"
Database  cat  COLUMN_DEF   "sort=VARCHAR(4) DEFAULT 'ZZ' NOT NULL"
Database  cat  COLUMN_DEF   "url=VARCHAR(128)"
Database  cat  ChopBlanks   1
