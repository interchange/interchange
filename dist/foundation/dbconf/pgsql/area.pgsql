Database  area  area.txt     __SQLDSN__
ifdef SQLUSER
Database  area  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  area  PASS         __SQLPASS__
endif
Database  area  DEFAULT_TYPE text
Database  area  COLUMN_DEF   "code=VARCHAR(12) NOT NULL PRIMARY KEY"
Database  area  COLUMN_DEF   "name=VARCHAR(128) DEFAULT '' NOT NULL"
Database  area  COLUMN_DEF   "sort=VARCHAR(3) DEFAULT '00' NOT NULL"
Database  area  INDEX        sort
Database  area  INDEX        name
