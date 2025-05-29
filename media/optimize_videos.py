import argparse
import os
import subprocess
from pathlib import Path
from tqdm import tqdm

SUPPORTED_EXTENSIONS = ['.mov', '.mkv', '.avi',
                        '.wmv', '.flv', '.webm', '.mpg', '.mpeg']


def is_video_file(file_path):
    return file_path.suffix.lower() in SUPPORTED_EXTENSIONS


def process_directory(directory, stabilize, exclude_prefix=None):
    videos_to_convert = []

    for root, _, files in os.walk(directory):
        for file in files:
            input_path = Path(root) / file
            if exclude_prefix and any(str(input_path).startswith(os.path.expanduser(prefix)) for prefix in exclude_prefix):
                continue
            if is_video_file(input_path):
                output_path = input_path.with_suffix('.mp4')
                if output_path != input_path:
                    videos_to_convert.append((input_path, output_path))

    if not videos_to_convert:
        print("\nNo videos found to convert.")
        return

    print("\nThe following videos will be converted:")
    for input_path, output_path in videos_to_convert:
        print(f"{input_path} -> {output_path}")
    print(f"\nTotal: {len(videos_to_convert)}")

    confirm = input("\nDo you want to proceed? (y/n): ").strip().lower()
    if confirm != 'y':
        print("Conversion cancelled.")
        return

    for input_path, output_path in tqdm(videos_to_convert, desc="Processing videos", unit="video"):
        convert_to_mp4(input_path, output_path, stabilize)


def convert_to_mp4(input_path, output_path, stabilize=False):
    if stabilize:
        stabilize_and_convert(input_path, output_path)
    else:
        command = [
            'ffmpeg',
            '-i', str(input_path),
            '-c:v', 'h264_videotoolbox',  # Apple Silicon optimized encoder
            '-pix_fmt', 'yuv420p',        # Ensures compatibility
            '-profile:v', 'main',         # Sets the profile
            '-c:a', 'copy',               # Copy audio without re-encoding
            '-y',                         # Overwrite without prompt
            str(output_path)
        ]
        print(f"\nConverting {input_path} to {output_path}\n")
        subprocess.run(command, check=True)


def stabilize_and_convert(input_path, output_path):
    trf_path = input_path.with_suffix('.trf')

    print(f"\nAnalyzing video for stabilization: {input_path}\n")
    detect_cmd = [
        'ffmpeg',
        '-i', str(input_path),
        '-vf', f'scale=1280:-1,vidstabdetect=fileformat=1:shakiness=10:result={trf_path}',
        '-f', 'null',
        '-'
    ]
    subprocess.run(detect_cmd, check=True)

    command = [
        'ffmpeg',
        '-i', str(input_path),
        '-vf', f'vidstabtransform=input={trf_path}:smoothing=30:zoom=5',
        '-c:v', 'h264_videotoolbox',  # Apple Silicon optimized encoder
        '-pix_fmt', 'yuv420p',        # Ensures compatibility
        '-c:a', 'copy',               # Copy audio without re-encoding
        '-y',                         # Overwrite without prompt
        str(output_path)
    ]
    print(f"\nConverting (with stabilization) {input_path} to {output_path}\n")
    subprocess.run(command, check=True)

    try:
        trf_path.unlink()
        print(f"Temporary stabilization file {trf_path} removed.")
    except Exception as e:
        print(f"Warning: could not remove temporary file {trf_path}: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Recursively convert videos to MP4 format, with optional stabilization."
    )
    parser.add_argument('--dir', required=True,
                        help="Directory to scan for videos.")
    parser.add_argument("--exclude-prefix", action="append",
                        help="Exclude files that start with this prefix. Can be used multiple times.")
    parser.add_argument('--stabilize', action='store_true',
                        help="Apply software video stabilization.")
    args = parser.parse_args()

    directory = os.path.expanduser(args.dir)

    process_directory(directory, args.stabilize, args.exclude_prefix)


if __name__ == '__main__':
    main()
