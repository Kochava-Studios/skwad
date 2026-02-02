# Sparkle Auto-Update Setup

This document describes the Sparkle auto-update configuration for Skwad.

## Overview

Skwad uses [Sparkle 2.x](https://sparkle-project.org/) for automatic updates. Updates are signed using EdDSA (Ed25519) signatures.

## Key Information

- **Public Key** (in `Skwad/Info.plist`): `Ly6mieNPNaFhdYyen9CuMTshryIaSiVHWNAhZ6ZdEOQ=`
- **Private Key**: Stored in macOS Keychain under "Sparkle Private Key" and backed up in Bitwarden
- **Feed URL**: `https://bonamy.fr/skwad/appcast.xml`
- **Download URL**: `https://bonamy.fr/skwad/Skwad.zip`

## Sparkle Tools Location

After building, Sparkle tools are available at:
```
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/
```

Key tools:
- `generate_keys` - Generate or manage EdDSA keys
- `sign_update` - Sign a ZIP file for distribution

## Signing Updates

When releasing, sign the ZIP before uploading:

```bash
./build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update build/Skwad.zip
```

This outputs a signature like:
```
sparkle:edSignature="..." length="..."
```

The signature should be added to the appcast.xml `<enclosure>` tag.

## Restoring Keys from Backup

If you lose access to your Keychain (new machine, etc.), restore the private key from Bitwarden:

### Method 1: Import from file

1. Create a file with the private key:
   ```bash
   echo "YOUR_PRIVATE_KEY_FROM_BITWARDEN" > /tmp/sparkle_private_key.txt
   ```

2. Import the key:
   ```bash
   ./build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -f /tmp/sparkle_private_key.txt
   ```

3. Delete the temporary file:
   ```bash
   rm /tmp/sparkle_private_key.txt
   ```

### Method 2: Direct import (if tools aren't built yet)

1. Build the project first to get Sparkle tools:
   ```bash
   make build
   ```

2. Then import as shown above.

### Verify Key Import

After importing, verify the public key matches:
```bash
./build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -p
```

Should output: `Ly6mieNPNaFhdYyen9CuMTshryIaSiVHWNAhZ6ZdEOQ=`

## Key Management Commands

```bash
# Generate new keys (only do this once!)
./generate_keys

# Print public key
./generate_keys -p

# Export private key to file (for backup)
./generate_keys -x /path/to/backup.txt

# Import private key from file
./generate_keys -f /path/to/backup.txt
```

## Release Process

1. `make release` - Builds, notarizes, generates appcast
2. Sign the ZIP:
   ```bash
   ./build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update build/Skwad.zip
   ```
3. Update `build/appcast.xml` with the signature
4. `make upload` - Uploads ZIP and appcast to server

## Troubleshooting

### "No signing key found"
Import your private key from Bitwarden (see above).

### "Signature verification failed"
The public key in Info.plist doesn't match the private key used to sign. Ensure you're using the correct key pair.

### Key mismatch after restore
If you generate a new key instead of restoring, users on old versions won't be able to update. Always restore from backup!
