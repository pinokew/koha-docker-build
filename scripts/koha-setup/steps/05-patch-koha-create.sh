#!/usr/bin/env bash
set -euo pipefail

if [ -x /usr/sbin/koha-create ]; then
  if ! grep -q "mpm_itk check bypassed" /usr/sbin/koha-create; then
    sed -i 's/Koha requires mpm_itk.*die/echo "WARNING: mpm_itk check bypassed." 1>\&2\n    #die/g' /usr/sbin/koha-create || true
    sed -i 's/die "User \$username already exists\."/echo "User exists." 1>\&2/' /usr/sbin/koha-create || true
    sed -i 's/die "Group \$username already exists\."/echo "Group exists." 1>\&2/' /usr/sbin/koha-create || true
  fi
fi
