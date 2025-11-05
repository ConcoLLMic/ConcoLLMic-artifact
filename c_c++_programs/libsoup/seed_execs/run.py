def execute_program(timeout: int) -> tuple[str, int]:
    """
    Execute the libsoup server, send a request with a cookie to trigger
    soup_cookie_parse logic, and return server's stderr and exit code.
    """
    import os
    import signal
    import socket
    import subprocess
    import time

    # this server termination can be reused for new test cases
    def terminate_server(server, use_sigkill=False):
        """Helper function to terminate the server, trying SIGUSR1 first for gcov collection"""
        if server.poll() is None:  # Only if server is still running
            try:
                # Always try SIGUSR1 first for gcov collection
                os.kill(server.pid, signal.SIGUSR1)
                time.sleep(3)

                # If server still running and sigkill requested, force kill
                if use_sigkill and server.poll() is None:
                    os.kill(server.pid, signal.SIGKILL)
                    return -signal.SIGKILL
            except OSError:
                pass
        return server.returncode if server.poll() is not None else -signal.SIGUSR1

    # find an available port on the system
    def find_available_port():
        """Find an available port on the system."""
        import socket

        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(
                ("localhost", 0)
            )  # Binding to port 0 lets the OS assign an available port
            return s.getsockname()[1]  # Return the port number assigned

    server_path = "./build/examples/simple-httpd"
    server = None
    port = find_available_port()

    try:
        # Start the server
        server = subprocess.Popen(
            [server_path, "-d", ".", "-p", str(port), "-a"],
            stderr=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            text=True,
        )

        # Wait for server to start
        time.sleep(0.5)

        # Send request
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(timeout)
                s.connect(("localhost", port))

                request = (
                    f"GET /echo HTTP/1.1\r\n"
                    f"Host: localhost:{port}\r\n"
                    "Cookie: TestCookie=Value1; AnotherCookie=Value2; Domain=localhost\r\n"
                    "Connection: close\r\n\r\n"
                )
                s.sendall(request.encode("utf-8"))
                time.sleep(0.5)  # wait for server to process the request
        except Exception:
            pass  # Continue to server termination even if request fails

        # Signal server to exit and collect output
        return_code = terminate_server(server)

        # Wait for server to exit with timeout
        try:
            if server.poll() is None:  # Only wait if server is still running
                server.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Force kill if timeout occurs
            return_code = terminate_server(server, use_sigkill=True)

        # Collect server output from stderr
        return server.stderr.read(), return_code

    except Exception:
        # Clean up on any unexpected error
        if server:
            terminate_server(server, use_sigkill=True)
        raise
