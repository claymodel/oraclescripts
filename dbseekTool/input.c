#include <setjmp.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include <readline/readline.h>
#include <readline/history.h>

#include "common.h"

sigjmp_buf sigint_jmp_buf;
int sigint_jmp_enabled;

void input_sigint(int signal) {
	if (sigint_jmp_enabled)
		siglongjmp(sigint_jmp_buf, signal);

	fprintf(stderr, "SIGINT handler, but not sigint_jmp_enabled?!\n");
}

void input_history(const char *statement) {
	/*
	 * add to readline's history, but only if it's not the same
	 * line as previously entered
	 */
	HIST_ENTRY *histent;

	histent = history_get(history_length);
	if (histent == NULL || strcmp(histent->line, statement) != 0)
		/* only add if not duplicate of prev. line */
		add_history(statement);
}

/*
 * input_loop()
 *
 * notes on readline usage:
 *
 * also, proper multi-line input, especially with a prompt, apparently
 * either is badly documented or not (easy) to do at all. hence the
 * custom implementation with a separate statement buffer that is
 * filled with each readline. note that (only) complete statements are
 * committed to readline's history, so multi-line history entries
 * are there and even editable as usual.
 *
 * write_history() does save multi-line history entries as single lines
 * though, so they don't really survive a program restart.
 *
 * notes on signals:
 *
 * OCI client library installs signal handlers! these are set at
 * connect / beginsession time. we should be okay, though, as
 * we only set the handler for readline() and then restore it back
 * (see below).
 */
void input_loop() {
	char *line;
	char prompt[100];
	char statement[16384];
	void (*sigint_orig)();
	int i;

	sigint_orig = NULL;

	if (sigsetjmp(sigint_jmp_buf, 1) != 0) {
		/* sigint triggered longjmp */

		/* when we get here, remove our signal handler */
		sigint_jmp_enabled = 0;
		if (sigint_orig != NULL)
			signal(SIGINT, (*input_sigint));

		printf("\n"); 
	}

	line = NULL;
	*statement = '\0';

	for (;;) {
		if (strstr(statement, "\n") != NULL)
			sprintf(prompt, "%s%s ", oprompt, "-#");
		else
			sprintf(prompt, "%s%s ", oprompt, "=#");

		if (line != NULL)
			free(line);

		/*
		 * while readline()ing, enable longjmp out of it
		 * when SIGINT is received. otherwise the program
		 * wouldn't react before the read call returned.
		 *
		 * take care to restore OCI's original signal
		 * handler.
		 */
		sigint_jmp_enabled = 1;
		sigint_orig = signal(SIGINT, input_sigint);
		line = readline(prompt);
		sigint_jmp_enabled = 0;
		signal(SIGINT, sigint_orig);

		if (line == NULL)
			/* EOF */
			return;

		/* kill trailing spaces */
		for (i = strlen(line); i > 0 && isspace(*(line + i - 1)); i--)
			*(line + i - 1) = '\0';

		if (!*line)
			/* empty input */
			continue;

		if (!*statement && input_is_internal(line)) {
			/* internal commands only recognized when stand-alone */
			input_history(line);
			input_process_internal(line);
			*statement = '\0';
			continue;
		}

		if (!*statement && *line == '\\') {
			/* apparently an unknown backslash cmd */
			input_history(line);
			fprintf(stderr, "ERROR:  Internal command %s not recognized. "
			    "Try \\?.\n", line);
			*statement = '\0';
			continue;
		}

		strcat(statement, line);

		/* single-line '/' submits the query */
                if (strstr(statement, "\n/") == (statement + strlen(statement) - 2)) {
			input_history(statement);
			*(statement + strlen(statement) - 2) = '\0';
			process_query(statement, 0);
			*statement = '\0';
			continue;
		}

		/* line ended with ';' submits the query */
		/* FIXME: this would trigger on comments ending on ';' */
		if (*(statement + strlen(statement) - 1) == ';') {
			input_history(statement);
			*(statement + strlen(statement) - 1) = '\0';
			process_query(statement, 0);
			*statement = '\0';
			continue;
		}

		strcat(statement, "\n");
	}
}

