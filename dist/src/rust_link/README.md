# Interchange CGI link program

This CGI program passes a request sent to a web server through a UNIX or INET (TCP) socket to an Interchange daemon. It can replace the customary vlink and tlink programs written in C.

It has been tested on Linux (x86_64) and macOS (ARM64).

See [interchangecommerce.org](https://www.interchangecommerce.org/) for more information about Interchange.

## Test

There are some unit and integration tests you can run:

```sh
cargo test
```

## Build

```sh
cargo build --release
```

## Install

```sh
cp -p target/release/rust_link /path/to/your/cgi-bin/
strip /path/to/your/cgi-bin/rust_link
```

You may need to make this program’s generated executable file setuid to the user your Interchange daemon runs as, for example for the `interch` user:

```sh
chown interch: /path/to/your/rust_link
chmod u+s /path/to/your/rust_link
```

## Configure

There is no default socket address compiled into the executable, so configuration must be passed in environment variables by whatever invokes the CGI program. These examples show how when using the Apache httpd web server.

### UNIX socket

```plain
SetEnv MINIVEND_SOCKET /path/to/your/interchange/etc/socket
```

### INET socket

To instead use an INET (TCP) socket:

```plain
SetEnv MINIVEND_HOST 127.0.0.1
```

If your Interchange server uses a TCP port other than the standard 7786, then also set, for example:

```plain
SetEnv MINIVEND_PORT 7787
```

## Activate!

Reload the Apache httpd configuration to pick up your changes. Depending on your operating system that will likely be one of:

```sh
systemctl reload httpd    # Red Hat family
systemctl reload apache2  # Debian family
```
