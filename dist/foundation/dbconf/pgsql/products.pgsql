Database  products  products.txt __SQLDSN__
ifdef SQLUSER
Database  products  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  products  PASS         __SQLPASS__
endif
Database  products  DEFAULT_TYPE varchar(128)
Database  products  KEY          sku
Database  products  COLUMN_DEF   "sku=varchar(64) NOT NULL PRIMARY KEY"
Database  products  COLUMN_DEF   "description=varchar(128)"
Database  products  COLUMN_DEF   "title=varchar(128)"
Database  products  COLUMN_DEF   "comment=text"
Database  products  COLUMN_DEF   "thumb=varchar(128)"
Database  products  COLUMN_DEF   "image=varchar(64)"
Database  products  COLUMN_DEF   "price=varchar(12)"
Database  products  COLUMN_DEF   "category=varchar(64)"
Database  products  COLUMN_DEF   "nontaxable=varchar(3)"
Database  products  COLUMN_DEF   "weight=varchar(12)"
Database  products  COLUMN_DEF   "size=varchar(96)"
Database  products  COLUMN_DEF   "color=varchar(96)"
Database  products  COLUMN_DEF   "related=text"
Database  products  COLUMN_DEF   "featured=varchar(32)"
Database  products  COLUMN_DEF   "inactive=char(1) default ''"
Database  products  NO_ASCII_INDEX 1
Database  products  INDEX         description
Database  products  INDEX         price
Database  products  INDEX         category
Database  products  INDEX         prod_group
Database  products  INDEX         inactive
