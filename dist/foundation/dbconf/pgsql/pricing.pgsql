Database  pricing  pricing.txt  __SQLDSN__
ifdef SQLUSER
Database  pricing  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  pricing  PASS         __SQLPASS__
endif
Database  pricing  KEY          sku

Database  pricing  COLUMN_DEF   "sku=VARCHAR(64) NOT NULL PRIMARY KEY"
Database  pricing  COLUMN_DEF   "price_group=VARCHAR(12) DEFAULT '' NOT NULL"
Database  pricing  COLUMN_DEF   "q2=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q5=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q10=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q25=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q100=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "w2=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "w5=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "w10=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "w25=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "w100=VARCHAR(12)"
Database  pricing  INDEX         price_group
