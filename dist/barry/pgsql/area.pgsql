Database  area  area.txt __SQLDSN__
#ifdef SQLUSER
Database  area  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  area  PASS         __SQLPASS__
#endif
Database  area  COLUMN_DEF   "code=VARCHAR(12) NOT NULL PRIMARY KEY"
Database  area  COLUMN_DEF   "selector=VARCHAR(20) NOT NULL"
Database  area  COLUMN_DEF   "name=VARCHAR(64) DEFAULT '' NOT NULL"
Database  area  COLUMN_DEF   "banner_img=VARCHAR(64)"
Database  area  COLUMN_DEF   "subs=VARCHAR(128)"
Database  area  COLUMN_DEF   "sort=VARCHAR(3) DEFAULT 'ZZ' NOT NULL"
Database  area  ChopBlanks   1
