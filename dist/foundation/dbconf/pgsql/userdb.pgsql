Database  userdb  userdb.txt   __SQLDSN__

ifdef SQLUSER
Database  userdb  USER         __SQLUSER__
endif
ifdef SQLPASS
Database  userdb  PASS         __SQLPASS__
endif
Database  userdb  DEFAULT_TYPE  VARCHAR(255)

## this truncates too-long user input that might cause a die otherwise
Database  userdb  LENGTH_EXCEPTION_DEFAULT  truncate_log

Database  userdb  COLUMN_DEF   "username=VARCHAR(20) NOT NULL PRIMARY KEY"
Database  userdb  COLUMN_DEF   "password=VARCHAR(20)"
Database  userdb  COLUMN_DEF   "acl=text"
Database  userdb  COLUMN_DEF   "mod_time=varchar(20)"
Database  userdb  COLUMN_DEF   "s_nickname=text"
Database  userdb  COLUMN_DEF   "company=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "fname=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "lname=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "address1=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "address2=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "address3=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "city=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "state=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "zip=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "country=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "phone_day=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "mv_shipmode=VARCHAR(255)"
Database  userdb  COLUMN_DEF   "b_nickname=text"
Database  userdb  COLUMN_DEF   "b_fname=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_lname=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_address1=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_address2=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_address3=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_city=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "b_state=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "b_zip=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "b_country=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "b_phone=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "mv_credit_card_type=VARCHAR(16)"
Database  userdb  COLUMN_DEF   "mv_credit_card_exp_month=VARCHAR(2)"
Database  userdb  COLUMN_DEF   "mv_credit_card_exp_year=VARCHAR(4)"
Database  userdb  COLUMN_DEF   "p_nickname=text"
Database  userdb  COLUMN_DEF   "email=VARCHAR(128)"
Database  userdb  COLUMN_DEF   "fax=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "phone_night=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "fax_order=VARCHAR(2)"
Database  userdb  COLUMN_DEF   "address_book=TEXT"
Database  userdb  COLUMN_DEF   "accounts=TEXT"
Database  userdb  COLUMN_DEF   "preferences=TEXT"
Database  userdb  COLUMN_DEF   "carts=TEXT"
Database  userdb  COLUMN_DEF   "owner=VARCHAR(20)"
Database  userdb  COLUMN_DEF   "file_acl=TEXT"
Database  userdb  COLUMN_DEF   "db_acl=TEXT"
Database  userdb  COLUMN_DEF   "order_numbers=TEXT"
Database  userdb  COLUMN_DEF   "email_copy=VARCHAR(1)"
Database  userdb  COLUMN_DEF   "mail_list=varchar(64)"
Database  userdb  COLUMN_DEF   "project_id=VARCHAR(20)"
Database  userdb  COLUMN_DEF   "account_id=VARCHAR(20)"
Database  userdb  COLUMN_DEF   "order_dest=VARCHAR(32)"
Database  userdb  COLUMN_DEF   "inactive=VARCHAR(32)"
Database  userdb  DEFAULT      "inactive=''"
Database  userdb  COLUMN_DEF   "credit_balance=VARCHAR(12)"

# Prevent problems with abstime representation
UserDB    default    time_field    none
