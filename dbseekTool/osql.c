#include <oci.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysexits.h>

#include <readline/readline.h>
#include <readline/history.h>

#include <wordexp.h>

#include "common.h"

/* another idea taken from psql */
#define NL_IN_HISTORY 0x01
#define COMMENT_CHAR 0x02

void recode_history(char from, char to) {
	HIST_ENTRY *hist;
	int i;
	char *s;

	for (i = 1; i <= history_length; i++) {
		hist = history_get(i);
		s = hist->line;

		while (*s != '\0') {
			if (*s == from)
				*s = to;

			s++;
		}
	}
}

int main(int argc, char *argv[]) {
	char histfile[256];
	wordexp_t exp;

	oinit();

	oec_abort(OCIHandleAlloc (oenv, (dvoid **) &ostmt, OCI_HTYPE_STMT, 0, 0),
	    "OCIHandleAlloc() for statement handle", EX_OSERR);

	/* ----- */

	obeginsession();

	/* ----- */

	wordexp("~/.osql_history", &exp, 0);
	strncpy(histfile, exp.we_wordv[0], 255);
	wordfree(&exp);

	history_comment_char = COMMENT_CHAR;
	history_write_timestamps = 1;

	read_history(histfile);
	recode_history(NL_IN_HISTORY, '\n');

	input_loop();

	fprintf(stdout, "eof.\n");

	recode_history('\n', NL_IN_HISTORY);
	write_history(histfile);

	return (EX_OK);
}

