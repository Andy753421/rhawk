/*
 * select.c - Provide select functions for gawk.
 */

/*
 * Copyright (C) 2012 Andy Spencer
 *
 * GAWK is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * GAWK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
 */

#include <awk.h>

int plugin_is_GPL_compatible;

/* Select function:
 *   select(how, [timeout,] fd, ..)
 *   type = {to,from,error,any} */
static NODE *do_select(int nargs)
{
	/* Parse arguments */
	if (do_lint && get_curfunc_arg_count() < 2)
		lintwarn("select: not enough arguments");

	/* - check how */
	int read = 0, write = 0, except = 0;
	NODE *node = get_scalar_argument(0, FALSE);
	NODE *how  = force_string(node);
	if (!strcmp("to",    how->stptr)) write  = 1;
	if (!strcmp("from",  how->stptr)) read   = 1;
	if (!strcmp("error", how->stptr)) except = 1;
	if (!strcmp("any",   how->stptr)) read = write = except = 1;
	if (!read && !write && !except) {
		printf("select: invalid select type: %.*s\n",
				(int)how->stlen, how->stptr);
		return make_number((AWKNUM) -EINVAL);
	}

	/* - check timeout */
	int    first = 1;
	struct timeval _timeout = {.tv_sec = 1, .tv_usec = 0};
	struct timeval *timeout = &_timeout;
	NODE *next = get_scalar_argument(1, FALSE);
	if (next->type == Node_val && next->flags & NUMBER) {
		AWKNUM num = force_number(next);
		if (num < 0) {
			timeout  = NULL;
		} else {
			_timeout.tv_sec  = (int)num;
			_timeout.tv_usec = (num - (int)num) * 1E6;
			printf("timeout -> %lf %ld,%ld\n", num,
					_timeout.tv_sec,
					_timeout.tv_usec);
		}
		first = 2;
	}

	/* Clear fds */
	int nfds = 0;
	fd_set readfds, writefds, exceptfds;
	FD_ZERO(&readfds);
	FD_ZERO(&writefds);
	FD_ZERO(&exceptfds);

	/* Set fds */
	for (int i = first; i < nargs; i++) {
		NODE *node = get_scalar_argument(i, TRUE);
		if (node == NULL)
			continue;
		NODE *str  = force_string(node);
		struct redirect *redir =
			getredirect(str->stptr, str->stlen);
		if (redir == NULL) {
			int err = 0;
			int type = read && write ? redirect_twoway :
				   read          ? redirect_input  :
				   write         ? redirect_output : 0 ;
			redir = redirect(str, type, &err);
		}
		if (redir == NULL) {
			lintwarn("select: arg %d is not a redirect", i);
			continue;
		}
		if ((read  || except) && redir->iop->fd >= 0) {
			int fd = redir->iop->fd;
			if (read)      FD_SET(fd, &readfds);
			if (except)    FD_SET(fd, &exceptfds);
			if (fd > nfds) nfds = fd;
		}
		if ((write || except) && redir->fp) {
			int fd = fileno(redir->fp);
			if (write)     FD_SET(fd, &writefds);
			if (except)    FD_SET(fd, &exceptfds);
			if (fd > nfds) nfds = fd;
		}
	}

	/* Select fds */
	int rval = select(nfds+1, &readfds, &writefds, &exceptfds, timeout);
	if (rval == 0)
		return make_number((AWKNUM) 0);
	if (rval == -1)
		return make_number((AWKNUM) 0);

	/* Return */
	for (int i = first; i < nargs; i++) {
		NODE *node = get_scalar_argument(i, TRUE);
		if (node == NULL)
			continue;
		NODE *str  = force_string(node);
		struct redirect *redir =
			getredirect(str->stptr, str->stlen);
		if (redir == NULL)
			continue;
		if ((read  || except) && redir->iop->fd >= 0) {
			int fd = redir->iop->fd;
			if ((read   && FD_ISSET(fd, &readfds))  ||
			    (except && FD_ISSET(fd, &writefds)))
				return node;
		}
		if ((write || except) && redir->fp) {
			int fd = fileno(redir->fp);
			if ((write  && FD_ISSET(fd, &writefds)) ||
			    (except && FD_ISSET(fd, &exceptfds)))
				return node;
		}
	}

	/* Error */
	return make_number((AWKNUM) 0);
}

/* Load select function */
NODE *dlload(NODE *tree, void *dl)
{
	make_builtin("select", do_select, 99);
	return make_number((AWKNUM) 0);
}
