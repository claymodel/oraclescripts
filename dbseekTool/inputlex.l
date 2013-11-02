%{
#include <string.h>

#include <readline/readline.h>
#include <readline/history.h>

#include "common.h"

extern int yylex();

/* basic internal commands */
#define STARTUP 1
#define SHUTDOWN 2
#define RESTART 3
#define X_DU 10
#define X_D 11
#define X_DB 12
#define X_QM 13
#define X_DT 14
#define X_S 15
#define X_DP 16
#define X_DD 17
#define X_H 18
#define X_DS 19
#define X_V 20

/* and their arguments */
#define NOMOUNT 100
#define MOUNT 101
#define IMMEDIATE 102
#define ABORT 103
#define RESTRICT 104
#define NORMAL 105

#define OTHER 9000
#define EOQ 9001

%}

%option nounput nodefault noyywrap
/* %option debug */

%%

STARTUP		return STARTUP;
NOMOUNT		return NOMOUNT;
MOUNT		return MOUNT;
RESTRICT	return RESTRICT;

SHUTDOWN	return SHUTDOWN;
IMMEDIATE	return IMMEDIATE;
ABORT		return ABORT;
NORMAL		return NORMAL;

RESTART		return RESTART;

\\db		return X_DB;
\\dd		return X_DD;
\\dp		return X_DP;
\\ds		return X_DS;
\\dt		return X_DT;
\\du		return X_DU;
\\d		return X_D;
\\d[[:alnum:]]*	return OTHER;

\\s		return X_S;
\\s[[:alnum:]]*	return OTHER;

\\v		return X_V;
\\v[[:alnum:]]*	return OTHER;

\\h		return X_H;
\\h[[:alnum:]]*	return OTHER;

\\\?		return X_QM;

DESC		return X_D; /* sqlplus "comfort" */
SHOW[[:space:]]+PARAMETER	return X_DP; /* sqlplus "comfort" */

[ \t]+		/* noop */;
[^[:space:]]*	return OTHER;
.		return OTHER;

\n		return EOQ;
<<EOF>>		return EOQ;

%%

void input_parse_startup() {
	int mode = 0;
	int token;

	token = yylex();

	switch (token) {
		case NOMOUNT:
			mode = STARTUP_NOMOUNT;
			break;
		case MOUNT:
			mode = STARTUP_MOUNT;
			break;
		case RESTRICT:
			mode = STARTUP_RESTRICT;
			break;
		case EOQ:
			mode = STARTUP_DEFAULT;
			break;
		default:
			fprintf(stderr, "Invalid argument.\n");
			return;
	}

	if (yylex() != EOQ) {
			fprintf(stderr, "Syntax error.\n");
			return;
	}

	ostart(mode);
}

void input_parse_shutdown() {
	int mode = 0;
	int token;

	token = yylex();

	switch (token) {
		case IMMEDIATE:
			mode = SHUTDOWN_IMMEDIATE;
			break;
		case NORMAL:
			mode = SHUTDOWN_NORMAL;
			break;
		case ABORT:
			mode = SHUTDOWN_ABORT;
			break;
		case EOQ:
			mode = SHUTDOWN_DEFAULT;
			break;
		default:
			fprintf(stderr, "Invalid argument.\n");
			return;
	}

	if (yylex() != EOQ) {
		fprintf(stderr, "Syntax error.\n");
		return;
	}

	oshutdown(mode);
}

void input_parse_restart() {
	/* this is pretty ugly duplication */

	int mode = 0;
	int token;

	token = yylex();

	switch (token) {
		case NOMOUNT:
			mode = STARTUP_NOMOUNT;
			break;
		case MOUNT:
			mode = STARTUP_MOUNT;
			break;
		case RESTRICT:
			mode = STARTUP_RESTRICT;
			break;
		case EOQ:
			mode = STARTUP_DEFAULT;
			break;
		default:
			fprintf(stderr, "Invalid argument.\n");
			return;
	}

	if (yylex() != EOQ) {
			fprintf(stderr, "Syntax error.\n");
			return;
	}

	oshutdown(SHUTDOWN_IMMEDIATE);
	ostart(mode);
}

void input_x_db() {
	char s[1024];

	if (yylex() == EOQ)
		snprintf(s, 1023, SQL_X_DB_SUMMARY);
	else
		snprintf(s, 1023, SQL_X_DB_DETAIL, yytext);

	process_query(s, 1);
}

void input_x_dd() {
	char s[1024];
	char *search;

	if (yylex() == EOQ)
		search = "";
	else
		search = yytext;

	snprintf(s, 1023, SQL_X_DD, search, search);
	process_query(s, 1);
}

void input_x_dp() {
	char s[1024];
	char *search;

	if (yylex() == EOQ)
		search = "";
	else
		search = yytext;

	snprintf(s, 1023, SQL_X_DP, search, search);
	process_query(s, 1);
}

void input_x_ds() {
	process_query(SQL_X_DS, 1);
}

void input_x_dt() {
	char s[1024];
	char *search;

	if (yylex() == EOQ)
		search = "";
	else
		search = yytext;

	snprintf(s, 1023, SQL_X_DT, search, search);
	process_query(s, 1);
}

void input_x_du() {
	process_query(SQL_X_DU, 1);
}

void input_x_h() {
	HIST_ENTRY *hist;
	char timestamp[30];
	time_t ts_time;
	int i;

	for (i = 1; i <= history_length; i++) {
		hist = history_get(i);

		ts_time = history_get_time(hist);
		strftime(timestamp, 29, "%Y-%m-%d %H:%M:%S", localtime(&ts_time));

		printf("%5d  %-21s %s\n", i, timestamp, hist->line);
	}
}

void input_x_s() {
	char s[1024];

	if (yylex() == EOQ) {
		fprintf(stderr, "Schema name required.\n");
		return;
	}

	snprintf(s, 1023, SQL_X_S, yytext);
	process_query(s, 0);
}

void input_x_v() {
	printf("\n");
	printf("Database versions:\n");
	process_query(SQL_X_V_BANNER, 0);

	printf("Registry history:\n");
	process_query(SQL_X_V_REGISTRY, 0);

	printf("Client version: %s\n", OSQL_VERSION);
	printf("\n");
}

void input_x_d() {
	/* describe object */

	if (yylex() == EOQ) {
		fprintf(stderr, "Object name required.\n");
		return;
	}

	describe(yytext);
}

void input_x_qm() {
	/* question mark: help! */
	char *fmt = "    %-15s %s\n";

	printf("\n");
	printf("Internal Oracle commands:\n");
	printf("\n");

	printf("    STARTUP [ { NOMOUNT | MOUNT | RESTRICT} ]\n");
	printf("        Start Oracle; default mode is to mount and open the database.\n");
	printf("\n");

	printf("    SHUTDOWN [ { NORMAL | IMMEDIATE | ABORT } ]\n");
	printf("        Shut down Oracle.\n");
	printf("        WARNING: Default mode is IMMEDIATE instead of NORMAL.\n");
	printf("\n");

	printf("    RESTART [ { NOMOUNT | MOUNT | RESTRICT} ]\n");
	printf("        Shut down Oracle (in IMMEDIATE mode),\n");
	printf("        then STARTUP as specified (see above).\n");
	printf("\n");

	printf("Internal backslash commands:\n");
	printf("\n");

	printf(fmt, "\\d <object>",
		"describe object (currently: table, view)");

	printf(fmt, "\\db [<tspace>]",
		"list tablespaces, or list datafiles for given tspace");

	printf(fmt, "\\dd [<search>]",
		"show dictionary entry [matching <search>]");

	printf(fmt, "\\dp [<search>]",
		"show parameters [matching <search>]");

	printf(fmt, "\\ds",
		"show current activity");

	printf(fmt, "\\dt [<schema>]",
		"list tables [in <schema>]");

	printf(fmt, "\\du",
		"list users");

	printf("\n");

	printf(fmt, "\\h",
		"show history");

	printf("\n");

	printf(fmt, "\\s <schema>",
		"change current schema");

	printf("\n");

	printf(fmt, "\\v",
		"version information");

	printf("\n");

	printf(fmt, "\\?",
		"this help");

	printf("\n");
}

void input_process_internal(const char *statement) {
	int token;

	yy_scan_string(statement);

	switch ((token = yylex())) {
		case RESTART:
			input_parse_restart();
			break;
		case STARTUP:
			input_parse_startup();
			break;
		case SHUTDOWN:
			input_parse_shutdown();
			break;
		case X_DB:
			input_x_db();
			break;
		case X_DD:
			input_x_dd();
			break;
		case X_DP:
			input_x_dp();
			break;
		case X_DS:
			input_x_ds();
			break;
		case X_DT:
			input_x_dt();
			break;
		case X_DU:
			input_x_du();
			break;
		case X_D:
			input_x_d();
			break;
		case X_H:
			input_x_h();
			break;
		case X_S:
			input_x_s();
			break;
		case X_V:
			input_x_v();
			break;
		case X_QM:
			input_x_qm();
			break;
		default:
			fprintf(stderr, "ERROR:	 Internal error: Unknown internal command?\n");
	}

	yy_delete_buffer(YY_CURRENT_BUFFER);
}

int input_is_internal(const char *cmd) {
	int ret;

	yy_scan_string(cmd);

	ret = yylex();

	ret = (ret > 0 && ret < 100);

	yy_delete_buffer(YY_CURRENT_BUFFER);
	return ret;
}

