Database  gift_certs  gift_certs.txt __SQLDSN__
ifdef SQLUSER
Database  gift_certs  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  gift_certs  PASS         __SQLPASS__
endif
Database  gift_certs  COLUMN_DEF   "code=varchar(14) NOT NULL PRIMARY KEY"
Database  gift_certs  COLUMN_DEF   "username=VARCHAR(20) default '' NOT NULL"
Database  gift_certs  COLUMN_DEF   "order_date=varchar(32) NOT NULL"
Database  gift_certs  COLUMN_DEF   "original_amount=float(4) NOT NULL"
Database  gift_certs  COLUMN_DEF   "redeemed_amount=float(4) NOT NULL"
Database  gift_certs  COLUMN_DEF   "available_amount=float(4) NOT NULL"
Database  gift_certs  COLUMN_DEF   "passcode=VARCHAR(20) NOT NULL"
Database  gift_certs  COLUMN_DEF   "active=VARCHAR(3)"
Database  gift_certs  COLUMN_DEF   "redeemed=VARCHAR(3)"
Database  gift_certs  COLUMN_DEF   "update_date=timestamp"
