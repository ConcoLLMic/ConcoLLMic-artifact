def execute_program(timeout: int) -> tuple[str, int]:
    import signal
    import subprocess
    import tempfile

    yaml_data = "foo: bar"

    # create a temporary file
    with tempfile.NamedTemporaryFile(mode="w") as temp_file:
        # write data to file
        temp_file.write(yaml_data)
        temp_file.flush()
        temp_file_path = temp_file.name
        try:
            # the target takes input file
            result = subprocess.run(
                ["./tests/run-parser-test-suite", temp_file_path],
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
