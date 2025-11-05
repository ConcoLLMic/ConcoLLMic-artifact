def execute_program(timeout: int) -> tuple[str, int]:
    import signal
    import subprocess

    proto_data = """
syntax = "proto3";

package example;

option go_package = "/examplepb";

message Person {
  string name = 1;
  int32 id = 2;
}
"""

    # create a proto file
    with open("test", mode="w") as file:
        # write to the proto file
        file.write(proto_data)
        file.flush()
        file_path = file.name
        try:
            result = subprocess.run(
                [
                    "./build/protoc",
                    "--plugin=protobuf-go/protoc-gen-go",
                    "--go_out=.",
                    file_path,
                ],
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
