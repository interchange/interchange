Database  inventory  inventory.txt __SQLDSN__
ifdef SQLUSER
Database  inventory  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  inventory  PASS         __SQLPASS__
endif
Database  inventory  KEY          sku
Database  inventory  COLUMN_DEF   "sku=VARCHAR(64) NOT NULL PRIMARY KEY"
Database  inventory  COLUMN_DEF   "quantity=VARCHAR(12)"
Database  inventory  COLUMN_DEF   "account=varchar(128)"
Database  inventory  COLUMN_DEF   "cogs_account=varchar(128)"
