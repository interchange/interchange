# MiniVend database definition
Database  pricing  pricing.txt __SQLDSN__
#ifdef SQLUSER
Database  pricing  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  pricing  PASS         __SQLPASS__
#endif
Database  pricing  KEY          sku
Database  pricing  COLUMN_DEF   "q2=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "price_group=VARCHAR(2) DEFAULT '' NOT NULL"
Database  pricing  COLUMN_DEF   "sku=VARCHAR(9) NOT NULL PRIMARY KEY"
Database  pricing  COLUMN_DEF   "q5=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q10=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q25=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "q100=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "XL=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "S=VARCHAR(12)"
Database  pricing  COLUMN_DEF   "red=VARCHAR(12)"
Database  pricing  ChopBlanks   1
