
Database  orderline  orderline.txt __SQLDSN__
#ifdef SQLUSER
Database  orderline  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  orderline  PASS         __SQLPASS__
#endif
Database  orderline  COLUMN_DEF   "code=VARCHAR(14) NOT NULL PRIMARY KEY"
Database  orderline  COLUMN_DEF   "store_id=VARCHAR(9) DEFAULT '' NOT NULL"
Database  orderline  COLUMN_DEF   "order_number=VARCHAR(14) NOT NULL"
Database  orderline  COLUMN_DEF   "session=VARCHAR(32) NOT NULL"
Database  orderline  COLUMN_DEF   "username=VARCHAR(20) default '' NOT NULL"
Database  orderline  COLUMN_DEF   "shipmode=VARCHAR(32) default '' NOT NULL"
Database  orderline  COLUMN_DEF   "sku=VARCHAR(14) NOT NULL"
Database  orderline  COLUMN_DEF   "quantity=VARCHAR(9) NOT NULL"
Database  orderline  COLUMN_DEF   "price=VARCHAR(12) NOT NULL"
Database  orderline  COLUMN_DEF   "subtotal=VARCHAR(12) NOT NULL"
Database  orderline  COLUMN_DEF   "shipping=VARCHAR(12)"
Database  orderline  COLUMN_DEF   "taxable=VARCHAR(3)"
Database  orderline  COLUMN_DEF   "size=VARCHAR(30)"
Database  orderline  COLUMN_DEF   "color=VARCHAR(30)"
Database  orderline  COLUMN_DEF   "options=VARCHAR(255)"
Database  orderline  COLUMN_DEF   "order_date=varchar(32) NOT NULL"
Database  orderline  COLUMN_DEF   "update_date=timestamp"
Database  orderline  COLUMN_DEF   "status=VARCHAR(32)"
Database  orderline  COLUMN_DEF   "parent=VARCHAR(9)"
Database  orderline  ChopBlanks   1
