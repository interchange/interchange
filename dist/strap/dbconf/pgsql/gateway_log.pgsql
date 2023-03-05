Database  gateway_log  gateway_log.txt  __SQLDSN__

Database  gateway_log  DEFAULT_TYPE   TEXT NOT NULL DEFAULT ''
Database  gateway_log  AUTO_SEQUENCE  gateway_log_id_seq
Database  gateway_log  AUTO_SEQUENCE_DROP 1
Database  gateway_log  KEY            gateway_log_id
Database  gateway_log  COLUMN_DEF     "gateway_log_id=INTEGER PRIMARY KEY NOT NULL DEFAULT NEXTVAL('gateway_log_id_seq')"
Database  gateway_log  INDEX          request_date
Database  gateway_log  INDEX          request_id
Database  gateway_log  INDEX          order_number
Database  gateway_log  INDEX          email
Database  gateway_log  NO_ASCII_INDEX 1
