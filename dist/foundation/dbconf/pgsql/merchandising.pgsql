Database  merchandising  merchandising.txt __SQLDSN__
ifdef SQLUSER
Database  merchandising  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  merchandising  PASS         __SQLPASS__
endif
Database  merchandising  DEFAULT_TYPE text
Database  merchandising  COLUMN_DEF   "sku=varchar(64) NOT NULL PRIMARY KEY"
Database  merchandising  COLUMN_DEF   "featured=varchar(32)"
Database  merchandising  COLUMN_DEF   "start_date=varchar(24)"
Database  merchandising  COLUMN_DEF   "finish_date=varchar(24)"
Database  merchandising  COLUMN_DEF   "cross_category=varchar(64)"
Database  merchandising  INDEX        featured start_date finish_date cross_category
