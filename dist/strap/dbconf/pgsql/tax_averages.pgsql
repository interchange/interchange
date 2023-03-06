Database  tax_averages  tax_averages.txt  __SQLDSN__

Database  tax_averages  AUTO_SEQUENCE   tax_average_id_seq
Database  tax_averages  AUTO_SEQUENCE_DROP 1
Database  tax_averages  KEY             tax_average_id
Database  tax_averages  COLUMN_DEF     "tax_average_id=INTEGER PRIMARY KEY NOT NULL DEFAULT NEXTVAL('tax_average_id_seq')"
Database  tax_averages  COLUMN_DEF     "state=VARCHAR(128) NOT NULL"
Database  tax_averages  COLUMN_DEF     "zip=VARCHAR(32) NOT NULL DEFAULT ''"
Database  tax_averages  COLUMN_DEF     "country=CHAR(2) NOT NULL DEFAULT 'US'"
Database  tax_averages  COLUMN_DEF     "has_nexus=BOOLEAN NOT NULL DEFAULT TRUE"
Database  tax_averages  COLUMN_DEF     "rate_percent=NUMERIC(7,3) NOT NULL"
Database  tax_averages  COLUMN_DEF     "rate_adjust_percent=NUMERIC(6,3)"
Database  tax_averages  COLUMN_DEF     "tax_shipping=BOOLEAN NOT NULL DEFAULT TRUE"
Database  tax_averages  NUMERIC         rate_percent,rate_adjust_percent
Database  tax_averages  PREFER_NULL     rate_adjust_percent
Database  tax_averages  POSTCREATE     "CREATE UNIQUE INDEX unq_tax_averages_zip_state_country ON tax_averages (zip, state, country)"
Database  tax_averages  NO_ASCII_INDEX  1
