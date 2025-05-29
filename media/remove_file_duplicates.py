import argparse
import hashlib
import os
from collections import defaultdict
from send2trash import send2trash


def hash_file(path, block_size=131072):
    """Generate a SHA256 hash of a file by reading one block in the middle."""
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


def find_duplicates(search_dir, by_name=False):
    """Find duplicate files based on content hash."""
    hashes = defaultdict(list)
    for root, _, files in os.walk(search_dir):
        for file in files:
            full_path = os.path.join(root, file)
            print(f"Found: {full_path}")
            key = file if by_name else hash_file(full_path)
            if key:
                hashes[key].append(full_path)
    return hashes


def filter_removals(duplicates, remove_prefix):
    """Filter duplicates, keeping all not matching remove_prefix, or one if all match."""
    to_remove = []
    for paths in duplicates.values():
        if len(paths) > 1:
            matching = [p for p in paths if p.startswith(remove_prefix)]
            non_matching = len(paths) - len(matching)

            if non_matching:
                # Keep all non-matching, remove matching
                to_remove.extend(matching)
            elif matching:
                # All match, keep one, remove the rest
                to_remove.extend(matching[1:])
    return to_remove


def main():
    parser = argparse.ArgumentParser(
        description="Find and optionally delete duplicate files.")
    parser.add_argument("--search-dir", required=True,
                        help="Directory to search for duplicates.")
    parser.add_argument("--remove-prefix", required=True,
                        help="Prefix path to mark for removal.")
    parser.add_argument("--by-name", action="store_true",
                        help="Detect duplicates by file name instead of content hash.")
    args = parser.parse_args()

    search_dir = os.path.expanduser(args.search_dir)
    remove_prefix = os.path.expanduser(args.remove_prefix)

    duplicates = find_duplicates(search_dir, args.by_name)
    to_remove = filter_removals(duplicates, remove_prefix)

    if not to_remove:
        print("No duplicates found to remove.")
        return

    print("\nDuplicates that would be moved to Trash:")
    for path in to_remove:
        print(path)
    print(f"\nTotal: {len(to_remove)}")

    confirm = input(
        "\nAre you sure you want to move these files to Trash? [y/N]: ").lower()
    if confirm == 'y':
        for path in to_remove:
            try:
                send2trash(path)
                print(f"Trashed: {path}")
            except Exception as e:
                print(f"Error trashing {path}: {e}")
    else:
        print("Aborted.")


if __name__ == "__main__":
    main()
