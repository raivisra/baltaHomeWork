CREATE TABLE MV_PRIORITIES(
  OWNER         VARCHAR2(30), --shemas nosaukums
  MV_NAME       VARCHAR2(128), --ar Oracle 12.2 max kolonu nosaukums var but 128
  PRIORITY      NUMBER(3),
  ACTIVE        NUMBER(1), --1 ja ieraksts aktivs , 0 ieraksts neaktivs
  FIRST_TIME    TIMESTAMP, --datums kad ieraksts tika izveidots
  LAST_TIME     TIMESTAMP --datums kad ieraksts ir pedejo reizi labots
)
/
CREATE TABLE MV_REFRESH_LOG(
  SESSION_ID    RAW(16),
  OWNER         VARCHAR2(30), --shemas nosaukums
  MV_NAME       VARCHAR2(128), --ar Oracle 12.2 max kolonu nosaukums var but 128
  START_TIME    TIMESTAMP, --datums kad MV refresh tika sakts
  END_TIME      TIMESTAMP, --datums kad MV refresh tika beigts
  dependency_path varchar2(1000),
  priority 		number,
  ERR_MSG       VARCHAR2(4000)
)
/
create index mv_refresh_log_sess_id on MV_REFRESH_LOG(session_id);
/
create index mv_refresh_log_start_time on MV_REFRESH_LOG(START_TIME);
/