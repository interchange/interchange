Database  affiliate  affiliate.txt __SQLDSN__
Database  affiliate  AUTO_NUMBER  A00000
ifdef SQLUSER
Database  affiliate  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  affiliate  PASS         __SQLPASS__
endif
Database  affiliate  COLUMN_DEF   "code=varchar(12) NOT NULL PRIMARY KEY"
Database  affiliate  DEFAULT_TYPE text
