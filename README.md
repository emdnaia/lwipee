# lwipee

`lwipee` is a basic Linux utility that offers file encryption and secure wiping using `shred` and `gpg`. The script presents a menu where you can select to:

- Encrypt files
- Wipe files
- Both Encrypt and Wipe files

## Features

- **Interactive Menu**: Offers a basic interface to select between encryption, wiping, or both.
- **Security Mechanisms**: Attempts to avoid deleting critical binaries to maintain system operability as long as possible.
- **Error Handling**: Tries to process all files, even when encountering permissions issues or missing files.

## Current Status

This script is in its early stages and might not cover all edge cases. Critical binaries are protected, but further testing is needed. It’s functional, but improvements are essential, especially in how it handles error conditions and preserves system stability during operation.

**Feedback Welcome**: If you’ve got ideas or notice issues, contributions are more than welcome.
