#!/usr/bin/env python3
import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_libmetal_depends.py <cmake/depends.cmake>", file=sys.stderr)
        return 1

    path = pathlib.Path(sys.argv[1])
    data = path.read_text()
    old = (
        '  find_package (LibUdev REQUIRED)\n'
        '  collect (PROJECT_INC_DIRS "${LIBUDEV_INCLUDE_DIR}")\n'
        '  collect (PROJECT_LIB_DEPS "${LIBUDEV_LIBRARIES}")\n'
    )
    new = (
        '  find_package (LibUdev)\n'
        '  if (LIBUDEV_FOUND)\n'
        '    collect (PROJECT_INC_DIRS "${LIBUDEV_INCLUDE_DIR}")\n'
        '    collect (PROJECT_LIB_DEPS "${LIBUDEV_LIBRARIES}")\n'
        '  endif(LIBUDEV_FOUND)\n'
    )
    if old not in data:
        print(f"failed to patch {path}", file=sys.stderr)
        return 1
    path.write_text(data.replace(old, new, 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
