Database  cat  cat.txt      __SQLDSN__
ifdef SQLUSER
Database  cat  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  cat  PASS         __SQLPASS__
endif
Database  cat  DEFAULT_TYPE text
Database  cat  COLUMN_DEF   "code=varchar(20) NOT NULL PRIMARY KEY"
Database  cat  COLUMN_DEF   "sel=varchar(64) DEFAULT '' NOT NULL"
Database  cat  COLUMN_DEF   "name=varchar(64) DEFAULT '' NOT NULL"
Database  cat  COLUMN_DEF   "sort=varchar(4) DEFAULT 'ZZ' NOT NULL"
