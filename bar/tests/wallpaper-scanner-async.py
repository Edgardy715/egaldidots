"""Build the production scanner and exercise async lifecycle without user data."""

import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, help="retain the build for integration")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="isla-wpscan-async-") as temporary:
        source = Path(temporary)
        build = args.build.resolve() if args.build else source / "build"
        (source / "CMakeLists.txt").write_text(f'''cmake_minimum_required(VERSION 3.22)
project(ScannerRegression LANGUAGES CXX)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Concurrent Qml)
add_subdirectory("{ROOT / 'wpscan'}" wpscan)
add_executable(scanner-async "{ROOT / 'bar/tests/wallpaper-scanner-async.cpp'}")
target_include_directories(scanner-async PRIVATE "{ROOT / 'wpscan'}")
target_link_libraries(scanner-async PRIVATE wpscanplugin Qt6::Core Qt6::Concurrent Qt6::Qml)
''')
        subprocess.run(["cmake", "-S", str(source), "-B", str(build), "-G", "Ninja",
                        "-DCMAKE_BUILD_TYPE=Release"], check=True, capture_output=True)
        subprocess.run(["cmake", "--build", str(build), "--parallel", "2"],
                       check=True, capture_output=True)
        subprocess.run([str(build / "scanner-async")], check=True, timeout=15)
        print(f"Plugin build: {build}")


if __name__ == "__main__":
    main()
