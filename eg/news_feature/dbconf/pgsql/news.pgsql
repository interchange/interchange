Database  news  news.txt __SQLDSN__
ifdef SQLUSER
Database  news  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  news  PASS         __SQLPASS__
endif
Database  news  DEFAULT_TYPE text
Database  news  COLUMN_DEF   "code=varchar(64) NOT NULL PRIMARY KEY"
Database  news  COLUMN_DEF   "featured=varchar(32) DEFAULT '' NOT NULL"
Database  news  COLUMN_DEF   "start_date=varchar(24) DEFAULT '' NOT NULL"
Database  news  COLUMN_DEF   "finish_date=varchar(24) DEFAULT '' NOT NULL"
Database  news  COLUMN_DEF   "posted_on=varchar(24) DEFAULT '' NOT NULL"
Database  news  COLUMN_DEF   "posted_by=varchar(64) DEFAULT '' NOT NULL"
Database  news  COLUMN_DEF   "posted_email=varchar(64)"
Database  news  COLUMN_DEF   "timed_news=varchar(8)"

