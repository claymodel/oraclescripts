#include <err.h>
#include <string.h>
#include <strings.h>
#include <stdio.h>
#include <stdlib.h>
#include <sysexits.h>
#include <unistd.h>

#include "common.h"

ocell text_pre;
ocell text_post;

coldata *columns = NULL;
ocell *data = NULL;

int ncolumns = 0;
int nrows = 0;

int tmpfd;
FILE *tmp;
char tmpfname[1024];

void output_resize(const int new_nrows) {
	data = realloc(data, new_nrows * ncolumns * sizeof(ocell));

	if (data == NULL && new_nrows > 0)
		err(EX_OSERR, NULL);

	if (new_nrows > nrows)
		bzero(data + (nrows * ncolumns), (new_nrows - nrows) * ncolumns * sizeof(ocell));

	nrows = new_nrows;
}

void output_init(const int new_nrows, const int new_ncolumns) {
	*text_pre = '\0';
	*text_post = '\0';

	if (columns != NULL) {
		free(columns);
		columns = NULL;
	}

	if (data != NULL) {
		free(data);
		data = NULL;
	}

	ncolumns = new_ncolumns;
	nrows = new_nrows;

	columns = calloc(ncolumns, sizeof(coldata));
	data = calloc(nrows * ncolumns, sizeof(ocell));

	if (columns == NULL || data == NULL)
		err(EX_OSERR, NULL);
}

void output_set_pre(const char *pre_in) {
	strncpy(text_pre, pre_in, MAXCELLLEN);
}

void output_set_post(const char *post_in) {
	strncpy(text_post, post_in, MAXCELLLEN);
}

void output_column_maxtextlen(const int col, const int len) {
	if (len > columns[col].maxtextlen)
		columns[col].maxtextlen = len;
}

void output_set_header(const int colid, const char *head) {
	if (colid > ncolumns)
		errx(EX_SOFTWARE, "output_set_header() with bad column number");

	strncpy(columns[colid].header, head, MAXCELLLEN);

	output_column_maxtextlen(colid, strlen(columns[colid].header));
}

void output_set_data(const int rowid, const int colid, const char *coldata) {
	strncpy(data[(rowid * ncolumns) + colid], coldata, MAXCELLLEN);
	output_column_maxtextlen(colid, strlen(data[(rowid * ncolumns) + colid]));
}

void output_print_cell(const char *s, const int colid) {
	int i;

	fprintf(tmp, " %s", s);

	if (colid < (ncolumns - 1)) {
		/* more to come: pad column and print separator */
		for (i = strlen(s); i < columns[colid].maxtextlen; i++)
			fprintf(tmp, " ");

		fprintf(tmp, " |");
	}
}

void output_print_sepline() {
	int i;
	int j;

	for (i = 0; i < ncolumns; i++) {
		fprintf(tmp, "-");

		for (j = 0; j < columns[i].maxtextlen; j++)
			fprintf(tmp, "-");

		fprintf(tmp, "-");

		if (i < (ncolumns - 1))
			/* more to come: print separator */
			fprintf(tmp, "+");
	}

	fprintf(tmp, "\n");
}

void output_display() {
	int i;
	int j;
	char cmd[1024];

	if (!ncolumns) {
		printf("ERROR: output_display(): No data to display.\n");
		return;
	}

	strcpy(tmpfname, "/tmp/dbseek.XXXXXX");
	if ((tmpfd = mkstemp(tmpfname)) == -1)
		err(EX_OSERR, "mkstemp()");

	if ((tmp = fdopen(tmpfd, "w")) == NULL)
		err(EX_OSERR, "fdopen(tempfile)");

	if (*text_pre)
		fprintf(tmp, "%s\n", text_pre);

	for (i = 0; i < ncolumns; i++)
		output_print_cell(columns[i].header, i);

	fprintf(tmp, "\n");

	output_print_sepline();

	if (!nrows)
		fprintf(tmp, "(no rows)\n");
	else {
		for (i = 0; i < nrows; i++) {
			for (j = 0; j < ncolumns; j++) {
				output_print_cell(data[(i * ncolumns) + j], j);
			}

			fprintf(tmp, "\n");
		}
		fprintf(tmp, "(%d row%s)\n", nrows, (nrows == 1 ? "" : "s"));
	}

	if (*text_post)
		fprintf(tmp, "%s\n", text_post);

	fprintf(tmp, "\n");

	fclose(tmp);

	sprintf(cmd, "less -E -F %s", tmpfname);
	system(cmd);
	unlink(tmpfname);
}

