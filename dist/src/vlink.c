/*
 * vlink.c: runs as a CGI program and passes request to Interchange
 *          server via UNIX socket
 *
 * $Id: vlink.c,v 2.6 2007-08-09 13:40:52 pajamian Exp $
 *
 * Copyright (C) 2005-2007 Interchange Development Group,
 * http://www.icdevgroup.org/
 * Copyright (C) 1996-2002 Red Hat, Inc.
 * Copyright (C) 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 * MA  02110-1301  USA.
 */

#include "config.h"
#include <errno.h>
#include <fcntl.h>
#include <setjmp.h>
#include <signal.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#ifndef ENVIRON_DECLARED
extern char** environ;
#endif

/* CGI output to the server is on stdout, fd 1.
 */
#define CGIOUT 1

#ifdef HAVE_STRERROR
#define ERRMSG strerror
#else
#define ERRMSG perror
#endif



/* Return this message to the browser when the server is not running.
 */
void server_not_running()
{
  printf("Content-type: text/html\r\n\r\n");
  printf("<HTML><HEAD><TITLE>No response</TITLE></HEAD><BODY BGCOLOR=\"#FFFFFF\">");
  printf("<H3>We're sorry, the Interchange server is unavailable...</H3>\r\n");
  printf("We are out of service or may be experiencing high system\r\n");
  printf("demand. Please try again soon.</BODY></HTML>\r\n");
  exit(1);
}

/* Return this message to the browser when a system error occurs.
 * Should we log to a file?  Email to admin?
 */
static void die(e, msg)
     int e;
     char* msg;
{
  printf("Content-type: text/plain\r\n\r\n");
  printf("We are sorry, but the Interchange server is unavailable due to a\r\n");
  printf("system error.\r\n\r\n");
  printf("%s: %s (%d)\r\n", msg, ERRMSG(e), e);
  exit(1);
}


/* Read the entity from stdin if present.
 */
static int entity_len = 0;
static char* entity_buf = 0;

static void
get_entity()
{
  int len;
  char* cl;
  int nr;

  entity_len = 0;
  cl = getenv("CONTENT_LENGTH");
  if (cl != 0)
    entity_len = atoi(cl);

  if (entity_len == 0) {
    entity_buf = 0;
    return;
  }

  entity_buf = malloc(entity_len);
  if (entity_buf == 0)
    die(0, "malloc");

  nr = fread(entity_buf, 1, entity_len, stdin);
  if (nr == 0) {
    free(entity_buf);
    entity_len = 0;
    entity_buf = 0;
  }
}


static char ibuf[1024];		/* input buffer */
static jmp_buf reopen_socket;	/* bailout when server shuts down */
#define buf_size 1024		/* output buffer size */
static char buf[buf_size];	/* output buffer */
static char* bufp;		/* current position in output buffer */
static int buf_left;		/* space left in output buffer */
static int sock;		/* socket fd */

/* Open the unix file socket and make a connection to the server.  If
 * the server isn't listening on the socket, retry for LINK_TIMEOUT
 * seconds.
 */
static void open_socket()
{
  struct sockaddr_un sa;
  int size;
  int s;
  int i;
  int e;
  int r;
  uid_t euid;
  gid_t egid;


  sa.sun_family = AF_UNIX;
  strcpy(sa.sun_path, LINK_FILE);
#ifdef offsetof
  size = (offsetof (struct sockaddr_un, sun_path) + strlen (sa.sun_path) + 1);
#else
  size = sizeof(sa.sun_family) + strlen(sa.sun_path) + 1;
#endif

  for (i = 0;  i < LINK_TIMEOUT;  ++i) {
    sock = socket(PF_UNIX, SOCK_STREAM, 0);
    e = errno;
    if (sock < 0)
      die(e, "Could not open socket");

    do {
      s = connect(sock, (struct sockaddr*) &sa, size);
      e = errno;
    } while (s == -1 && e == EINTR);

    if (s == 0)
      break;
    close(sock);
    sleep(1);
  }
  if (s < 0) {
    server_not_running();
    exit(1);
  }
}

/* Close the socket connection.
 */
static void close_socket()
{
  if (close(sock) < 0)
    die(errno, "close");
}

/* Write out the output buffer to the socket.  If the cgi-bin server
 * has 'listen'ed on the socket but closes it before 'accept'ing our
 * connection, we'll get a EPIPE here and retry the connection over again.
 */
static void write_out()
{
  char* p = buf;
  int len = bufp - buf;
  int w;

  while (len > 0) {
    do {
      w = write(sock, p, len);
    } while (w < 0 && errno == EINTR); /* retry on interrupted system call */
    if (w < 0 && errno == EPIPE) /* server closed */
      longjmp(reopen_socket, 1); /* try to reopen the connection */
    if (w < 0)
      die(errno, "write");
    p += w;			/* write the rest out if short write */
    len -= w;
  }

  bufp = buf;			/* reset output buffer */
  buf_left = buf_size;
}

/* Write out LEN characters from STR to the cgi-bin server.
 */
static void out(len, str)
     int len;
     char* str;
{
  char* strp = str;
  int str_left = len;

  while (str_left > 0) {
    if (str_left < buf_left) {	       /* all fits in buffer */
      memcpy(bufp, strp, str_left);
      bufp += str_left;
      buf_left -= str_left;
      str_left = 0;
    } else {			       /* only part fits */
      memcpy(bufp, strp, buf_left);    /* copy in as much as fits */
      str_left -= buf_left;
      strp += buf_left;
      bufp += buf_left;
      write_out();		       /* write out buffer */
    }
  }
}

/* Writes the null-terminated STR to the cgi-bin server.
 */
static void outs(str)
     char* str;
{
  out(strlen(str), str);
}

/* Returns I as an ascii string.  Don't some systems define itoa for you?
 */
static char* itoa(i)
     int i;
{
  static char buf[32];
  sprintf(buf, "%d", i);
  return buf;
}

/* Sends the null-terminated value STR to the cgi-bin server.  First
 * writes the length, then a space, then the value, and finally an
 * aesthetic newline.
 */
static void outv(str)
     char* str;
{
  int len = strlen(str);

  outs(itoa(len));
  out(1, " ");
  out(len, str);
  out(1, "\n");
}

/* Send the program arguments (but not the program name argv[0])
 * to the server.
 */
static void send_arguments(argc, argv)
     int argc;
     char** argv;
{
  int i;

  outs("arg ");
  outs(itoa(argc - 1));		       /* number of arguments */
  outs("\n");
  for (i = 1;  i < argc;  ++i) {
    outv(argv[i]);
  }
}

/* Send the environment to the server.
 */
static void send_environment()
{
  int n;
  char** e;

  /* count number of env variables */
  for (e = environ, n = 0;  *e != 0;  ++e, ++n)
    ;

  outs("env ");
  outs(itoa(n));		       /* number of vars */
  outs("\n");
  for (e = environ;  *e != 0;  ++e) {
    outv(*e);
  }
}

/* Send entity if we have one.
 */
static void
send_entity()
{
  char* cl;
  int len;
  int left;
  int tr;

  if (entity_len > 0) {
    outs("entity\n");
    outs(itoa(entity_len));
    out(1, " ");
    out(entity_len, entity_buf);
    out(1, "\n");
  }
}

#define BUFSIZE 16384

struct buffer {
  int len;
  int written;
  struct buffer* nextbuf;
  char buf[BUFSIZE];
};

static struct buffer* new_buffer()
{
  struct buffer* buf = (struct buffer*) malloc(sizeof(struct buffer));
  if (buf == 0)
    die(0, "malloc");
  buf->len = 0;
  buf->written = 0;
  buf->nextbuf = 0;
  return buf;
}

static int read_from_server(bp)
     struct buffer* bp;
{
  int b;
  int n;
  char* a;

  b = BUFSIZE - bp->len;
  a = (bp->buf) + bp->len;
  do {
    n = read(sock, a, b);
  } while (n < 0 && errno == EINTR);
  if (n < 0)
    die(errno, "read");
  if (n == 0) {
    return 0;
  }
  bp->len += n;
  return 1;
}

static int write_to_client(bp)
     struct buffer* bp;
{
  int b = bp->len - bp->written;
  int n;

  do {
    n = write(CGIOUT, bp->buf + bp->written, b);
  } while (n < 0 && errno == EINTR);
  if (n < 0 && errno == EAGAIN)
    return 0;
  if (n < 0)
    die(errno, "write");
  bp->written += n;
  return (bp->written == bp->len);
}

static void return_response()
{
  int reading;
  int writing;
  fd_set readfds;
  fd_set writefds;
  int maxfd;
  int r;
  struct buffer* readbuf;
  struct buffer* writebuf;
  struct buffer* newbuf;

  int f;
  if (fcntl(CGIOUT, F_SETFL, O_NONBLOCK) < 0)
    die(errno, "fcntl");
  f = fcntl(CGIOUT, F_GETFL);

  reading = 1;
  readbuf = writebuf = new_buffer();

  for (;;) {
    if (writebuf->written == BUFSIZE && writebuf->nextbuf != 0) {
      newbuf = writebuf->nextbuf;
      free(writebuf);
      writebuf = newbuf;
    }

    writing = (writebuf->written < writebuf->len);

    if (!reading && !writing)
      break;
      
    FD_ZERO(&readfds);
    FD_ZERO(&writefds);
    maxfd = 0;
    if (reading) {
      FD_SET(sock, &readfds);
      maxfd = sock;
    }
    if (writing) {
      FD_SET(CGIOUT, &writefds);
      if (maxfd < CGIOUT)
        maxfd = CGIOUT;
    }

    r = select(maxfd + 1, &readfds, &writefds, 0, 0);
    if (r < 0)
      die(errno, "select");

    if (reading && FD_ISSET(sock, &readfds)) {
      if (readbuf->len == BUFSIZE) {
        newbuf = new_buffer();
        readbuf->nextbuf = newbuf;
        readbuf = newbuf;
      }
      r = read_from_server(readbuf);
      if (r == 0)
        reading = 0;
    }

    if (writing && FD_ISSET(CGIOUT, &writefds)) {
      r = write_to_client(writebuf);
    }
  }
}


#if 0
/* Now read the response from the cgi-bin server and return it to our
 * caller (httpd).  We assume the server just closes the socket at the
 * end of the response.
 */
static void read_sock()
{
  int nr;
  char* p;
  int w;

  for (;;) {
    do {
      nr = read(sock, ibuf, sizeof(ibuf));
    } while (nr < 0 && errno == EINTR);	/* interrupted system call */
    if (nr < 0)
      die(errno, "read");
    if (nr == 0)		       /* that's it, all done */
      break;

    p = ibuf;			       /* write it to our stdout */
    while (nr > 0) {
      do {
	w = write(CGIOUT, p, nr);
      } while (w < 0 && errno == EINTR);
      if (w < 0)
	die(errno, "write");
      p += w;			       /* and write again if short write */
      nr -= w;
    }
  }
}
#endif

int main(argc, argv)
     int argc;
     char** argv;
{

  /* Give us an EPIPE error instead of a SIGPIPE signal if the server
   * closes the socket on us.
   */
  if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
    die(errno, "signal");

  get_entity();

  /* If the server does close the socket, jump back here to reopen. */
  if (setjmp(reopen_socket)) {
    close_socket();		       /* close our end of old socket */
  }

  bufp = buf;			       /* init output buf */
  buf_left = buf_size;
  open_socket();		       /* open our connection */
  send_arguments(argc, argv);
  send_environment();
  send_entity();
  outs("end\n");
  write_out();			       /* flush output buffer */

  return_response();
  close_socket();
  return 0;
}
