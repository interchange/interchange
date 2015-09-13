Database  products  products.txt __SQLDSN__
Database  products  DEFAULT_TYPE varchar(128)
Database  products  KEY          sku
Database  products  HIDE_FIELD   inactive
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
Database  products  COLUMN_DEF   "inactive=varchar(3) default ''"
Database  products  COLUMN_DEF   "gift_cert=varchar(3) default ''"
Database  products  NO_ASCII_INDEX 1
Database  products  INDEX         description
Database  products  INDEX         price
Database  products  INDEX         category
Database  products  INDEX         prod_group
Database  products  INDEX         inactive
