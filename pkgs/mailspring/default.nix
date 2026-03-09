# TODO: Create custom Mailspring package with randomized Message-IDs
# This requires:
# 1. Creating a patch file that modifies app/src/flux/stores/draft-factory.ts
#    to change headerMessageId from:
#      headerMessageId: `${uuidv4().toUpperCase()}@getmailspring.com`,
#    to:
#      headerMessageId: `${uuidv4().toUpperCase()}@${uuidv4().split('-')[0]}.local`,
# 2. Overriding the mailspring package with the patch
# 3. Building from source or patching the existing package
#
# For now, use the standard mailspring package from nixpkgs
{ lib, pkgs }:
pkgs.mailspring
