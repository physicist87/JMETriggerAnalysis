#!/usr/bin/env python3

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

try:
    import uproot
except ImportError:
    print("ERROR: uproot is not available.")
    print("Install it with: python3 -m pip install --user uproot")
    sys.exit(2)


FILE_PATTERN = re.compile(r"^ntuple_(\d+)\.root$")


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Check AK8 ntuple Condor outputs."
    )

    parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory containing ntuple_<jobid>.root files.",
    )

    parser.add_argument(
        "--input-list",
        help=(
            "Original input file list. The number of non-empty, "
            "non-comment lines determines the expected number of jobs."
        ),
    )

    parser.add_argument(
        "--expected",
        type=int,
        help=(
            "Expected number of jobs. Kept as a fallback. "
            "--input-list takes precedence when both are provided."
        ),
    )

    parser.add_argument(
        "--min-size",
        type=int,
        default=1024,
        help="Minimum acceptable ROOT-file size in bytes. Default: 1024.",
    )

    parser.add_argument(
        "--skip-integrity",
        action="store_true",
        help="Skip opening ROOT files with uproot.",
    )

    return parser.parse_args()


def read_input_files(input_list):
    input_path = Path(input_list).expanduser()

    if not input_path.is_file():
        raise FileNotFoundError(f"Input list not found: {input_path}")

    valid_inputs = []

    with input_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()

            if not stripped:
                continue

            if stripped.startswith("#"):
                continue

            valid_inputs.append(stripped)

    return valid_inputs


def find_output_files(output_dir):
    output_path = Path(output_dir).expanduser()

    if not output_path.is_dir():
        raise NotADirectoryError(
            f"Output directory not found: {output_path}"
        )

    matched_files = []

    for path in output_path.glob("ntuple_*.root"):
        match = FILE_PATTERN.match(path.name)

        if match:
            matched_files.append((int(match.group(1)), path))

    return sorted(matched_files, key=lambda item: item[0])


def check_root_file(path):
    try:
        with uproot.open(path) as root_file:
            # Force uproot to read the ROOT directory information.
            root_file.keys()
        return None
    except Exception as error:
        return str(error)


def main():
    args = parse_arguments()

    try:
        if args.input_list:
            input_files = read_input_files(args.input_list)
            expected = len(input_files)
            expected_source = f"input list: {args.input_list}"
        elif args.expected is not None:
            if args.expected < 0:
                raise ValueError("--expected must be non-negative.")

            expected = args.expected
            expected_source = "--expected argument"
        else:
            raise ValueError(
                "Provide --input-list, or use --expected as a fallback."
            )

        output_files = find_output_files(args.output_dir)

    except (FileNotFoundError, NotADirectoryError, ValueError) as error:
        print(f"ERROR: {error}")
        return 2

    job_ids = [job_id for job_id, _ in output_files]
    id_counts = Counter(job_ids)

    unique_ids = sorted(id_counts)
    expected_ids = set(range(expected))
    actual_ids = set(unique_ids)

    missing_ids = sorted(expected_ids - actual_ids)
    extra_ids = sorted(actual_ids - expected_ids)
    duplicate_ids = sorted(
        job_id for job_id, count in id_counts.items() if count > 1
    )

    zero_size_files = []
    small_files = []

    for _, path in output_files:
        size = path.stat().st_size

        if size == 0:
            zero_size_files.append(path)
        elif size < args.min_size:
            small_files.append(path)

    print("=" * 70)
    print("AK8 NTUPLE OUTPUT CHECK")
    print("=" * 70)
    print(f"Output directory : {args.output_dir}")
    print(f"Expected source  : {expected_source}")
    print(f"Expected jobs    : {expected}")
    print(f"Unique job IDs   : {len(unique_ids)}")
    print(f"Missing outputs  : {len(missing_ids)}")
    print(f"Extra job IDs    : {len(extra_ids)}")
    print(f"Duplicate IDs    : {len(duplicate_ids)}")
    print(f"Zero-size files  : {len(zero_size_files)}")
    print(f"Small files      : {len(small_files)}")

    if missing_ids:
        print("\nMissing output job IDs:")
        print(f"  {missing_ids}")

    if extra_ids:
        print("\nExtra output job IDs:")
        print(f"  {extra_ids}")

    if duplicate_ids:
        print("\nDuplicate job IDs:")
        print(f"  {duplicate_ids}")

    if zero_size_files:
        print("\nZero-size files:")
        for path in zero_size_files:
            print(f"  {path}")

    if small_files:
        print(f"\nFiles smaller than {args.min_size} bytes:")
        for path in small_files:
            print(f"  {path} ({path.stat().st_size} bytes)")

    bad_root_files = []

    if not args.skip_integrity:
        print("\nChecking ROOT file integrity...")

        total = len(output_files)

        for index, (_, path) in enumerate(output_files, start=1):
            error = check_root_file(path)

            if error is not None:
                bad_root_files.append((path, error))

            if index % 20 == 0 or index == total:
                print(f"  checked {index}/{total} files")

        if bad_root_files:
            print("\nUnreadable ROOT files:")

            for path, error in bad_root_files:
                print(f"  {path}")
                print(f"    {error}")

    problems_found = any(
        [
            missing_ids,
            extra_ids,
            duplicate_ids,
            zero_size_files,
            small_files,
            bad_root_files,
        ]
    )

    print("\n" + "=" * 70)

    if problems_found:
        print("RESULT: problems were found.")

        if missing_ids and args.input_list:
            missing_file = Path("missing_job_ids.txt")

            with missing_file.open("w", encoding="utf-8") as handle:
                handle.write(",".join(str(job_id) for job_id in missing_ids))
                handle.write("\n")

            print(f"Missing IDs saved to: {missing_file}")
            print("\nResubmit command fragment:")
            print(
                f"  --resubmit "
                f"{','.join(str(job_id) for job_id in missing_ids)}"
            )

        return 1

    print("RESULT: all expected outputs passed the checks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
