Database  orderline  orderline.txt __SQLDSN__
ifdef SQLUSER
Database  orderline  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  orderline  PASS         __SQLPASS__
endif
Database  orderline  DEFAULT_TYPE varchar(128)
Database  orderline  COLUMN_DEF   "code=varchar(14) NOT NULL PRIMARY KEY"
Database  orderline  COLUMN_DEF   "store_id=varchar(9)"
Database  orderline  COLUMN_DEF   "order_number=varchar(14) NOT NULL"
Database  orderline  COLUMN_DEF   "session=varchar(32) NOT NULL"
Database  orderline  COLUMN_DEF   "username=varchar(20)"
Database  orderline  COLUMN_DEF   "shipmode=varchar(255)"
Database  orderline  COLUMN_DEF   "sku=varchar(64) NOT NULL"
Database  orderline  COLUMN_DEF   "quantity=varchar(9) NOT NULL"
Database  orderline  COLUMN_DEF   "price=varchar(12) NOT NULL"
Database  orderline  COLUMN_DEF   "subtotal=varchar(12) NOT NULL"
Database  orderline  COLUMN_DEF   "shipping=varchar(12)"
Database  orderline  COLUMN_DEF   "taxable=varchar(3)"
Database  orderline  COLUMN_DEF   "size=varchar(255)"
Database  orderline  COLUMN_DEF   "color=varchar(255)"
Database  orderline  COLUMN_DEF   "options=text"
Database  orderline  COLUMN_DEF   "order_date=varchar(32) NOT NULL"
Database  orderline  COLUMN_DEF   "update_date=timestamp"
Database  orderline  COLUMN_DEF   "status=varchar(64)"
Database  orderline  COLUMN_DEF   "parent=varchar(9)"
Database  orderline  INDEX         store_id order_number
