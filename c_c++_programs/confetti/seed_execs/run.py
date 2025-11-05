def execute_program(timeout: int) -> tuple[str, int]:
    import signal
    import subprocess

    file_data = """
# This is a comment.

probe-device eth0 eth1

user * {
    login anonymous
    password \"${ENV:ANONPASS}\"
    machine 167.89.14.1
    proxy {
        try-ports 582 583 584
    }
}

user \"Joe Williams\" {
    login joe
    machine 167.89.14.1
}"""

    try:
        # ./parse read input from stdin
        result = subprocess.run(
            ["./parse"],
            input=file_data,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        # return stderr and the returncode
        return result.stderr, result.returncode
    except subprocess.TimeoutExpired as e:
        # Timeout occurred, also ensure to return stderr captured before timeout and return code -signal.SIGKILL
        return e.stderr, -signal.SIGKILL
    except Exception as e:
        # ensure to raise the error if run failed
        raise e
