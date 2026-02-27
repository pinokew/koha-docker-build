#!/usr/bin/env bash
set -euo pipefail

if [ -x /usr/sbin/koha-create ]; then
  # Debian/Apache variants in public images may not provide mpm_itk.
  # Keep koha-create usable by bypassing only that hard-stop check.
  if ! grep -q "mpm_itk check bypassed by koha-setup" /usr/sbin/koha-create; then
    perl -0777 -i -pe 's#(Koha requires mpm_itk to be enabled within Apache in order to run\.\nTypically this can be enabled with:\n\n\s+\$APACHE_DISABLE_MPM_MSG sudo a2enmod mpm_itk\nEOM\n)\s*die#${1}\n        echo "WARNING: mpm_itk check bypassed by koha-setup." 1>\&2#s' /usr/sbin/koha-create || true
  fi

  # Apache 2.4 threaded setups usually expose cgid_module instead of cgi_module.
  sed -i "s/grep -q 'cgi_module'/grep -Eq 'cgi_module|cgid_module'/" /usr/sbin/koha-create || true

  # The setup pipeline may pre-create the instance user; make adduser idempotent.
  sed -i 's/--quiet "\$username"/--quiet "\$username" || true/' /usr/sbin/koha-create || true

  # In pinokew image Apache restart may fail before AssignUserID cleanup step.
  sed -i 's/service apache2 restart/service apache2 restart || true/' /usr/sbin/koha-create || true

  sed -i "s/die \"User \\\$username already exists\\.\"/echo \"User exists.\" 1>\\&2/" /usr/sbin/koha-create || true
  sed -i "s/die \"Group \\\$username already exists\\.\"/echo \"Group exists.\" 1>\\&2/" /usr/sbin/koha-create || true
fi
