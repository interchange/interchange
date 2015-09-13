Database  variants  variants.txt __SQLDSN__
Database  variants  DEFAULT_TYPE varchar(255)
Database  variants  COLUMN_DEF   "code=varchar(64) NOT NULL PRIMARY KEY"
Database  variants  COLUMN_DEF   "sku=varchar(64)"
Database  variants  COLUMN_DEF   "description=varchar(128)"
Database  variants  COLUMN_DEF   "comment=text"
Database  variants  COLUMN_DEF   "thumb=varchar(128)"
Database  variants  COLUMN_DEF   "image=varchar(128)"
Database  variants  COLUMN_DEF   "price=varchar(12)"
Database  variants  COLUMN_DEF   "weight=varchar(12)"
Database  variants  COLUMN_DEF   "inactive=varchar(1) default ''"
Database  variants  NO_ASCII_INDEX 1
Database  variants  INDEX         description price inactive sku
