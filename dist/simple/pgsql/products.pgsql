# MiniVend database definition
Database  products  products.txt __SQLDSN__
#ifdef SQLUSER
Database  products  USER         __SQLUSER__
#endif
#ifdef SQLPASS
Database  products  PASS         __SQLPASS__
#endif
Database  products  KEY          sku
Database  products  COLUMN_DEF   "sku=VARCHAR(14) NOT NULL PRIMARY KEY"
Database  products  COLUMN_DEF   "description=VARCHAR(128) NOT NULL"
Database  products  COLUMN_DEF   "title=VARCHAR(128) DEFAULT '' NOT NULL"
Database  products  COLUMN_DEF   "artist=VARCHAR(128) DEFAULT '' NOT NULL"
Database  products  COLUMN_DEF   "comment=TEXT"
Database  products  COLUMN_DEF   "display=VARCHAR(128)"
Database  products  COLUMN_DEF   "image=VARCHAR(64)"
Database  products  COLUMN_DEF   "price=VARCHAR(12) NOT NULL"
Database  products  COLUMN_DEF   "category=VARCHAR(64) NOT NULL"
Database  products  COLUMN_DEF   "nontaxable=VARCHAR(3)"
Database  products  COLUMN_DEF   "weight=VARCHAR(12)"
Database  products  COLUMN_DEF   "size=VARCHAR(96)"
Database  products  COLUMN_DEF   "color=VARCHAR(96)"
Database  products  COLUMN_DEF   "related=text"
Database  products  COLUMN_DEF   "featured=VARCHAR(32)"
Database  products  ChopBlanks   1
