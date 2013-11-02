#ifndef HAVE_COMMON_H
#define HAVE_COMMON_H

/*
 * globals
 */

#define OSQL_VERSION	"osql 0.2 (2013-05-12)"

#include <oci.h>

OCIEnv     *oenv;    /* environment handle */
OCIError   *oerr;    /* error handle */
OCISvcCtx  *osvc;    /* service handle */
OCIServer  *osrv;    /* server handle */
OCISession *ossn;    /* user session handle */
OCIStmt    *ostmt;   /* statement handle */

sb4 oerrcode;
char oerrstring[512];
int oprelimauth;
int oshuttingdown;
char oprompt[100];

#define MAXCELLLEN 511

typedef struct {
	int sqlfnid;
	char *statement;
} sqlfncode_t;

typedef struct {
        int typecode;
        char *typename;
} sqltypecode_t;

typedef char ocell[MAXCELLLEN+1];
typedef struct {
        int maxtextlen;
        ocell header;
} coldata;      

OraText *oinstname;


/*
 * functions
 */

int process_select();
int process_query(const char *statement, int silent);
void describe_table(const OraText *objname, const OraText *objschema, ub1 objtype, OCIDescribe *odesc, OCIParam *oparam);
void describe(const char *objname_in);
void process_input(const char *statement);

int oec(sword rcode, const char *context);
int oe_silent(sword rcode);
int oe(sword rcode);
int oec_abort(sword rcode, const char *context, const int exitcode);
void oinit();
void update_oprompt();
void obeginsession();
int ostart(int mode);
int oshutdown(int mode);

void output_init(const int new_nrows, const int new_ncolumns);
void output_resize(const int new_nrows);
void output_set_pre(const char *pre_in);
void output_set_post(const char *post_in);
void output_set_header(const int colid, const char *head);
void output_set_data(const int rowid, const int colid, const char *coldata);
void output_display();

void parse(char *cmd);
int input_is_internal(const char *cmd);
void input_process_internal(const char *statement);
void input_loop();

void input_parse_startup();
void input_parse_shutdown();

char *getsqlfn(int sqlfncode);
char *getsqltypename(int sqltypecode);

/*
 * other constants
 */

#define STARTUP_NOMOUNT		1
#define STARTUP_RESTRICT	2
#define STARTUP_MOUNT		3
#define STARTUP_DEFAULT		4

#define SHUTDOWN_NORMAL		1
#define SHUTDOWN_IMMEDIATE	2
#define SHUTDOWN_ABORT		3
#define SHUTDOWN_DEFAULT	SHUTDOWN_IMMEDIATE

/*
 * our SQL commands (for backslash commands)
 */

#define SQL_X_DB_SUMMARY \
	"SELECT" \
	"	ts.tablespace_name AS tablespace," \
	"	ts.contents," \
	"	ts.status," \
	"	ts.segment_space_management AS \"AUTO?\"," \
	"	count(df.file_id) as num_df," \
	"	round(sum(df.maxbytes)/1024/1024) as maxsize_mb," \
	"	round(sum(df.bytes)/1024/1024) as cursize_mb," \
	"	CASE WHEN sum(maxbytes) = 0 THEN NULL ELSE round(100 - sum(bytes)*100/sum(maxbytes)) END AS pct_free" \
	" FROM dba_tablespaces ts" \
	"	LEFT JOIN dba_data_files df ON (df.tablespace_name = ts.tablespace_name)" \
	" GROUP BY ts.tablespace_name, ts.contents, ts.status, ts.segment_space_management" \
	" ORDER BY tablespace"

#define SQL_X_DB_DETAIL \
	"SELECT tablespace_name AS tablespace, file_name, autoextensible AS \"AUTO?\"," \
	"       round(bytes/1024/1024) AS size_mb," \
	"	round(nvl(hwm, 1) * (SELECT value FROM v$parameter WHERE name='db_block_size')/1024/1024) AS min_mb," \
	"	round(maxbytes/1024/1024) AS max_mb," \
	"	round(increment_by * (SELECT value FROM v$parameter WHERE name='db_block_size')/1024/1024) as increment_by_mb" \
	" FROM dba_data_files df," \
	" 	( SELECT file_id, max(block_id+blocks-1) hwm" \
	"	 FROM dba_extents GROUP by file_id ) e" \
	" WHERE df.file_id = e.file_id(+)" \
	"	AND LOWER(tablespace_name) LIKE LOWER('%s')" \
	" ORDER BY tablespace_name, file_name"

#define SQL_X_DD \
	"SELECT table_name, comments" \
	" FROM SYS.dictionary" \
	" WHERE INSTR(LOWER(table_name), LOWER('%s')) IS NULL OR INSTR(LOWER(table_name), LOWER('%s')) > 0" \
	" ORDER BY table_name"

#define SQL_X_DP \
	"SELECT name, display_value, isdefault" \
	" FROM SYS.v$parameter" \
	" WHERE" \
	"	INSTR(LOWER(name || '=' || display_value), LOWER('%s')) IS NULL" \
	"	OR INSTR(LOWER(name || '=' || display_value), LOWER('%s')) > 0" \
	" ORDER BY name"

#define SQL_X_DS \
	"SELECT sid, serial#, username as \"user\", schemaname as \"schema\", machine, port, program, logon_time," \
	"	status, trunc(wait_time_micro/1000000, 2) as wait_time, sql_text" \
	" FROM v$session s LEFT JOIN v$sqlarea sql ON s.sql_id=sql.sql_id" \
	" ORDER BY status, wait_time_micro"

#define SQL_X_DT \
	"SELECT owner, table_name, tablespace_name, status" \
	" FROM dba_tables" \
	" WHERE LOWER(owner || '.' || table_name) LIKE" \
		" LOWER((SELECT CASE WHEN '%s' != '%%'" \
			" THEN '%s%%'" \
			" ELSE (SELECT sys_context('USERENV','SESSION_SCHEMA') FROM DUAL)" \
				" || '.' || '%%' END from dual))" \
	" ORDER BY owner, table_name"

#define SQL_X_DU \
	"SELECT username, account_status, lock_date, expiry_date, default_tablespace, profile" \
	" FROM dba_users" \
	" ORDER BY account_status, username"

#define SQL_X_S \
	"ALTER SESSION SET CURRENT_SCHEMA = %s"

#define SQL_X_V_BANNER \
	"SELECT banner FROM V$VERSION" \
	" ORDER BY 1"

#define SQL_X_V_REGISTRY \
	"SELECT version, action, comments, id, action_time" \
	" FROM DBA_REGISTRY_HISTORY" \
	" WHERE action IN ('UPGRADE', 'APPLY')" \
	" ORDER BY action_time"

#define SQL_TABLE_INDEXES \
	"SELECT i.index_name, i.tablespace_name, i.status," \
	" '(' || LISTAGG(c.column_name, ', ')" \
	"    WITHIN GROUP (ORDER BY c.column_position) || ')' AS columns" \
	" FROM dba_indexes i JOIN dba_ind_columns c" \
	"     ON (i.table_name=c.table_name AND i.table_owner=c.table_owner)" \
	" WHERE i.table_owner = '%s' AND i.table_name = '%s'" \
	" GROUP BY i.index_name, i.tablespace_name, i.status" \
	" ORDER BY i.index_name"

/*
 * from
 * http://download.oracle.com/docs/cd/E18283_01/appdev.112/e10646/ociaahan.htm#i428664
 */

#define SQLFN_CREATE_TABLE 1
#define SQLFN_SET_ROLE 2
#define SQLFN_INSERT 3
#define SQLFN_SELECT 4
#define SQLFN_UPDATE 5
#define SQLFN_DROP_ROLE 6
#define SQLFN_DROP_VIEW 7
#define SQLFN_DROP_TABLE 8
#define SQLFN_DELETE 9
#define SQLFN_CREATE_VIEW 10
#define SQLFN_DROP_USER 11
#define SQLFN_CREATE_ROLE 12
#define SQLFN_CREATE_SEQUENCE 13
#define SQLFN_ALTER_SEQUENCE 14
#define SQLFN_DROP_SEQUENCE 16
#define SQLFN_CREATE_SCHEMA 17
#define SQLFN_CREATE_CLUSTER 18
#define SQLFN_CREATE_USER 19
#define SQLFN_CREATE_INDEX 20
#define SQLFN_DROP_INDEX 21
#define SQLFN_DROP_CLUSTER 22
#define SQLFN_VALIDATE_INDEX 23
#define SQLFN_CREATE_PROCEDURE 24
#define SQLFN_ALTER_PROCEDURE 25
#define SQLFN_ALTER_TABLE 26
#define SQLFN_EXPLAIN 27
#define SQLFN_GRANT 28
#define SQLFN_REVOKE 29
#define SQLFN_CREATE_SYNONYM 30
#define SQLFN_DROP_SYNONYM 31
#define SQLFN_ALTER_SYSTEM_SWITCH_LOG 32
#define SQLFN_SET_TRANSACTION 33
#define SQLFN_PLSQL_EXECUTE 34
#define SQLFN_LOCK 35
#define SQLFN_NOOP 36
#define SQLFN_RENAME 37
#define SQLFN_COMMENT 38
#define SQLFN_AUDIT 39
#define SQLFN_NO_AUDIT 40
#define SQLFN_ALTER_INDEX 41
#define SQLFN_CREATE_EXTERNAL_DATABASE 42
#define SQLFN_DROP_EXTERNAL_DATABASE 43
#define SQLFN_CREATE_DATABASE 44
#define SQLFN_ALTER_DATABASE 45
#define SQLFN_CREATE_ROLLBACK_SEGMENT 46
#define SQLFN_ALTER_ROLLBACK_SEGMENT 47
#define SQLFN_DROP_ROLLBACK_SEGMENT 48
#define SQLFN_CREATE_TABLESPACE 49
#define SQLFN_ALTER_TABLESPACE 50
#define SQLFN_DROP_TABLESPACE 51
#define SQLFN_ALTER_SESSION 52
#define SQLFN_ALTER_USER 53
#define SQLFN_COMMIT_WORK 54
#define SQLFN_ROLLBACK 55
#define SQLFN_SAVEPOINT 56
#define SQLFN_CREATE_CONTROL_FILE 57
#define SQLFN_ALTER_TRACING 58
#define SQLFN_CREATE_TRIGGER 59
#define SQLFN_ALTER_TRIGGER 60
#define SQLFN_DROP_TRIGGER 61
#define SQLFN_ANALYZE_TABLE 62
#define SQLFN_ANALYZE_INDEX 63
#define SQLFN_ANALYZE_CLUSTER 64
#define SQLFN_CREATE_PROFILE 65
#define SQLFN_DROP_PROFILE 66
#define SQLFN_ALTER_PROFILE 67
#define SQLFN_DROP_PROCEDURE 68
#define SQLFN_ALTER_RESOURCE_COST 70
#define SQLFN_CREATE_SNAPSHOT_LOG 71
#define SQLFN_ALTER_SNAPSHOT_LOG 72
#define SQLFN_DROP_SNAPSHOT_LOG 73
#define SQLFN_CREATE_SNAPSHOT 74
#define SQLFN_ALTER_SNAPSHOT 75
#define SQLFN_DROP_SNAPSHOT 76
#define SQLFN_CREATE_TYPE 77
#define SQLFN_DROP_TYPE 78
#define SQLFN_ALTER_ROLE 79
#define SQLFN_ALTER_TYPE 80
#define SQLFN_CREATE_TYPE_BODY 81
#define SQLFN_ALTER_TYPE_BODY 82
#define SQLFN_DROP_TYPE_BODY 83
#define SQLFN_DROP_LIBRARY 84
#define SQLFN_TRUNCATE_TABLE 85
#define SQLFN_TRUNCATE_CLUSTER 86
#define SQLFN_CREATE_BITMAPFILE 87
#define SQLFN_ALTER_VIEW 88
#define SQLFN_DROP_BITMAPFILE 89
#define SQLFN_SET_CONSTRAINTS 90
#define SQLFN_CREATE_FUNCTION 91
#define SQLFN_ALTER_FUNCTION 92
#define SQLFN_DROP_FUNCTION 93
#define SQLFN_CREATE_PACKAGE 94
#define SQLFN_ALTER_PACKAGE 95
#define SQLFN_DROP_PACKAGE 96
#define SQLFN_CREATE_PACKAGE_BODY 97
#define SQLFN_ALTER_PACKAGE_BODY 98
#define SQLFN_DROP_PACKAGE_BODY 99
#define SQLFN_CREATE_DIRECTORY 157
#define SQLFN_DROP_DIRECTORY 158
#define SQLFN_CREATE_LIBRARY 159
#define SQLFN_CREATE_JAVA 160
#define SQLFN_ALTER_JAVA 161
#define SQLFN_DROP_JAVA 162
#define SQLFN_CREATE_OPERATOR 163
#define SQLFN_CREATE_INDEXTYPE 164
#define SQLFN_DROP_INDEXTYPE 165
#define SQLFN_ALTER_INDEXTYPE 166
#define SQLFN_DROP_OPERATOR 167
#define SQLFN_ASSOCIATE_STATISTICS 168
#define SQLFN_DISASSOCIATE_STATISTICS 169
#define SQLFN_CALL_METHOD 170
#define SQLFN_CREATE_SUMMARY 171
#define SQLFN_ALTER_SUMMARY 172
#define SQLFN_DROP_SUMMARY 173
#define SQLFN_CREATE_DIMENSION 174
#define SQLFN_ALTER_DIMENSION 175
#define SQLFN_DROP_DIMENSION 176
#define SQLFN_CREATE_CONTEXT 177
#define SQLFN_DROP_CONTEXT 178
#define SQLFN_ALTER_OUTLINE 179
#define SQLFN_CREATE_OUTLINE 180
#define SQLFN_DROP_OUTLINE 181
#define SQLFN_UPDATE_INDEXES 182
#define SQLFN_ALTER_OPERATOR 183
 
#endif /* HAVE_COMMON_H */

