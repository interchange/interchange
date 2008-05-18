#define	MODULE_VERSION	"mod_interchange/1.33"
/*
 *	$Id: mod_interchange.c,v 2.11 2007-03-30 11:39:43 pajamian Exp $
 *
 *	Apache Module implementation of the Interchange application server's
 *	link programs.
 *
 *	----------------------------------------------------------------------
 *
 *	Author: Kevin Walsh <kevin@cursor.biz>
 *	Based on original code by Francis J. Lacoste <francis.lacoste@iNsu.COM>
 *
 *	Copyright (c) 2000-2005 Cursor Software Limited.
 *	Copyright (c) 1999 Francis J. Lacoste, iNsu Innovations.
 *	All rights reserved.
 *
 *	----------------------------------------------------------------------
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 *	02110-1301 USA.
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

#ifdef	OSX
typedef long socklen_t;
#endif

#ifndef	AF_LOCAL
#define	AF_LOCAL	AF_UNIX
#endif

#ifndef	PF_LOCAL
#define	PF_LOCAL	PF_UNIX
#endif

#ifndef	SUN_LEN
#define	SUN_LEN(su)	(sizeof(*(su)) - sizeof((su)->sun_path) + strlen((su)->sun_path))
#endif

#define	IC_DEFAULT_PORT			7786
#define	IC_DEFAULT_ADDR			"127.0.0.1"
#define	IC_DEFAULT_TIMEOUT		10
#define	IC_DEFAULT_CONNECT_TRIES	10
#define	IC_DEFAULT_CONNECT_RETRY_DELAY	2

#define	IC_MAX_DROPLIST			10
#define	IC_MAX_ORDINARYLIST		10
#define	IC_MAX_LIST_ENTRYSIZE		40
#define	IC_MAX_SERVERS			2
#define	IC_CONFIG_STRING_LEN		100

module MODULE_VAR_EXPORT interchange_module;

typedef struct ic_socket_struct{
	struct sockaddr *sockaddr; /* socket to the Interchange server */
	int family;		/* the socket family in use */
	socklen_t size;		/* the size of the socket structure */
	char *address;		/* human-readable form of the address */
}ic_socket_rec;

typedef struct ic_conf_struct{
	ic_socket_rec *server[IC_MAX_SERVERS];	/* connection to IC server(s) */
	int connect_tries;	/* number of times to ret to connect to IC */
	int connect_retry_delay;/* delay this many seconds between retries */
	int droplist_no;	/* number of entries in the "drop list" */
	int ordinarylist_no;	/* number of entries in the "ordinary file list" */
	int location_len;	/* length of the configured <Location> path */
	char location[IC_CONFIG_STRING_LEN+1];	/* configured <Location> path */
	char script_name[IC_CONFIG_STRING_LEN+1];
	char droplist[IC_MAX_DROPLIST][IC_MAX_LIST_ENTRYSIZE+1];
	char ordinarylist[IC_MAX_ORDINARYLIST][IC_MAX_LIST_ENTRYSIZE+1];
}ic_conf_rec;

typedef struct ic_response_buffer_struct{
	int buff_size;
	int pos;
	char buff[MAX_STRING_LEN];
}ic_response_buffer;

static void ic_initialise(server_rec *,pool *);
static void *ic_create_dir_config(pool *,char *);
static const char *ic_server_cmd(cmd_parms *,void *,const char *);
static const char *ic_serverbackup_cmd(cmd_parms *,void *,const char *);
static const char *ic_server_setup(cmd_parms *,void *,int,const char *arg);
static const char *ic_connecttries_cmd(cmd_parms *,void *,const char *);
static const char *ic_connectretrydelay_cmd(cmd_parms *,void *,const char *);
static BUFF *ic_connect(request_rec *,ic_conf_rec *);
static int ic_select(int,int,int,int);
static int ic_send_request(request_rec *,ic_conf_rec *,BUFF *);
static int ic_transfer_response(request_rec *,BUFF *);
static int ic_handler(request_rec *);

/*
 *	ic_initialise()
 *	---------------
 *	Module initialisation.
 */
static void ic_initialise(server_rec *s,pool *p)
{
	ap_add_version_component(MODULE_VERSION);
}

/*
 *	ic_create_dir_config()
 *	----------------------
 *	This module's per-directory config creator.
 *	Sets up the default configuration for this location,
 *	which can be overridden using the module's configuration
 *	directives
 */
static void *ic_create_dir_config(pool *p,char *dir)
{
	struct sockaddr_in *inet_sock;
	int tmp;

	ic_conf_rec *conf_rec = (ic_conf_rec *)ap_pcalloc(p,sizeof(ic_conf_rec));
	if (conf_rec == NULL)
		return NULL;

	/*
	 *	the default connection method is INET to localhost
	 */
	inet_sock = (struct sockaddr_in *)ap_pcalloc(p,sizeof(struct sockaddr_in));
	if (inet_sock == NULL)
		return NULL;

	inet_sock->sin_family = AF_INET;
	inet_aton(IC_DEFAULT_ADDR,&inet_sock->sin_addr);
	inet_sock->sin_port = htons(IC_DEFAULT_PORT);

	conf_rec->server[0] = (ic_socket_rec *)ap_pcalloc(p,sizeof(ic_socket_rec));
	if (conf_rec->server[0] == NULL)
		return NULL;

	conf_rec->server[0]->sockaddr = (struct sockaddr *)inet_sock;
	conf_rec->server[0]->size = sizeof (struct sockaddr_in);
	conf_rec->server[0]->family = PF_INET;
	conf_rec->server[0]->address = IC_DEFAULT_ADDR;

	for (tmp = 1; tmp < IC_MAX_SERVERS; tmp++)
		conf_rec->server[tmp] = (ic_socket_rec *)NULL;

	if (dir){
		/*
		 *	remove leading '/' characters
		 */
		while (*dir == '/')
			dir++;

		/*
		 *	copy the configured <Location> path into place
		 */
		strncpy(conf_rec->location,dir,IC_CONFIG_STRING_LEN);
		conf_rec->location[IC_CONFIG_STRING_LEN] = '\0';
		conf_rec->location_len = strlen(conf_rec->location);

		/*
		 *	remove trailing '/' characters
		 */
		while (conf_rec->location_len > 1 && conf_rec->location[conf_rec->location_len] == '/'){
			conf_rec->location[conf_rec->location_len--] = '\0';
		}
	}else{
		conf_rec->location[0] = '\0';
		conf_rec->location_len = 0;
	}
	conf_rec->connect_tries = IC_DEFAULT_CONNECT_TRIES;
	conf_rec->connect_retry_delay = IC_DEFAULT_CONNECT_RETRY_DELAY;
	conf_rec->droplist_no = 0;
	conf_rec->ordinarylist_no = 0;
	conf_rec->script_name[0] = '\0';
	return conf_rec;
}

/*
 *	ic_server_cmd()
 *	---------------
 *	Handle the "InterchangeServer" module configuration directive
 */
static const char *ic_server_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	return ic_server_setup(parms,mconfig,0,arg);
}

/*
 *	ic_serverbackup_cmd()
 *	---------------------
 *	Handle the "InterchangeServerBackup" module configuration directive
 */
static const char *ic_serverbackup_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	conf_rec->server[1] = (ic_socket_rec *)ap_pcalloc(parms->pool,sizeof(ic_socket_rec));
	if (conf_rec->server[1] == NULL)
		return "not enough memory for backup socket record";

	return ic_server_setup(parms,mconfig,1,arg);
}

/*
 *	ic_server_setup()
 *	-----------------
 *	Do the actual primary/backup server setup on behalf of the
 *	ic_server_cmd() and ic_serverbackup_cmd() functions.
 */
static const char *ic_server_setup(cmd_parms *parms,void *mconfig,int server,const char *arg)
{
	static char errmsg[100];

	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;
	ic_socket_rec *sock_rec = conf_rec->server[server];

	sock_rec->address = ap_pstrdup(parms->pool,arg);
	if (sock_rec->address == NULL)
		return "not enough memory for the socket address";

	/*
	 *	verify type of the argument, which will indicate
	 *	whether we should be using a UNIX or Inet socket
	 *	to connect to the Interchange server
	 */
	if (*arg == '/'){
		/*
		 *	this is to be a UNIX socket
		 */
		struct sockaddr_un *unix_sock;

		unix_sock = (struct sockaddr_un *)ap_pcalloc(parms->pool,sizeof(struct sockaddr_un));
		if (unix_sock == NULL){
			sprintf(errmsg,"not enough memory for %s UNIX socket structure",server ? "primary" : "backup");
			return errmsg;
		}

		unix_sock->sun_family = AF_LOCAL;
		ap_cpystrn(unix_sock->sun_path,sock_rec->address,sizeof(unix_sock->sun_path));
		sock_rec->sockaddr = (struct sockaddr *)unix_sock;
		sock_rec->size = SUN_LEN(unix_sock);
		sock_rec->family = PF_LOCAL;
	}else{
		/*
		 *	this is to be an INET socket
		 *
		 *	the argument is an IP address or hostname followed by
		 *	an optional port specification
		 */
		struct sockaddr_in *inet_sock;
		char **hostaddress;
		char *hostname;

		inet_sock = (struct sockaddr_in *)ap_pcalloc(parms->pool,sizeof(struct sockaddr_in));
		if (inet_sock == NULL){
			sprintf(errmsg,"not enough memory for %s INET socket structure",server ? "primary" : "backup");
			return errmsg;
		}

		inet_sock->sin_family = AF_INET;
		hostaddress = &(sock_rec->address);
		hostname = ap_getword_nc(parms->temp_pool,hostaddress,':');

		if (!inet_aton(hostname,&inet_sock->sin_addr)){
			/*
			 *	address must point to a hostname
			 */
			struct hostent *host = ap_pgethostbyname(parms->temp_pool,hostname);
			if (!host)
				return "invalid hostname specification";

			memcpy(&inet_sock->sin_addr,host->h_addr,sizeof(inet_sock->sin_addr));
		}

		/*
		 *	check if a port number has been specified
		 */
		if (**hostaddress){
			int port = atoi(*hostaddress);

			if (port <= 100 || port > 65535)
				return "invalid port specification";

			inet_sock->sin_port = htons(port);
		}else{
			inet_sock->sin_port = htons(IC_DEFAULT_PORT);
		}

		sock_rec->sockaddr = (struct sockaddr *)inet_sock;
		sock_rec->family = PF_INET;
		sock_rec->size = sizeof(struct sockaddr_in);
	}
	return NULL;
}

/*
 *	ic_connecttries_cmd()
 *	---------------------
 *	Handle the "ConnectTries" module configuration directive
 */
static const char *ic_connecttries_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	conf_rec->connect_tries = atoi(arg);
	return NULL;
}

/*
 *	ic_connectretrydelay_cmd()
 *	--------------------------
 *	Handle the "ConnectRetries" module configuration directive
 */
static const char *ic_connectretrydelay_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	conf_rec->connect_retry_delay = atoi(arg);
	return NULL;
}

/*
 *	ic_droprequestlist_cmd()
 *	------------------------
 *	Handle the "DropRequestList" module configuration directive
 */
static const char *ic_droprequestlist_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	if (conf_rec->droplist_no < IC_MAX_DROPLIST){
		strncpy(conf_rec->droplist[conf_rec->droplist_no],arg,IC_MAX_LIST_ENTRYSIZE);
		conf_rec->droplist[conf_rec->droplist_no++][IC_MAX_LIST_ENTRYSIZE] = '\0';
	}
	return NULL;
}

/*
 *	ic_ordinaryfilelist_cmd()
 *	-------------------------
 *	Handle the "OrdinaryFileList" module configuration directive
 */
static const char *ic_ordinaryfilelist_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	if (conf_rec->ordinarylist_no < IC_MAX_ORDINARYLIST){
		strncpy(conf_rec->ordinarylist[conf_rec->ordinarylist_no],arg,IC_MAX_LIST_ENTRYSIZE);
		conf_rec->ordinarylist[conf_rec->ordinarylist_no++][IC_MAX_LIST_ENTRYSIZE] = '\0';
	}
	return NULL;
}

/*
 *	ic_interchangescript_cmd()
 *	--------------------------
 *	Handle the "InterchangeScript" module configuration directive
 */
static const char *ic_interchangescript_cmd(cmd_parms *parms,void *mconfig,const char *arg)
{
	ic_conf_rec *conf_rec = (ic_conf_rec *)mconfig;

	strncpy(conf_rec->script_name,arg,IC_CONFIG_STRING_LEN);
	conf_rec->script_name[IC_CONFIG_STRING_LEN] = '\0';
	return NULL;
}

/*
 *	ic_connect()
 *	------------
 *	Connect to the Interchange server
 */
static BUFF *ic_connect(request_rec *r,ic_conf_rec *conf_rec)
{
	BUFF *ic_buff;
	ic_socket_rec *sock_rec;
	int ic_sock,retry,srv;
	int connected = 0;

	/*
	 *	connect the new socket to the Interchange server
	 *
	 *	if the connection to the Interchange server fails then
	 *	retry IC_DEFAULT_CONNECT_TRIES times, sleeping for
	 *	IC_DEFAULT_CONNECT_RETRY_DELAY seconds between each retry
	 */
	for (retry = 0; retry != conf_rec->connect_tries; retry++){
		for (srv = 0; srv != IC_MAX_SERVERS; srv++){
			if ((sock_rec = conf_rec->server[srv]) == NULL)
				break;
			if (srv){
				ap_log_rerror(APLOG_MARK,APLOG_ERR|APLOG_NOERRNO,r,"Attempting to connect to backup server %d",srv);
			}

			/*
			 *	attempt to connect to the Interchange server
			 */
			ic_sock = ap_psocket(r->pool,sock_rec->family,SOCK_STREAM,0);
			if (ic_sock < 0){
				ap_log_reason("socket",r->uri,r);
				return NULL;
			}
			ap_hard_timeout("ic_connect",r);
			if (connect(ic_sock,sock_rec->sockaddr,sock_rec->size) >= 0){
				connected++;
				break;
			}
			ap_kill_timeout(r);
			ap_pclosesocket(r->pool,ic_sock);
		}
		if (connected)
			break;
		sleep(conf_rec->connect_retry_delay);
	}
	ap_kill_timeout(r);
	if (retry == conf_rec->connect_tries){
		ap_log_reason("Connection failed",r->uri,r);
		return NULL;
	}

	/*
	 *	create an Apache BUFF structure for our new connection
	 */
	ic_buff = ap_bcreate(r->pool,B_RDWR|B_SOCKET);
	if (!ic_buff){
		ap_log_reason("failed to create BUFF",r->uri,r);
		return NULL;
	}
	ap_bpushfd(ic_buff,ic_sock,ic_sock);
	return ic_buff;
}

/*
 *	ic_select()
 *	-----------
 *	Convenient wrapper for select().
 *	Wait for data to become available on the socket, or
 *	for an error to occur, and return the appropriate status
 *	code to the calling function.
 */
static int ic_select(int sock_rd,int sock_wr,int secs,int usecs)
{
	fd_set sock_set_rd,sock_set_wr;
	fd_set *rd = NULL,*wr = NULL;
	struct timeval tv;
	int rc;

	do{
		if (sock_rd > 0){
			FD_ZERO(&sock_set_rd);
			FD_SET(sock_rd,&sock_set_rd);
			rd = &sock_set_rd;
		}
		if (sock_wr > 0){
			FD_ZERO(&sock_set_wr);
			FD_SET(sock_wr,&sock_set_wr);
			wr = &sock_set_wr;
		}

		tv.tv_sec = secs;
		tv.tv_usec = usecs;
		rc = ap_select(((sock_rd > sock_wr) ? sock_rd : sock_wr) + 1,rd,wr,NULL,&tv);
	}while (rc == 0);
	return rc;
}

/*
 *	ic_send_request()
 *	-----------------
 *	Send the client's page/form request to the Interchange server
 */
static int ic_send_request(request_rec *r,ic_conf_rec *conf_rec,BUFF *ic_buff)
{
	char **env,**e,*rp;
	int env_count,rc;
	char request_uri[MAX_STRING_LEN];
	char redirect_url[MAX_STRING_LEN];

	/*
	 *	send the Interchange-link arg parameter
	 *	(this is always empty for a CGI request)
	 */
	ap_hard_timeout("ic_send_request",r);
	if (ap_bputs("arg 0\n",ic_buff) < 0){
		ap_log_reason("error writing to Interchange",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout(r);

	/*
	 *	initialize the environment to send to Interchange
	 */
	ap_add_common_vars(r);
	ap_add_cgi_vars(r);
	env = ap_create_environment(r->pool,r->subprocess_env);

	/*
	 *	count the number of environment variables present
	 */
	for (e = env,env_count = 0; *e != NULL; e++,env_count++){
		if (strncmp(*e,"PATH_INFO=",10) == 0)
			env_count--;
	}
	env_count++;

	/*
	 *	send the environment variable count to Interchange
	 */
	if (ap_bprintf(ic_buff,"env %d\n",env_count) < 0){
		ap_log_reason("error writing to Interchange",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	ap_reset_timeout(r);

	/*
	 *	ignore the PATH_INFO variable and fix the SCRIPT_NAME,
	 *	REQUEST_URI and REDIRECT_URL variable content
	 */
	request_uri[0] = '\0';
	redirect_url[0] = '\0';
	for (e = env; *e != NULL; e++){
		int len;
		char tmp[MAX_STRING_LEN];
		char *p = *e;

		if (strncmp(p,"PATH_INFO=",10) == 0)
			continue;
		if (strncmp(p,"REDIRECT_URL=",13) == 0){
			strncpy(redirect_url,p + 13,MAX_STRING_LEN - 14);
			continue;
		}
		if (strncmp(p,"REQUEST_URI=",12) == 0)
			strncpy(request_uri,p + 12,MAX_STRING_LEN - 13);
		else if (strncmp(p,"SCRIPT_NAME=",12) == 0){
			p = tmp;
			strcpy(p,"SCRIPT_NAME=");

			if (conf_rec->script_name[0])
				strcat(p,conf_rec->script_name);
			else{
				strcat(p,"/");
				strcat(p,conf_rec->location);
			}
		}
		len = strlen(p);
		if (len && ap_bprintf(ic_buff,"%d %s\n",len,p) < 0){
			ap_log_reason("error writing to Interchange",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}
	}

	rp = request_uri;

	while (*rp == '/')
		rp++;

	/*
	 *	strip the location path from the request_uri string
	 *	unless the location is "/"
	 */
	if (conf_rec->location[0] != '\0'){
		if (strncmp(rp,conf_rec->location,conf_rec->location_len) == 0)
			rp += conf_rec->location_len;
	}else{
		if (rp != request_uri)
			rp--;
	}

	strncpy(request_uri,rp,MAX_STRING_LEN - 1);
	request_uri[MAX_STRING_LEN - 1] = '\0';

	for (rp = request_uri; *rp != '\0'; rp++){
		if (*rp == '?'){
			*rp = '\0';
			break;
		}
	}
	switch (ap_unescape_url(request_uri)){
	case BAD_REQUEST:
	case NOT_FOUND:
		ap_log_reason("Bad URI entities found",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/*
	 *	send the PATH_INFO variable as our "fixed" REQUEST_URI
	 */
	if (ap_bprintf(ic_buff,"%d PATH_INFO=%s\n",strlen(request_uri) + 10,request_uri) < 0){
		ap_log_reason("error writing to Interchange",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/*
	 *	check if we have a REDIRECT_URL
	 *	if so then give it the same "fixes" as PATH_INFO (REQUEST_URI)
	 */
	if (redirect_url[0] != '\0'){
		rp = redirect_url;

		while (*rp == '/')
			rp++;

		/*
		 *	strip the location path from the request_uri string
		 *	unless the location is "/"
		 */
		if (conf_rec->location[0] != '\0'){
			if (strncmp(rp,conf_rec->location,conf_rec->location_len) == 0)
				rp += conf_rec->location_len;
		}else{
			if (rp != redirect_url)
				rp--;
		}

		strncpy(redirect_url,rp,MAX_STRING_LEN - 1);
		redirect_url[MAX_STRING_LEN - 1] = '\0';

		for (rp = redirect_url; *rp != '\0'; rp++){
			if (*rp == '?'){
				*rp = '\0';
				break;
			}
		}
		switch (ap_unescape_url(redirect_url)){
		case BAD_REQUEST:
		case NOT_FOUND:
			ap_log_reason("Bad URI entities found",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		if (ap_bprintf(ic_buff,"%d REDIRECT_URL=%s\n",strlen(redirect_url) + 13,redirect_url) < 0){
			ap_log_reason("error writing to Interchange",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}
	}
	ap_reset_timeout(r);

	/*
	 *	send the request body, if any
	 */
	if (ap_should_client_block(r)){
		char buffer[MAX_STRING_LEN];
		int len_read;
		long length = r->remaining;

		if (ap_bprintf(ic_buff,"entity\n%ld ",length) < 0){
			ap_log_reason("error writing to Interchange",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		/*
		 *	read a block of data from the client and send
		 *	it to the Interchange server, until there
		 *	is nothing more to read from the client
		 */
		while ((len_read = ap_get_client_block(r,buffer,sizeof(buffer))) > 0){
			ap_reset_timeout(r);

			if (ap_bwrite(ic_buff,buffer,len_read) != len_read){
				ap_log_reason("error writing client block to Interchange",r->uri,r);
				return HTTP_INTERNAL_SERVER_ERROR;
			}
			ap_reset_timeout(r);
		}
		if (len_read < 0){
			ap_log_reason("error reading block from client",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		/*
		 *	send an end of line character to Interchange
		 */
		if (ap_bputc('\n',ic_buff) < 0){
			ap_log_reason("error writing to Interchange",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}
	}

	/*
	 *	all data has been sent, so send the "end" marker
	 */
	ap_reset_timeout(r);
	if (ap_bputs("end\n",ic_buff) < 0){
		ap_log_reason("error writing the end marker to Interchange",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}
	if (ap_bflush(ic_buff) < 0){
		ap_log_reason("error flushing data to Interchange",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	ap_kill_timeout(r);
	return OK;
}

/*
 *	ic_transfer_response()
 *	----------------------
 *	Read the response from the Interchange server
 *	and relay it to the client
 */
static int ic_transfer_response(request_rec *r,BUFF *ic_buff)
{
	const char *location;
	int rc,ic_sock;
	char sbuf[MAX_STRING_LEN],argsbuffer[MAX_STRING_LEN];

	/*
	 *	get the socket we are using to talk to the
	 *	Interchange server, and wait for Interchange to
	 *	send us some data
	 */
	ic_sock = ap_bfileno(ic_buff,B_RD);
	rc = ic_select(ic_sock,0,IC_DEFAULT_TIMEOUT,0);
	if (rc < 0){
		ap_log_reason("Failed to select the response header",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/*
	 *	check the HTTP header to make sure that it looks valid
	 */
	if ((rc = ap_scan_script_header_err_buff(r,ic_buff,sbuf)) != OK) {
		if (rc == HTTP_INTERNAL_SERVER_ERROR) {
			ap_log_rerror(APLOG_MARK,APLOG_ERR|APLOG_NOERRNO,r,"Malformed header return by Interchange: %s",sbuf);
		}
		return rc;
	}

	/*
	 *	check the header for an HTTP redirect request
	 */
	location = ap_table_get(r->headers_out,"Location");
	if (r->status == 200 && location){
		fd_set sock_set;

		/*
		 *	check if we need to do an external redirect
		 */
		if (*location != '/')
			return REDIRECT;

		/*
		 *	we are here because we need to do an internal redirect
		 *
		 *	soak up any data from the Interchange socket
		 */
		rc = ic_select(ic_sock,0,IC_DEFAULT_TIMEOUT,0);
		if (rc < 0){
			ap_log_reason("Failed to select the response text",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}

		/*
		 *	soak up any body-text sent by the Interchange server
		 */
		ap_soft_timeout("mod_interchange: Interchange read",r);
		while (ap_bgets(argsbuffer,MAX_STRING_LEN,ic_buff) > 0)
			;
		ap_kill_timeout(r);

		/*
		 *	always use the GET method for internal redirects
		 *	also, unset the Content-Length so that nothing
		 *	else tries to re-read the text we just soaked up
		 */
		r->method = ap_pstrdup(r->pool,"GET");
		r->method_number = M_GET;
		ap_table_unset(r->headers_in,"Content-Length");
		ap_internal_redirect(location,r);
		return OK;
	}

	/*
	 *	we were not redirected, so send the HTTP headers
	 *	to the client
	 */
	ap_hard_timeout("mod_interchange: Client write",r);
	ap_send_http_header(r);
	if (ap_rflush(r) < 0){
		ap_log_reason("error sending headers to client",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/*
	 *	if Interchange is sending body text (HTML), then
	 *	relay this to the client
	 */
	if (!r->header_only){
		ap_reset_timeout(r);
		if ((rc = ap_bnonblock(ic_buff,B_RD)) != 0){
			ap_log_reason("error turning non blocking I/O on Interchange socket",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}
		ap_bsetflag(ic_buff,B_SAFEREAD,1);
		if (ap_send_fb(ic_buff,r) <= 0){
			ap_log_reason("error sending response body to client",r->uri,r);
			return HTTP_INTERNAL_SERVER_ERROR;
		}
	}
	ap_kill_timeout(r);
	return OK;
}

/*
 *	ic_handler()
 *	------------
 *	module content handler
 */
static int ic_handler(request_rec *r)
{
	ic_conf_rec *conf_rec;
	BUFF *ic_buff;
	int i,rc;

	if (r->method_number == M_OPTIONS){
		r->allowed |= (1 << M_GET);
		r->allowed |= (1 << M_PUT);
		r->allowed |= (1 << M_POST);
		return DECLINED;
	}

	if ((rc = ap_setup_client_block(r,REQUEST_CHUNKED_ERROR)) != OK)
		return rc;

	/*
	 *	get our configuration
	 */
	conf_rec = (ic_conf_rec *)ap_get_module_config(r->per_dir_config,&interchange_module);
	if (!conf_rec){
		ap_log_reason("interchange-handler not configured properly",r->uri,r);
		return HTTP_INTERNAL_SERVER_ERROR;
	}

	/*
	 *	check if the requested URI matches strings in the
	 *	"ordinary file" list.  This module will not handle
	 *	the request if a match is found, and will leave it
	 *	up to Apache to work out what to do with the request
	 */
	for (i = 0; i < conf_rec->ordinarylist_no; i++){
		if (strncmp(r->uri,conf_rec->ordinarylist[i],strlen(conf_rec->ordinarylist[i])) == 0){
			return DECLINED;
		}
	}

	/*
	 *	check if the requested URI matches an entry in the drop list.
	 *	If so then return a 404 (not found) status.  Note that a
	 *	substring match is used
	 */
	for (i = 0; i < conf_rec->droplist_no; i++){
		if (strstr(r->uri,conf_rec->droplist[i])){
			ap_log_reason("interchange-handler match found in the drop list",r->uri,r);
			ap_log_rerror(APLOG_MARK,APLOG_ERR|APLOG_NOERRNO,r,"Requested URI (%s) matches drop list entry (%s)",r->uri,conf_rec->droplist[i]);
			return HTTP_NOT_FOUND;
		}
	}

	/*
	 *	connect to the Interchange server
	 */
	ic_buff = ic_connect(r,conf_rec);
	if (!ic_buff)
		return HTTP_INTERNAL_SERVER_ERROR;

	/*
	 *	send the client's request to Interchange
	 */
	rc = ic_send_request(r,conf_rec,ic_buff);

	/*
	 *	receive the response from the Interchange server
	 *	and relay that response to the client
	 */
	if (rc == OK)
		rc = ic_transfer_response(r,ic_buff);

	/*
	 *	close the Interchange socket and return
	 */
	ap_bclose(ic_buff);
	return rc;
}

/*
 *	the module's configuration directives
 */
static command_rec ic_cmds[] = {
	{
		"InterchangeServer",	/* directive name */
		ic_server_cmd,		/* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		TAKE1,			/* arguments */
		"Address of the primary Interchange server"
	},
	{
		"InterchangeServerBackup",	/* directive name */
		ic_serverbackup_cmd,		/* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		TAKE1,			/* arguments */
		"Address of the backup Interchange server"
	},
	{
		"ConnectTries",		/* directive name */
		ic_connecttries_cmd,	/* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		TAKE1,			/* arguments */
		"The number of connection attempts to make before giving up"
	},
	{
		"ConnectRetryDelay",	/* directive name */
		ic_connectretrydelay_cmd, /* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		TAKE1,			/* arguments */
		"The number of connection attempts to make before giving up"
	},
	{
		"DropRequestList",	/* directive name */
		ic_droprequestlist_cmd,	/* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		ITERATE,		/* arguments */
		"Drop the request if the URI path contains one of the specified values"
	},
	{
		"OrdinaryFileList",	/* directive name */
		ic_ordinaryfilelist_cmd,/* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		ITERATE,		/* arguments */
		"Don't pass to Interchange if the URI path starts with one of the specified values"
	},
	{
		"InterchangeScript",	/* directive name */
		ic_interchangescript_cmd, /* config action routine */
		NULL,			/* argument to include in call */
		ACCESS_CONF,		/* where available */
		TAKE1,			/* arguments */
		"Replace the 'script name' with this value before calling Interchange"
	},
	{NULL}
};

/*
 *	make the name of the content handler known to Apache
 */
static handler_rec ic_handlers[] = {
	{"interchange-handler",ic_handler},
	{NULL}
};

/*
 *	tell Apache what phases of the transaction we handle
 */
module MODULE_VAR_EXPORT interchange_module = {
	STANDARD_MODULE_STUFF,
	ic_initialise,		/* module initialiser                 */
	ic_create_dir_config,	/* per-directory config creator       */
	NULL,			/* dir config merger                  */
	NULL,			/* server config creator              */
	NULL,			/* server config merger               */
	ic_cmds,		/* command table                      */
	ic_handlers,		/* [7]  content handlers              */
	NULL,			/* [2]  URI-to-filename translation   */
	NULL,			/* [5]  check/validate user_id        */
	NULL,			/* [6]  check user_id is valid *here* */
	NULL,			/* [4]  check access by host address  */
	NULL,			/* [7]  MIME type checker/setter      */
	NULL,			/* [8]  fixups                        */
	NULL,			/* [9]  logger                        */
	NULL,			/* [3]  header parser                 */
	NULL,			/* process initialization             */
	NULL,			/* process exit/cleanup               */
	NULL			/* [1]  post read_request handling    */
};

/*
 *	vim:ts=8:sw=8
 */
