def execute_program(timeout: int) -> tuple[str, int]:
    import signal
    import socket
    import subprocess
    import threading
    import time

    java_stderr = []
    py_stderr = []

    # Wait for the port to be ready. Do NOT change
    def wait_for_port(port: int, timeout: float) -> bool:
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=1):
                    return True
            except (ConnectionRefusedError, TimeoutError):
                time.sleep(0.1)
        return False

    # Read stderr from a pipe. Do NOT change
    def read_stderr(pipe):
        for line in iter(pipe.readline, ""):
            java_stderr.append(line)

    # Post-execution cleanup. Do NOT change
    def cleanup(thread):
        subprocess.run("pkill -f 'java -cp .:py4j0.10.9.9.jar'", shell=True)
        thread.join()

    # A Java Gateway program
    java_program = """
import py4j.GatewayServer;

public class Test {

    public int addition(int first, int second) {
        return first + second;
    }

    public static void main(String[] args) {
        Test app = new Test();
        // app is now the gateway.entry_point
        GatewayServer server = new GatewayServer(app);
        server.start();
    }
}
"""

    # A Python program that accesses JVM objects
    python_program = """
from py4j.java_gateway import JavaGateway

gateway = JavaGateway() 
random = gateway.jvm.java.util.Random()
number1 = random.nextInt(10) 
number2 = random.nextInt(10)
print(number1, number2)
test_app = gateway.entry_point
value = test_app.addition(number1, number2)
print(value)
"""

    # Defult port of Java Gateway
    PORT = 25333

    with open("Test.java", "w") as f:
        f.write(java_program)

    with open("test.py", "w") as f:
        f.write(python_program)

    try:
        # Compile Java code with py4j
        subprocess.run(["javac", "-cp", "py4j0.10.9.9.jar", "Test.java"], check=True)

        # Launch the Java Gateway program
        java_process = subprocess.Popen(
            ["java", "-cp", ".:py4j0.10.9.9.jar", "Test"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )

        # Start a thread to read stderr of the Java program to prevent stalling
        stderr_thread = threading.Thread(
            target=read_stderr, args=(java_process.stderr,), daemon=True
        )
        stderr_thread.start()

        # Wait for the Java Gateway to prepare the port
        wait_for_port(PORT, 1)

        # Launch the Python program
        python_process = subprocess.Popen(
            ["python3", "test.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        # Wait for the Python program to finish
        time.sleep(1)

        # Clean up all running processes
        cleanup(stderr_thread)

        # Collect stderr and return code from Python process
        py_stdout, py_stderr = python_process.communicate()
        py_ret = python_process.returncode

        # Return stderr and return code
        return "".join(java_stderr) + "".join(py_stderr), py_ret

    except subprocess.TimeoutExpired:
        # Clean up all running processes
        cleanup(stderr_thread)

        # Collect stderr from Python
        py_stderr = python_process.stderr.readlines()

        # Return stderr and -signal.SIGKILL
        return "".join(java_stderr) + "".join(py_stderr), -signal.SIGKILL

    except Exception as e:
        # Clean up all running processes
        cleanup(stderr_thread)

        # ensure to raise the error if run failed
        raise e
