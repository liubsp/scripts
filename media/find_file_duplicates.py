import argparse
import hashlib
import os
from collections import defaultdict


def hash_file(path, block_size=131072):
    """Generate a hash for a file using a middle block of the file."""
    sha256 = hashlib.sha256()
    try:
        file_size = os.path.getsize(path)
        with open(path, 'rb') as f:
            if file_size < 2*block_size:
                # File is too small; read the whole thing
                sha256.update(f.read())
            else:
                middle = file_size // 2 - block_size
                f.seek(middle)
                sha256.update(f.read(block_size))
    except (OSError, IOError):
        return None
    return sha256.hexdigest()


def find_duplicates(search_dir, by_name=False, exclude_prefix=None):
    """Find duplicate files based on content hash."""
    hashes = defaultdict(list)
    for root, _, files in os.walk(search_dir):
        for file in files:
            full_path = os.path.join(root, file)
            if exclude_prefix and any(full_path.startswith(os.path.expanduser(prefix)) for prefix in exclude_prefix):
                continue
            print(f"Found: {full_path}")
            key = file if by_name else hash_file(full_path)
            if key:
                hashes[key].append(full_path)
    result = []
    for paths in hashes.values():
        if len(paths) > 1:
            result.append(paths)
    return result


def main():
    parser = argparse.ArgumentParser(description="Finds duplicate files.")
    parser.add_argument("--search-dir", required=True,
                        help="Directory to search for duplicates.")
    parser.add_argument("--exclude-prefix", action="append",
                        help="Exclude files that start with this prefix. Can be used multiple times.")
    parser.add_argument("--by-name", action="store_true",
                        help="Detect duplicates by file name instead of content hash.")
    args = parser.parse_args()

    search_dir = os.path.expanduser(args.search_dir)

    duplicates = find_duplicates(search_dir, args.by_name, args.exclude_prefix)

    print("\nDuplicates:")
    for paths in duplicates:
        print(paths)
    print(f"\nTotal: {len(duplicates)}")


if __name__ == "__main__":
    main()
