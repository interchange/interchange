Database  cat  cat.txt __SQLDSN__
#ifdef SQLUSER
Database  cat  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  cat  PASS         __SQLPASS__
#endif
Database  cat  DEFAULT_TYPE text
Database  cat  COLUMN_DEF   "code=char(20) NOT NULL PRIMARY KEY"
Database  cat  COLUMN_DEF   "sel=char(64) DEFAULT '' NOT NULL, index(sel)"
Database  cat  COLUMN_DEF   "name=char(64) DEFAULT '' NOT NULL, index(name)"
Database  cat  COLUMN_DEF   "sort=char(4) DEFAULT 'ZZ' NOT NULL, index(sort)"
Database  cat  ChopBlanks   1
