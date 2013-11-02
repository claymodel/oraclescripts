/* oops: oracle operations */

#include <oci.h>
#include <stdio.h>
#include <stdlib.h>
#include <sysexits.h>
#include <err.h>
#include <string.h>

#include "common.h"

int oerrcheck(sword rcode) {
	/*
	 * "oracle error" check:
	 *
	 * return true (1) on error, after printing details to stdout
	 * (if desired, specifying the given context)
	 *
	 * error code (oerrcode) and error message (oerrstring) are
	 * saved as globals for later use.
	 *
	 * return false (0) on OCI_SUCCESS
	 */

	if (rcode == OCI_SUCCESS)
		return 0;

	OCIErrorGet(oerr, 1, NULL, &oerrcode, (text *) oerrstring, sizeof(oerrstring), OCI_HTYPE_ERROR);
	return 1;
}

int oes(sword rcode) {
	/* silent check: don't print */
	return oerrcheck(rcode);
}

void oerrprint(const char *context) {
	/* simply print an already-determined error code (possibly after oe_silent()) */

	if (context == NULL)
		fprintf(stderr, "ERROR:  %s", oerrstring);
	else
		fprintf(stderr, "ERROR:  %s: %s", context, oerrstring);
}

int oec(sword rcode, const char *context) {
	/* oerrcheck with error message */
	int ret;

	ret = oerrcheck(rcode);

	if (ret)
		oerrprint(context);

	return ret;
}

int oe(sword rcode) {
	/* short hand for oec() without context */
	return (oec(rcode, NULL));
}

int oec_abort(sword rcode, const char *context, const int exitcode) {
	/* same as oec(), but on failure exit() with exitcode */
	if (!oec(rcode, context))
		return (rcode);

	exit(exitcode);
}

void oinit() {
	oprelimauth = 0;
	oshuttingdown = 0;
	oinstname = NULL;

	if (oe(OCIEnvCreate(&oenv, OCI_DEFAULT, (dvoid *)0, 0, 0, 0, (size_t) 0, (dvoid **)0))) {
		if (oerrcode == 1804)
			fprintf(stderr, "HINT: ORA-01804 may be caused by an invalid ORACLE_HOME.\n");

		exit(EX_CONFIG);
	}

	oec_abort(OCIHandleAlloc(oenv, (dvoid **) &oerr, OCI_HTYPE_ERROR, 0, 0),
	    "OCIHandleAlloc() for error handle", EX_OSERR);

	oec_abort(OCIHandleAlloc (oenv, (dvoid **) &osvc, OCI_HTYPE_SVCCTX, 0, 0),
	    "OCIHandleAlloc() for service context handle", EX_OSERR);

	oec_abort(OCIHandleAlloc (oenv, (dvoid **) &osrv, OCI_HTYPE_SERVER, 0, 0),
	    "OCIHandleAlloc() for server handle", EX_OSERR);

	oec_abort(OCIHandleAlloc (oenv, (dvoid **) &ossn, OCI_HTYPE_SESSION, 0, 0),
	    "OCIHandleAlloc() for session handle", EX_OSERR);
}

void update_oprompt() {
	/*
	 * XXX: bonkers; an updated prompt would require re-ServerAttach()ing, as the
	 * data in the osrv handle does not change on startup / shutdown
	 */
	oec(OCIAttrGet(osrv, OCI_HTYPE_SERVER, (dvoid *) &oinstname, (ub4 *) NULL, OCI_ATTR_INSTNAME, oerr),
	    "OCIAttrGet() for INSTNAME");

	if (oinstname != NULL) {
		strcpy(oprompt, (char *) oinstname);
		return;
	}

	oinstname = (OraText *) getenv("ORACLE_SID");

	if (oinstname == NULL)
		strcpy(oprompt, "<ORACLE_SID=?>");
	else
		sprintf(oprompt, "<ORACLE_SID=%s>", oinstname);
}

void obeginsession() {

	/*
	 * NOTE: OCIServerAttach(): if dblink (arg 3) is NULL, then and ONLY THEN
	 * the library authenticates as OS user using the ORACLE_SID environment
	 * (thus allowing SYSDBA authentication and connections to idle / closed
	 * instances)
	 *
	 * assumption: if dblink is given, the connection is not direct/local (?) but
	 * via TNS, which cannot do OS authentication
	 */

	OCISessionEnd(osvc, oerr, ossn, OCI_DEFAULT);
	OCIServerDetach(osrv, oerr, OCI_DEFAULT);

	oec_abort(OCIServerAttach(osrv, oerr, NULL, 0, OCI_DEFAULT),
	    "OCIServerAttach()", EX_CONFIG);

	oec_abort(OCIAttrSet(osvc, OCI_HTYPE_SVCCTX, osrv, 0, OCI_ATTR_SERVER, oerr),
	    "OCIAttrSet() service's server handle", EX_OSERR);

	// (void) OCIAttrSet(ossn, OCI_HTYPE_SESSION, (void *) username, strlen(username), OCI_ATTR_USERNAME, oerr);
	// (void) OCIAttrSet(ossn, OCI_HTYPE_SESSION, (void *) password, strlen(password), OCI_ATTR_PASSWORD, oerr);

	if (!oes(OCISessionBegin(osvc, oerr, ossn, OCI_CRED_EXT, OCI_SYSDBA))) {
		if (oprelimauth) {
			printf("Switched from preliminary to SYSDBA authentication.\n");
			oprelimauth = 0;
		}
	} else {
		/* ORA-01034: ORACLE not available -- instance is not running? */
		if (oerrcode != 1034) {
			oerrprint("OCISessionBegin()");
			exit(EX_SOFTWARE);
		}

		/* try prelim auth */
		oec_abort(OCISessionBegin(osvc, oerr, ossn, OCI_CRED_EXT, OCI_SYSDBA|OCI_PRELIM_AUTH),
		    "OCISessionBegin()", EX_SOFTWARE);

		/* control reaches here -> we have an idle instance */
		oprelimauth = 1;
		fprintf(stderr, "\n");
		fprintf(stderr, "-!- Connected to an idle instance, using preliminary authentication.\n");
		fprintf(stderr, "-!- Only the STARTUP command is available.\n");
		fprintf(stderr, "\n");
	}

	(void) OCIAttrSet(osvc, OCI_HTYPE_SVCCTX, ossn, 0, OCI_ATTR_SESSION, oerr);

	update_oprompt();

	if (!oprelimauth) {
		process_query("ALTER SESSION SET NLS_DATE_FORMAT =         'YYYY-MM-DD HH24:MI:SS'", 1);
		process_query("ALTER SESSION SET NLS_TIMESTAMP_FORMAT =    'YYYY-MM-DD HH24:MI:SSXFF'", 1);
		process_query("ALTER SESSION SET NLS_TIMESTAMP_TZ_FORMAT = 'YYYY-MM-DD HH24:MI:SSXFF TZR'", 1);
		process_query("ALTER SESSION SET NLS_TIME_FORMAT =                    'HH24:MI:SSXFF'", 1);
		process_query("ALTER SESSION SET NLS_TIME_TZ_FORMAT =                 'HH24:MI:SSXFF TZR'", 1);
	}
}

int ostart(int mode) {
	/*
	 * ... NOMOUNT part: always necessary
	 */
	if (oe(OCIDBStartup(osvc, oerr, NULL, OCI_DEFAULT, OCI_DEFAULT)))
		return 0;

	/* startup succeeded - switch session */
	oe(OCISessionEnd(osvc, oerr, ossn, OCI_DEFAULT));
	obeginsession();

	printf("Oracle initialized.\n");

	if (mode == STARTUP_NOMOUNT)
		return 1;

	if (!process_query("ALTER DATABASE MOUNT", 1))
		return 0;

	printf("ALTER DATABASE MOUNT\n");

	if (mode == STARTUP_RESTRICT) {
		if (!process_query("ALTER SYSTEM ENABLE RESTRICTED SESSION", 1))
			return 0;

		printf("ALTER SYSTEM ENABLE RESTRICTED SESSION\n");
	}

	if (mode == STARTUP_MOUNT)
		/* MOUNT means: mount, don't open. */
		return 1;

	if (!process_query("ALTER DATABASE OPEN", 1))
		return 0;

	printf("ALTER DATABASE OPEN\n");

	return 1;
}

int oshutdown(int mode) {
	if (mode == SHUTDOWN_ABORT) {
		if (oe(OCIDBShutdown(osvc, oerr, NULL, OCI_DBSHUTDOWN_ABORT)))
			return 0;

		printf("ORACLE INSTANCE ABORTED.\n");

		obeginsession();

		return 1;
	}

	if (mode == SHUTDOWN_NORMAL) {
		if (oe(OCIDBShutdown(osvc, oerr, NULL, OCI_DEFAULT)))
			return 0;

		printf("Shutdown (normal) initiated.\n");

	} else if (mode == SHUTDOWN_IMMEDIATE) {
		if (oe(OCIDBShutdown(osvc, oerr, NULL, OCI_DBSHUTDOWN_IMMEDIATE)))
			return 0;

		printf("Shutdown (immediate) initiated.\n");
	}

	oshuttingdown = 1;

	/*
	 * we ignore these during shutdown:
	 * ORA-01507: database not mounted
	 * ORA-01109: database not open
	 */

	if (process_query("ALTER DATABASE CLOSE NORMAL", 1))
		printf("ALTER DATABASE CLOSE NORMAL\n");
	else if (oerrcode != 1507 && oerrcode != 1109)
		return 0;

	if (process_query("ALTER DATABASE DISMOUNT", 1))
		printf("ALTER DATABASE DISMOUNT\n");
	else if (oerrcode != 1507 && oerrcode != 1109)
		return 0;

	if (oe(OCIDBShutdown(osvc, oerr, NULL, OCI_DBSHUTDOWN_FINAL)))
		return 0;

	printf("Oracle shut down.\n");

	oshuttingdown = 0;

	obeginsession();

	return 1;
}

int process_select() {
	/* we assume a prepared and executed statement at this time */
	int i;
	ub4 numcols;
	ub4 numrows;
	OCIParam *colparam;
	OraText *colname;

	if (oe(OCIAttrGet(ostmt, OCI_HTYPE_STMT, &numcols, 0, OCI_ATTR_PARAM_COUNT, oerr)))
		return 0;

	/*
	 * since we can't get the grand total row count in advance, we realloc() every 1000 rows,
	 * assuming that a realloc() for *every* iteration would probably be very costly. (?)
	 * we reduce to the correct amount at the very end.
	 */

	output_init(1000, numcols);

	ocell data[numcols];
	OCIDefine *defnp[numcols];
	sb2 ind[numcols];

	/* per-column data and Defines */
	for (i = 0; i < numcols; i++) {
		/* indication pointers (null, truncate) */
		if (oe(OCIDefineByPos(ostmt, &defnp[i], oerr, i + 1, &data[i], MAXCELLLEN,
		    SQLT_STR, &ind[i], 0, 0, OCI_DEFAULT)))
			return 0;

		/* column name */
		if (oe(OCIParamGet(ostmt, OCI_HTYPE_STMT, oerr, (dvoid **) &colparam, i + 1)))
			return 0;

		if (oe(OCIAttrGet(colparam, OCI_DTYPE_PARAM, &colname, 0, OCI_ATTR_NAME, oerr)))
			return 0;

		output_set_header(i, (char *) colname);
	}

	for (numrows = 1; /* forever */; numrows++) {
		if ((numrows % 1000) == 0)
			output_resize(numrows + 1000);

		if (oes(OCIStmtFetch2(ostmt, oerr, 1, OCI_FETCH_NEXT, 0, OCI_DEFAULT))) {
			if (oerrcode == 1403) {
				/* end of data */
				numrows--;
				break;
			} else if (oerrcode == 1406) {
				/* value truncated: NOOP (handled below) */
				;
			} else if (oerrcode == 24347) {
				/* Warning of a NULL column in an aggregate function: ignore / NOOP */
				oerrprint(NULL);
			} else {
				oerrprint("OCIStmtFetch2()");
				return 0;
			}
		}

		for (i = 0; i < numcols; i++) {
			if (ind[i] == -1)
				/* NULL value */
				strcpy(data[i], "");
			else if (ind[i] > 0 || ind[i] == -2)
				/* value truncated */
				strcpy(data[i] + MAXCELLLEN - 3, "<<<");

			output_set_data(numrows - 1, i, data[i]);
		}
	}

	output_resize(numrows);

	output_display();

	return 1;
}

int process_query(const char *statement, int silent) {
	ub2 sqlfncode;
	ub2 statement_type;
	ub4 iters;

	char *sqlfn;

	if (oe(OCIStmtPrepare(ostmt, oerr, (OraText *) statement, strlen(statement), OCI_NTV_SYNTAX, OCI_DEFAULT)))
		return 0;

	oe(OCIAttrGet(ostmt, OCI_HTYPE_STMT, &statement_type, 0, OCI_ATTR_STMT_TYPE, oerr));

	iters = 1;
	if (statement_type == OCI_STMT_SELECT)
		/* Only for non-SELECT, we need iters == 1 */
		iters = 0;

	if (oe(OCIStmtExecute(osvc, ostmt, oerr, iters, 0, NULL, NULL, OCI_DEFAULT)))
		return 0;

	oe(OCIAttrGet(ostmt, OCI_HTYPE_STMT, &sqlfncode, 0, OCI_ATTR_SQLFNCODE, oerr));

	sqlfn = getsqlfn(sqlfncode);

	if (sqlfncode == SQLFN_SELECT) {
		return process_select();
	}

	if (!silent) {
		if (sqlfn != NULL)
			fprintf(stdout, "%s\n", sqlfn);
		else
			fprintf(stdout, "Query OK: %s\n", statement);
	}

	if (sqlfncode == SQLFN_ALTER_DATABASE && !oshuttingdown) {
		/* instname becomes available after database is opened */
		obeginsession();
	}

	return 1;
}

void describe_table(const OraText *objname, const OraText *objschema, ub1 objtype, OCIDescribe *odesc, OCIParam *oparam) {
	int i;
	ub2 numcols;
	OCIParam *ocollist;
	OCIParam *ocol;
	ub2 coltype;
	ub2 colwidth;
	ub1 is_char;
	OraText *colname;
	char tmp[2048+1];

	if (oe(OCIAttrGet(oparam, OCI_DTYPE_PARAM, &numcols, 0, OCI_ATTR_NUM_COLS, oerr)))
		return;

	output_init(numcols, 2);

	snprintf(tmp, 2048, "%s %s.%s",
	    (objtype == OCI_PTYPE_VIEW) ? "View" : "Table",
	    objschema, objname);

	output_set_pre(tmp);
	output_set_header(0, "Column");
	output_set_header(1, "Type");

	if (oe(OCIAttrGet(oparam, OCI_DTYPE_PARAM, &ocollist, 0, OCI_ATTR_LIST_COLUMNS, oerr)))
		return;

	for (i = 1; i <= numcols; i++) {
		if (oe(OCIParamGet(ocollist, OCI_DTYPE_PARAM, oerr, (dvoid **) &ocol, i)))
			return;

		if (oe(OCIAttrGet(ocol, OCI_DTYPE_PARAM, &coltype, 0, OCI_ATTR_DATA_TYPE, oerr)))
			return;

		if (oe(OCIAttrGet(ocol, OCI_DTYPE_PARAM, &is_char, 0, OCI_ATTR_CHAR_USED, oerr)))
			return;

		if (is_char) {
			if (oe(OCIAttrGet(ocol, OCI_DTYPE_PARAM, &colwidth, 0, OCI_ATTR_CHAR_SIZE, oerr)))
				return;
		} else {
			if (oe(OCIAttrGet(ocol, OCI_DTYPE_PARAM, &colwidth, 0, OCI_ATTR_DATA_SIZE, oerr)))
				return;
		}

		if (oe(OCIAttrGet(ocol, OCI_DTYPE_PARAM, &colname, 0, OCI_ATTR_NAME, oerr)))
			return;

		snprintf(tmp, 2048, "%s (%d)", getsqltypename(coltype), colwidth);
		output_set_data(i - 1, 0, (char *) colname);
		output_set_data(i - 1, 1, tmp);
	}

	output_display();

	if (objtype == OCI_PTYPE_TABLE) {
		snprintf(tmp, 2047, SQL_TABLE_INDEXES, objschema, objname);
		process_query(tmp, 1);
	}
}

void describe(const char *objname_in) {
	ub1 objtype;
	OraText *objname;
	OraText *objschema;
	OCIParam *oparam = NULL;
	OCIDescribe *odesc = NULL;

	oec_abort(OCIHandleAlloc(oenv, (dvoid **) &odesc, OCI_HTYPE_DESCRIBE, 0, 0),
		"OCIHandleAlloc() for describe", EX_SOFTWARE);

	if (oe(OCIDescribeAny(osvc, oerr, (void *) objname_in, strlen(objname_in),
	    OCI_OTYPE_NAME, 0, OCI_PTYPE_UNK, odesc)))
		return;

	if (oe(OCIAttrGet(odesc, OCI_HTYPE_DESCRIBE, &oparam, 0, OCI_ATTR_PARAM, oerr)))
		return;

	if (oe(OCIAttrGet(oparam, OCI_DTYPE_PARAM, &objtype, 0, OCI_ATTR_PTYPE, oerr)))
		return;

	if (oe(OCIAttrGet(oparam, OCI_DTYPE_PARAM, &objname, 0, OCI_ATTR_OBJ_NAME, oerr)))
		return;

	if (oe(OCIAttrGet(oparam, OCI_DTYPE_PARAM, &objschema, 0, OCI_ATTR_OBJ_SCHEMA, oerr)))
		return;

	switch (objtype) {
		case OCI_PTYPE_TABLE: describe_table(objname, objschema, objtype, odesc, oparam); break;
		case OCI_PTYPE_VIEW:  describe_table(objname, objschema, objtype, odesc, oparam); break;
		default: printf("object type %d not supported\n", objtype);
	}
}

