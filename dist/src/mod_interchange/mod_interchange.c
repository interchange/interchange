/*
 *  mod_interchange.c
 *  Apache module implementation of the Interchange link program.
 *
 *  $Id: mod_interchange.c,v 2.0.2.1 2002-11-26 03:21:09 jon Exp $
 *
 *  Support: http://www.icdevgroup.org/
 *
 *  Author: Francis J. Lacoste <francis.lacoste@iNsu.COM>
 *
 *  Copyright (C) 1999 Francis J. Lacoste, iNsu Innovations
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307 USA
 */

#include "httpd.h"
#include "http_config.h"
#include "http_core.h"
#include "http_log.h"
#include "http_main.h"
#include "http_protocol.h"
#include "util_script.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define IC_DEFAULT_PORT 7786
#define IC_DEFAULT_ADDR "127.0.0.1"

/* Forward declaration */
module MODULE_VAR_EXPORT interchange_module;

typedef struct ic_conf_struct
{
	struct sockaddr *sockaddr;  /* Socket of Interchange Server */
	int				family;		/* The socket family of that one */
	NET_SIZE_T		size;		/* The size of the socket */
	char			*address;	/* Human readable version of the above */
} ic_conf_rec;

typedef struct ic_response_buffer_struct
{
	int  buff_size;
	int  pos;
	char buff[HUGE_STRING_LEN];
} ic_response_buffer;

static void*
ic_create_dir_config(pool *p, char *dir)
{
	struct sockaddr_in *inet_sock;

	ic_conf_rec *conf_rec = (ic_conf_rec *)ap_pcalloc(p, sizeof(ic_conf_rec));

	/* Default connection method is INET to localhost */
	inet_sock =
		(struct sockaddr_in *)ap_pcalloc( p, sizeof (struct sockaddr_in));
	inet_sock->sin_family = AF_INET;
	inet_aton( IC_DEFAULT_ADDR, &inet_sock->sin_addr );
	inet_sock->sin_port   = htons( IC_DEFAULT_PORT );

	conf_rec->sockaddr  = (struct sockaddr *)inet_sock;
	conf_rec->size      = sizeof (struct sockaddr_in);
	conf_rec->family    = PF_INET;
	conf_rec->address   = IC_DEFAULT_ADDR ":" "IC_DEFAULT_PORT";

	return conf_rec;
}

static const char*
ic_server_cmd(cmd_parms *parms, void *mconfig, const char *arg)
{
	ic_conf_rec *conf_rec   = (ic_conf_rec *)mconfig;

	conf_rec->address		= ap_pstrdup( parms->pool, arg );
	if ( conf_rec->address == NULL )
		return "not enough memory";

	/* Verify type of the argument */
	if ( *arg == '/' ) {
		/* This is a UNIX socket specification */
		struct sockaddr_un *unix_sock;

		unix_sock	= (struct sockaddr_un *)
			ap_pcalloc( parms->pool, sizeof( struct sockaddr_un ) );
		if (unix_sock == NULL)
			return "not enough memory";

		unix_sock->sun_family = AF_LOCAL;
		ap_cpystrn( unix_sock->sun_path, conf_rec->address,
				 sizeof (unix_sock->sun_path));

		conf_rec->family   = PF_LOCAL;
		conf_rec->size     = SUN_LEN( unix_sock );
		conf_rec->sockaddr = (struct sockaddr *)unix_sock;
	} else {
		/* INET Socket

		   The argument is an IP address or hostname followed by
		   an optional port specification.
		 */
		struct sockaddr_in *inet_sock;
		char **hostaddress, *hostname;

		inet_sock	= (struct sockaddr_in *)
			ap_pcalloc( parms->pool, sizeof( struct sockaddr_in ) );
		if (inet_sock == NULL)
			return "not enough memory";
		inet_sock->sin_family = AF_INET;

		hostaddress = &(conf_rec->address);
		hostname    = ap_getword_nc( parms->temp_pool, hostaddress, ':');

		if ( ! inet_aton( hostname, &inet_sock->sin_addr ) )
		{
			/* Address must be a host */
			struct hostent * host;
			host = ap_pgethostbyname( parms->temp_pool, hostname );
			if ( ! host )
				return "invalid host specification";

			memcpy(&inet_sock->sin_addr, host->h_addr,
				   sizeof(inet_sock->sin_addr) );
		}

		/* Check if there is a port spec */
		if ( **hostaddress ) {
			int port = atoi( *hostaddress );

			if ( port < 1 || port > 65535 )
				return "invalid port specification";

			inet_sock->sin_port = htons( port );
		} else {
			inet_sock->sin_port = htons( IC_DEFAULT_PORT );
		}

		conf_rec->sockaddr = (struct sockaddr *)inet_sock;
		conf_rec->family   = PF_INET;
		conf_rec->size     = sizeof( struct sockaddr_in );
		conf_rec->sockaddr = (struct sockaddr *)inet_sock;
	}

	return NULL;
}

static BUFF *
ic_connect( request_rec *r, ic_conf_rec *conf_rec )
{
	int ic_sock;
	BUFF *ic_buff;

	/* Open connection to the server */
	ic_sock = ap_psocket( r->pool, conf_rec->family, SOCK_STREAM, 0 );
	if ( ic_sock < 0 ) {
		ap_log_reason( "socket", r->uri, r);
		return NULL;
	}

	/* Initialize a timeout */
	ap_hard_timeout( "ic_connect", r );
	if ( connect( ic_sock, conf_rec->sockaddr, conf_rec->size ) < 0 )
	{
		ap_log_reason( "Connection failed", r->uri, r );
		return NULL;
	}
	ap_kill_timeout( r );

	/* Create a BUFF struct of that socket */
	ic_buff = ap_bcreate( r->pool, B_RDWR | B_SOCKET );
	if ( !ic_buff) {
		ap_log_reason( "failed to create BUFF", r->uri, r );
		return NULL;
	}
	ap_bpushfd( ic_buff, ic_sock, ic_sock );

	return ic_buff;
}

static int
ic_send_request( request_rec *r, ic_conf_rec *conf_rec, BUFF *ic_buff )
{
	char **env, **e;
	int env_count, rc;

	/* Initialize a timeout */
	ap_hard_timeout( "ic_send_request", r );

	/* Send the arg param
	   This is always empty for a CGI request
	 */
	if ( ap_bputs( "arg 0\n", ic_buff ) < 0 ) {
		ap_log_reason( "error writing to Interchange", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout( r );

	/* Now on with the environment */

	/* Initialize Environment to send to Interchange */
	ap_add_common_vars( r );
	ap_add_cgi_vars( r );

	env = ap_create_environment( r->pool, r->subprocess_env );

	/* Send the count */
	for (e = env, env_count = 0;  *e != NULL;  ++e, ++env_count);
	if ( ap_bprintf( ic_buff, "env %d\n", env_count ) < 0 ) {
		ap_log_reason( "error writing to Interchange", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout( r );

	/* Now the vars */
	for ( e = env;  *e != NULL;  ++e) {
		if ( ap_bprintf(ic_buff, "%d %s\n", strlen(*e), *e ) < 0 ) {
			ap_log_reason( "error writing to Interchange", r->uri, r );
			return HTTP_INTERNAL_SERVER_ERROR;
		}
		ap_reset_timeout( r );
	}

	/* Send the request body if any */
	if ( r->method_number == M_POST ) {
		if ( (rc = ap_setup_client_block( r, REQUEST_CHUNKED_ERROR) ) != OK)
			return rc;

		if ( ap_should_client_block(r) ) {
			char buffer[HUGE_STRING_LEN];
			int  len_read;
			long length = r->remaining;

			if (ap_bprintf( ic_buff, "entity\n%ld ", length ) < 0 ) {
				ap_log_reason( "error writing to Interchange", r->uri, r );
				return HTTP_INTERNAL_SERVER_ERROR;
			}

			while ( (len_read =
					 ap_get_client_block(r, buffer, sizeof(buffer ))
					 ) > 0 )
			{
				ap_reset_timeout(r);

				/* Send that to Interchange */
				if ( ap_bwrite( ic_buff, buffer, len_read ) != len_read ) {
					ap_log_reason( "error writing to Interchange", r->uri, r );
					return HTTP_INTERNAL_SERVER_ERROR;
				}
				ap_reset_timeout(r);
			}
			if ( len_read < 0 ) {
				ap_log_reason( "error reading from client", r->uri, r );
				return HTTP_INTERNAL_SERVER_ERROR;
			}
			/* Send end of line */
			if ( ap_bputc( '\n', ic_buff ) < 0 ) {
				ap_log_reason( "error writing to Interchange", r->uri, r );
				return HTTP_INTERNAL_SERVER_ERROR;
			}
		}
	}

	/* We are done */
	if ( ap_bputs( "end\n", ic_buff ) < 0 ) {
		ap_log_reason( "error writing to Interchange", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout( r );
	if ( ap_bflush( ic_buff ) < 0 ) {
		ap_log_reason( "error writing to Interchange", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	ap_kill_timeout( r );

	return OK;
}

static int
ic_transfer_response( request_rec *r, ic_conf_rec *conf_rec,
					  BUFF *ic_buff )
{
	char error_buff[MAX_STRING_LEN];
	BUFF *client_buff;
	int rc;

	array_header *resp_buff_arr;
	int cur_reading_elt;
	int cur_writing_elt;

	/* For ap_select */
	fd_set readers,writers;
	int client_fd,ic_fd,maxfd;
	int reading,writing;

	ap_hard_timeout( "ic_transfer_response", r );

	/* Scan the request response for CGI headers */
	if ( ap_scan_script_header_err_buff( r, ic_buff, error_buff ) != OK )
	{
		ap_log_rerror( APLOG_MARK, APLOG_ERR|APLOG_NOERRNO, r,
					   "Error while scanning response headers: %s",
					   error_buff );

		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/* Send beggining of the response */
	ap_reset_timeout( r );
	ap_send_http_header( r );
	/* Make sure all headers are flushed */
	if ( ap_rflush( r ) < 0 ) {
		ap_log_reason( "error sending headers to client", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout(r);

	/* OK, now turn on non blocking IO */
	client_buff = r->connection->client;
	if ( (rc = ap_bnonblock( client_buff, B_WR ) ) != 0 )
	{
		ap_log_reason( "error turning non blocking I/O on client",
					   r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	if ( (rc = ap_bnonblock( ic_buff, B_RD ) ) != 0 )
	{
		ap_log_reason( "error turning non blocking I/O on Interchange",
					   r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_bsetflag( ic_buff, B_SAFEREAD, 1 );

	reading = 1, writing = 1;
	client_fd    = ap_bfileno( client_buff, B_WR );
	ic_fd		 = ap_bfileno( ic_buff, B_RD );
	maxfd       = client_fd > ic_fd ? client_fd : ic_fd;
	maxfd++;

	/* Allocate array for response */
	resp_buff_arr = ap_make_array(r->pool, 5, sizeof(ic_response_buffer ) );
	if ( !resp_buff_arr ) {
		ap_log_reason( "failed to allocate response buffer", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	/* Create the first element */
	if ( ap_push_array( resp_buff_arr ) == NULL ) {
		ap_log_reason( "failed to allocate first element", r->uri, r );
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	cur_reading_elt = 0, cur_writing_elt = 0;

	while (1) {
		int i;

		FD_ZERO(&readers);
		FD_ZERO(&writers);

		if ( !reading && !writing) {
			break;
		}

		if ( reading )
			FD_SET( ic_fd, &readers );

		if ( writing )
			FD_SET(client_fd, &writers);

		if ( ( rc = ap_select( maxfd, &readers, &writers, NULL, NULL ) ) < 0 )
		{
			ap_log_reason( "error in ap_select", r->uri, r );
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		if ( reading && FD_ISSET( ic_fd, &readers ) )
		{
			int read_len,left;
			ic_response_buffer *resp_buff;
			char *buff;

			resp_buff = ((ic_response_buffer *)resp_buff_arr->elts);
			for ( i=0; i< cur_reading_elt; i++)
				resp_buff++;

			buff = resp_buff->buff;
			buff += resp_buff->buff_size;
			left = HUGE_STRING_LEN - resp_buff->buff_size;

			read_len = ap_bread( ic_buff, buff, left );
			if ( read_len < 0 ) {
				ap_log_reason( "error while reading Interchange response",
							   r->uri, r );
				return HTTP_INTERNAL_SERVER_ERROR;
			} else if ( read_len == 0 ) {
				reading = 0;
			} else {
				resp_buff->buff_size += read_len;
				writing = 1; /* Flag to indicate that there is now
								writing to do */

				if ( resp_buff->buff_size == HUGE_STRING_LEN ) {
					/* Create a new response buffer in the array */
					resp_buff =
						(ic_response_buffer *)ap_push_array(resp_buff_arr);
					if ( !resp_buff ) {
						ap_log_reason( "error while allocating "
									   "response buffer", r->uri, r );
						return HTTP_INTERNAL_SERVER_ERROR;
					}
					cur_reading_elt++;
				}
			}
		}
		if ( writing && FD_ISSET( client_fd, &writers ) )
		{
			int write_len,left;
			ic_response_buffer *resp_buff;
			char *buff;

			resp_buff = (ic_response_buffer *)resp_buff_arr->elts;
			for ( i=0; i< cur_writing_elt; i++)
				resp_buff++;

			buff = resp_buff->buff;
			buff += resp_buff->pos;
			left = resp_buff->buff_size - resp_buff->pos;
			if ( left > 0 ) {
				write_len = ap_bwrite( client_buff, buff, left );
				if ( write_len < 0 ) {
					ap_log_reason( "error while sending response",
								   r->uri, r );
					return HTTP_INTERNAL_SERVER_ERROR;
				}
				resp_buff->pos += write_len;

				if ( resp_buff->pos == resp_buff->buff_size ) {
					if ( ! reading && cur_writing_elt ==
						 cur_reading_elt )
					{
						/* Done */
						writing = 0;
					} else if ( resp_buff->pos == HUGE_STRING_LEN )
					{
						/* No remaining space in the buffer
						 */
						cur_writing_elt++;
					} else {
						/*
						  It seems that all that was read has been
						  sent, so wait for more data.
						 */
						writing = 0;
					}
				}
			} else {
				writing = 0;
			}
		}

		ap_reset_timeout(r);
	}

	/* Push everything to the client */
	if ( ap_bflush( client_buff ) < 0 ) {
		ap_log_reason( "error sending response to client", r->uri, r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	ap_kill_timeout(r);
	return OK;
}

static int
ic_handler( request_rec *r)
{
	ic_conf_rec *conf_rec;
	BUFF *ic_buff;
	int result;

	/* Grab our configuration */
	conf_rec = (ic_conf_rec *)ap_get_module_config( r->per_dir_config,
													&interchange_module );
	if ( ! conf_rec ) {
		ap_log_reason( "interchange-handler not configured properly",
					   r->uri, r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	ic_buff = ic_connect( r, conf_rec );
	if ( !ic_buff )
		return HTTP_INTERNAL_SERVER_ERROR;

	result = ic_send_request( r, conf_rec, ic_buff );
	if ( result != OK )
		return result;

	return ic_transfer_response( r, conf_rec, ic_buff );
}

/* Our configuration directives */
static command_rec ic_cmds[] =
{
    {
    "InterchangeServer",			/* directive name */
    ic_server_cmd,					/* config action routine */
    NULL,							/* argument to include in call */
    ACCESS_CONF,					/* where available */
    TAKE1,							/* arguments */
    "address of Interchange server"	/* directive description */
    },
	{NULL}
};

/* Make the name of the content handler known to Apache */
static handler_rec ic_handlers[] = {
    {"interchange-handler", ic_handler},
    {NULL}
};

/* Tell Apache what phases of the transaction we handle */
module MODULE_VAR_EXPORT interchange_module =
{
		STANDARD_MODULE_STUFF,
		NULL,					/* module initializer                 */
		ic_create_dir_config,	/* per-directory config creator       */
		NULL,					/* dir config merger                  */
		NULL,					/* server config creator              */
		NULL,					/* server config merger               */
		ic_cmds,				/* command table                      */
		ic_handlers,			/* [7]  content handlers              */
		NULL,					/* [2]  URI-to-filename translation   */
		NULL,					/* [5]  check/validate user_id        */
		NULL,					/* [6]  check user_id is valid *here* */
		NULL,					/* [4]  check access by host address  */
		NULL,					/* [7]  MIME type checker/setter      */
		NULL,					/* [8]  fixups                        */
		NULL,					/* [9]  logger                        */
		NULL,					/* [3]  header parser                 */
		NULL,					/* process initialization             */
		NULL,					/* process exit/cleanup               */
		NULL					/* [1]  post read_request handling    */
};
