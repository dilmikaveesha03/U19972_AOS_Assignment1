#!/usr/bin/env python3

# Secure Submission Validator

import sys
import os
import hashlib
import datetime


def compute_sha256(filepath: str) -> str:
    
    sha256 = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                sha256.update(chunk)
    except OSError as e:
        print(f"ERROR: Cannot read file '{filepath}': {e}", file=sys.stderr)
        sys.exit(1)
    return sha256.hexdigest()


def load_hash_database(hash_db_path: str) -> set[str]:
  
    known_hashes: set[str] = set()

    if not os.path.exists(hash_db_path):
        return known_hashes

    with open(hash_db_path, "r") as db:
        for line in db:
            line = line.strip()
            if line and not line.startswith("#"):
                parts: list[str] = line.split("|")
                if parts:
                    known_hashes.add(parts[0].strip())

    return known_hashes


def check_hash(file_path: str, hash_db_path: str) -> None:
    file_hash:     str      = compute_sha256(file_path)
    known_hashes:  set[str] = load_hash_database(hash_db_path)

    if file_hash in known_hashes:
        print("DUPLICATE")
    else:
        print("NEW")


def register_hash(file_path: str, hash_db_path: str) -> None:
    file_hash:    str      = compute_sha256(file_path)
    known_hashes: set[str] = load_hash_database(hash_db_path)

    if file_hash in known_hashes:
        return  

    timestamp: str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    filename:  str = os.path.basename(file_path)
    entry:     str = f"{file_hash} | {filename} | {timestamp}\n"

    os.makedirs(os.path.dirname(os.path.abspath(hash_db_path)), exist_ok=True)
    with open(hash_db_path, "a") as db:
        db.write(entry)


# CLI Entry Point 

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(
            "Usage: validator.py <check_hash|register_hash> <file_path> <hash_db>",
            file=sys.stderr
        )
        sys.exit(1)

    command:    str = sys.argv[1]
    input_file: str = sys.argv[2]
    db_path:    str = sys.argv[3]

    if not os.path.isfile(input_file):
        print(f"ERROR: File not found: {input_file}", file=sys.stderr)
        sys.exit(1)

    if command == "check_hash":
        check_hash(input_file, db_path)
    elif command == "register_hash":
        register_hash(input_file, db_path)
    else:
        print(f"ERROR: Unknown command '{command}'", file=sys.stderr)
        sys.exit(1)

