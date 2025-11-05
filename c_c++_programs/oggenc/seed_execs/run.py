def execute_program(timeout: int) -> tuple[str, int]:
    import binascii
    import signal
    import subprocess
    import tempfile

    hex_data = [
        "5249 4646 2400 0000 5741 5645 666d 7420",
        "1000 0000 0100 0100 44ac 0000 8858 0100",
        "0200 1000 6461 7461 0000 0000 2020 2020",
        "2020 2020 2020 2020 2020 2020 2020 2020",
        "2020 2020 2020 2020 2020 2020 2020 2020",
        "2020 2020 2020 2020 2020 2020 2020 2020",
        "2020 200a",
    ]

    # merge hex strings and convert to binary data
    hex_str = "".join(line.replace(" ", "") for line in hex_data)
    binary_data = binascii.unhexlify(hex_str)

    # create a temporary file
    with tempfile.NamedTemporaryFile(mode="wb") as temp_file:
        # write binary data to file
        temp_file.write(binary_data)
        temp_file.flush()
        temp_file_path = temp_file.name
        try:
            result = subprocess.run(
                ["./oggenc/oggenc", temp_file_path],
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
