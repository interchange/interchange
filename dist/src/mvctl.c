/*
 * mvctl.c: runs as a command line or cgi program and starts up
 *			Interchange in various modes
 *
 * $Id: mvctl.c,v 2.3 2007-03-30 11:39:42 pajamian Exp $
 *
 * Copyright (C) 1997-2002 Red Hat, Inc.
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

#define PERL      "/usr/bin/perl"
#define VendRoot  "/home/minivend"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(argc, argv)
     int argc;
     char** argv;
{
  int r;
  char minivend[255];

  printf("Content-type: text/plain\r\n\r\n");
  fflush(stdout);

  if(argv[1] == NULL) {
	  printf("Requires an argument.\n", argv[1]);
	  exit(0);
  }
  	

  strcpy(minivend, VendRoot);
  if(strcmp(argv[1], "start_unix") == 0) {
	  printf("Starting in UNIX mode...\n");
	  strcat(minivend, "/bin/start_unix");
  }
  else if(strcmp(argv[1], "start_inet") == 0) {
	  printf("Starting in INET mode...\n");
	  strcat(minivend, "/bin/start_inet");
  }
  else if(strcmp(argv[1], "restart_unix") == 0) {
	  printf("Re-starting in UNIX mode...\n");
	  strcat(minivend, "/bin/restart_unix");
  }
  else if(strcmp(argv[1], "restart_inet") == 0) {
	  printf("Re-starting in INET mode...\n");
	  strcat(minivend, "/bin/restart_inet");
  }
  else if(strcmp(argv[1], "stop") == 0) {
	  printf("Stopping server...\n");
	  strcat(minivend, "/bin/stop");
  }
  else {
	  printf("Unrecognized command %s.\n", argv[1]);
	  exit(0);
  }
  	

  execl(PERL, PERL, minivend, 0);
  printf("Could not exec %s.", PERL);
  exit(1);
}
