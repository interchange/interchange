#![forbid(unsafe_code)]
//
//! # Interchange CGI link program rust_link
//!
//! This [CGI program](https://en.wikipedia.org/wiki/Common_Gateway_Interface)
//! passes a request sent to a web server through a UNIX or INET (TCP) socket
//! to an [Interchange](https://www.interchangecommerce.org/) daemon.
//! It is based on, and can replace, the customary vlink.c and tlink.c programs.
//!
//! See the associated README.md for usage documentation.
//
// Copyright © 2021–2023 Jon Jensen <jon@endpointdev.com>
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but without any warranty; without even the implied warranty of
// merchantability or fitness for a particular purpose. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this program; if not, visit:
// https://www.gnu.org/licenses/old-licenses/gpl-2.0.html

use bytes::{BufMut, Bytes, BytesMut};
use const_format::concatcp;
use multisock::Stream;
use std::env;
use std::include_str;
use std::io::prelude::*;
use std::io::{self, Write};
use std::net::ToSocketAddrs;
use std::os::unix::ffi::OsStringExt;
use std::thread::sleep;
use std::time::Duration;

/// Name of environment variable "MINIVEND_SOCKET" containing UNIX socket address.
const ENV_KEY_SOCKET: &str = "MINIVEND_SOCKET";
/// Name of environment variable "MINIVEND_HOST" containing INET socket host name or IP address.
const ENV_KEY_HOST: &str = "MINIVEND_HOST";
/// Name of environment variable "MINIVEND_PORT" containing INET socket TCP port number.
const ENV_KEY_PORT: &str = "MINIVEND_PORT";
/// Name of environment variable "CONTENT_LENGTH" containing length in bytes of HTTP response body in ASCII text form.
const ENV_KEY_CONTENT_LENGTH: &str = "CONTENT_LENGTH";

#[cfg(test)]
mod tests {
    use super::*;
    use multisock::Listener;
    use regex::bytes::Regex;
    use serial_test::serial;
    use std::fs;
    use std::str::FromStr;
    use std::thread;

    #[test]
    fn number_to_text_bytes_0() {
        assert_eq!(Bytes::from_static(b"0"), number_to_text_bytes(0));
    }

    #[test]
    fn number_to_text_bytes_1() {
        assert_eq!(Bytes::from_static(b"1"), number_to_text_bytes(1));
    }

    #[test]
    fn number_to_text_bytes_259() {
        assert_eq!(Bytes::from_static(b"259"), number_to_text_bytes(259));
    }

    // Tests using environment variables must be run serially because
    // environment variables are process-wide, not thread-safe.

    #[test]
    #[should_panic]
    #[serial]
    fn get_socket_addr_from_env_missing_vars() {
        for k in [ENV_KEY_SOCKET, ENV_KEY_HOST, ENV_KEY_PORT].iter() {
            env::remove_var(k);
        }
        get_socket_addr_from_env();
    }

    // IPv6 sockets are currently not supported by Interchange itself.
    #[test]
    #[should_panic]
    #[serial]
    fn get_socket_addr_from_env_host_ipv6() {
        env::remove_var(ENV_KEY_SOCKET);
        env::remove_var(ENV_KEY_PORT);
        env::set_var(ENV_KEY_HOST, "::1");
        assert_eq!(
            multisock::SocketAddr::from_str("[::1]:7786").unwrap(),
            get_socket_addr_from_env()
        );
    }

    #[test]
    #[serial]
    fn get_socket_addr_from_env_host_ipv4() {
        env::remove_var(ENV_KEY_SOCKET);
        env::remove_var(ENV_KEY_PORT);
        env::set_var(ENV_KEY_HOST, "127.0.0.1");
        assert_eq!(
            multisock::SocketAddr::from_str("127.0.0.1:7786").unwrap(),
            get_socket_addr_from_env()
        );
    }

    #[test]
    #[serial]
    fn get_socket_addr_from_env_host_ipv4_alt_port() {
        env::remove_var(ENV_KEY_SOCKET);
        env::set_var(ENV_KEY_HOST, "127.0.0.1");
        env::set_var(ENV_KEY_PORT, "30000");
        assert_eq!(
            multisock::SocketAddr::from_str("127.0.0.1:30000").unwrap(),
            get_socket_addr_from_env()
        );
    }

    #[test]
    #[serial]
    #[should_panic]
    fn get_socket_addr_from_env_host_ipv4_bad_host() {
        env::remove_var(ENV_KEY_SOCKET);
        env::remove_var(ENV_KEY_PORT);
        env::set_var(ENV_KEY_HOST, "abc");
        get_socket_addr_from_env();
    }

    #[test]
    #[serial]
    #[should_panic]
    fn get_socket_addr_from_env_host_ipv4_bad_port() {
        env::remove_var(ENV_KEY_SOCKET);
        env::set_var(ENV_KEY_HOST, "127.0.0.1");
        env::set_var(ENV_KEY_PORT, "xyz");
        get_socket_addr_from_env();
    }

    #[test]
    #[serial]
    fn get_socket_addr_from_env_host_name() {
        env::remove_var(ENV_KEY_SOCKET);
        env::remove_var(ENV_KEY_PORT);
        // This depends on the system running the tests having the usual localhost
        // set to 127.0.0.1 and tolerates (by ignoring) extras like ::1.
        env::set_var(ENV_KEY_HOST, "localhost");
        assert_eq!(
            multisock::SocketAddr::from_str("127.0.0.1:7786").unwrap(),
            get_socket_addr_from_env()
        );
    }

    // It would be nice to also test for an invalid UNIX socket, but any pathname
    // is valid for creating, and failure only happens when you try to use it.

    #[test]
    #[serial]
    fn get_socket_addr_from_env_unix() {
        env::remove_var(ENV_KEY_HOST);
        env::remove_var(ENV_KEY_PORT);
        env::set_var(ENV_KEY_SOCKET, "/dev/null");
        get_socket_addr_from_env();
    }

    #[test]
    #[serial]
    fn get_entity_content_length_missing() {
        env::remove_var(ENV_KEY_CONTENT_LENGTH);
        assert!(get_entity().is_empty());
    }

    #[test]
    #[serial]
    fn get_entity_content_length_empty() {
        env::set_var(ENV_KEY_CONTENT_LENGTH, "");
        assert!(get_entity().is_empty());
    }

    #[test]
    #[serial]
    fn get_entity_content_length_zero() {
        env::set_var(ENV_KEY_CONTENT_LENGTH, "0");
        assert!(get_entity().is_empty());
    }

    #[test]
    #[serial]
    #[should_panic]
    fn get_entity_content_length_bad() {
        env::set_var(ENV_KEY_CONTENT_LENGTH, "efg");
        get_entity();
    }

    // TODO: test get_entity() with mock stdin correct length

    // TODO: test get_entity() with mock stdin incorrect length

    const TEST_SOCKET_FILE: &str = "rust_link_test_socket";
    const TEST_SOCKET_ADDR: &str = concatcp!("unix:", TEST_SOCKET_FILE);

    fn send_arguments_output_listener() -> std::io::Result<()> {
        let listener = Listener::bind_reuse(&TEST_SOCKET_ADDR.parse().unwrap(), None)?;

        match listener.accept() {
            Ok((mut stream, _)) => {
                thread::spawn(move || send_arguments(&mut stream));
            }
            Err(_) => (),
        }

        fs::remove_file(TEST_SOCKET_FILE)?;
        Ok(())
    }

    #[test]
    #[serial]
    fn send_arguments_output() {
        thread::spawn(move || send_arguments_output_listener());
        // TODO: use a mutex instead of this timing hack
        sleep(Duration::from_millis(500));
        let socket_addr = TEST_SOCKET_ADDR.parse().unwrap();
        let mut response = Vec::<u8>::new();
        if let Ok(mut stream) = Stream::connect(&socket_addr) {
            stream
                .read_to_end(&mut response)
                .expect("Error reading stream");
        }

        const ARG_COUNT_PREFIX: &[u8] = b"arg 1\n";

        assert!(response.starts_with(ARG_COUNT_PREFIX));
        let line = response.strip_prefix(ARG_COUNT_PREFIX).unwrap();

        // Expect a response line with length that matches the path, such as:
        // 93 /Users/user/repos/interchange/dist/src/rust_link/target/debug/deps/rust_link-b36163eb170bb7cb
        let re = Regex::new(r"^(?P<len>\d+) (?P<arg>.*?)\n").unwrap();
        let caps = re.captures(line).unwrap();
        assert_eq!(
            caps.name("len").unwrap().as_bytes(),
            number_to_text_bytes(caps.name("arg").unwrap().as_bytes().len())
        );
    }
}

/// Given an integer, returns the textual representation of that number as ASCII bytes.
fn number_to_text_bytes(num: usize) -> Bytes {
    Bytes::from(num.to_string())
}

/// Reads configuration from environment variables and returns a UNIX or INET socket address.
fn get_socket_addr_from_env() -> multisock::SocketAddr {
    const INVALID_UTF8: &str = " contains invalid UTF-8";
    const INVALID_SOCKET: &str = concatcp!(ENV_KEY_SOCKET, INVALID_UTF8);
    const INVALID_HOST: &str = concatcp!(ENV_KEY_HOST, INVALID_UTF8);
    const INVALID_PORT: &str = concatcp!(ENV_KEY_PORT, " does not contain a valid port number");
    const INVALID_ADDR: &str = concatcp!(
        "Invalid TCP socket address from ",
        ENV_KEY_HOST,
        " and/or ",
        ENV_KEY_PORT
    );

    let socket_addr = if let Some(socket_name) = env::var_os(ENV_KEY_SOCKET) {
        format!("unix:{}", socket_name.into_string().expect(INVALID_SOCKET))
    } else if let Some(socket_host) = env::var_os(ENV_KEY_HOST) {
        let mut socket_host = socket_host.into_string().expect(INVALID_HOST);

        // Wrap bare IPv6 address in [...] as parse() expects
        if socket_host.contains(':') && !socket_host.contains('[') {
            socket_host = format!("[{socket_host}]");
        }

        let socket_port: u16 = match env::var_os(ENV_KEY_PORT) {
            Some(socket_port) => socket_port
                .into_string()
                .expect(INVALID_PORT)
                .parse()
                .expect(INVALID_PORT),
            None => 7786, // Interchange's default TCP port
        };

        let socket_str = format!("{socket_host}:{socket_port}");

        // If only numeric IP addresses were allowed, we would now be done. But we resolve
        // in case a hostname was used. Multiple IP addresses can come from one DNS
        // resolution, especially common for localhost (IPv4 + IPv6).
        let mut addrs_iter = socket_str.to_socket_addrs().expect(INVALID_ADDR);
        loop {
            match addrs_iter.next() {
                Some(addr) => {
                    // Use only IPv4 since Interchange Inet_Mode doesn't yet listen on IPv6.
                    if addr.is_ipv4() {
                        break addr.to_string();
                    }
                }
                None => {
                    panic!("{INVALID_ADDR} (must be IPv4)");
                }
            }
        }
    } else {
        // We could default to INET socket on localhost, but that isn't how
        // tlink behaves, and Interchange users tend to use INET less commonly
        // than UNIX sockets, so such a default would likely make it less
        // obvious why this link program isn't working when not configured.
        panic!("Environment variable {ENV_KEY_SOCKET} or {ENV_KEY_HOST} must be set");
    };

    socket_addr.parse().expect("Error parsing socket address")
}

/// Reads all of stdin.
/// If CONTENT_LENGTH environment variable is set, panics if given length
/// does not match length of bytes read from stdin.
fn get_entity() -> Vec<u8> {
    let mut buffer = Vec::new();

    const INVALID_CONTENT_LENGTH: &str = concatcp!(ENV_KEY_CONTENT_LENGTH, " has an invalid value");

    match env::var_os(ENV_KEY_CONTENT_LENGTH) {
        Some(cl) => {
            if cl.is_empty() {
                return buffer;
            }
            let cl = cl.to_str().expect(INVALID_CONTENT_LENGTH);
            if cl == "0" {
                return buffer;
            }
            let cl = cl.parse().expect(INVALID_CONTENT_LENGTH);

            let stdin = io::stdin();
            let mut handle = stdin.lock();
            handle
                .read_to_end(&mut buffer)
                .expect("Error reading entity from stdin");

            if buffer.len() != cl {
                panic!("Entity is wrong length");
            }

            buffer
        }
        None => buffer,
    }
}

/// Sends to a socket the Interchange-protocol arguments from CGI command line.
fn send_arguments(handle: &mut Stream) -> io::Result<()> {
    let mut out = BytesMut::new();

    out.put(&b"arg "[..]);
    out.put(number_to_text_bytes(env::args_os().count()));
    out.put_u8(b'\n');

    for arg in env::args_os() {
        let arg = Bytes::from(arg.into_vec());
        out.put(number_to_text_bytes(arg.len()));
        out.put_u8(b' ');
        out.put(arg);
        out.put_u8(b'\n');
    }

    handle.write_all(&out.freeze())?;

    Ok(())
}

/// Sends to a socket the Interchange-protocol environment variables.
fn send_environment(handle: &mut Stream) -> io::Result<()> {
    let mut out = BytesMut::new();

    out.put(&b"env "[..]);
    out.put(number_to_text_bytes(env::vars_os().count()));
    out.put_u8(b'\n');

    for (k, v) in env::vars_os() {
        let mut setting = BytesMut::new();
        setting.put(Bytes::from(k.into_vec()));
        setting.put_u8(b'=');
        setting.put(Bytes::from(v.into_vec()));

        out.put(number_to_text_bytes(setting.len()));
        out.put_u8(b' ');
        out.put(setting);
        out.put_u8(b'\n');
    }

    handle.write_all(&out.freeze())?;

    Ok(())
}

/// Sends to a socket the Interchange-protocol "entity" (which normally was read from stdin).
fn send_entity(handle: &mut Stream, entity: &[u8]) -> io::Result<()> {
    let mut out = BytesMut::new();
    out.put(&b"entity\n"[..]);
    out.put(number_to_text_bytes(entity.len()));
    out.put_u8(b' ');
    handle.write_all(&out)?;
    handle.write_all(entity)?;
    handle.write_all(&b"\n"[..])?;
    Ok(())
}

/// Sends to a socket the Interchange-protocol end of message.
fn send_end(handle: &mut Stream) -> io::Result<()> {
    handle.write_all(&b"end\n"[..])?;
    Ok(())
}

/// Sends to a socket the entire Interchange-protocol response.
fn send_all_to_ic(handle: &mut Stream, entity: &[u8]) -> io::Result<()> {
    send_arguments(handle)?;
    send_environment(handle)?;
    send_entity(handle, entity)?;
    send_end(handle)?;
    Ok(())
}

/// Assembles a 503 error response in HTTP headers & HTML body.
fn put_error_in_response(response: &mut Vec<u8>) {
    response.extend_from_slice(
        "\
        Status: 503 Service Unavailable\r\n\
        Content-Type: text/html; charset=UTF-8\r\n\
        \r\n\
        "
        .as_bytes(),
    );
    response.extend_from_slice(include_str!("503.html").as_bytes());
}

fn main() -> io::Result<()> {
    let socket_addr = get_socket_addr_from_env();

    let mut response = Vec::<u8>::new();

    // Try connecting to the socket every half-second for up to 10 seconds
    // to allow time for Interchange server restarts.
    const RETRY_WAIT_MSEC: Duration = Duration::from_millis(500);
    const RETRY_MAX_TRIES: u8 = 21;
    let mut count: u8 = 0;
    loop {
        if let Ok(mut stream) = Stream::connect(&socket_addr) {
            let entity = get_entity();
            send_all_to_ic(&mut stream, &entity)?;
            stream.read_to_end(&mut response)?;
            break;
        }

        count += 1;
        if count >= RETRY_MAX_TRIES {
            put_error_in_response(&mut response);
            break;
        }

        sleep(RETRY_WAIT_MSEC);
    }

    let stdout = io::stdout();
    let mut handle = stdout.lock();
    handle.write_all(&response).expect("Error sending response");

    Ok(())
}
