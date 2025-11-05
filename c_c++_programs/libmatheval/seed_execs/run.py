def execute_program(timeout: int) -> tuple[str, int]:
    import signal
    import subprocess

    input_str = "3*x\n"

    try:
        # ./program is interactive!
        result = subprocess.run(
            ["./program"],
            input=input_str,
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
