#!/bin/bash
set -euo pipefail

#############################################################################
#  Touch Down Hosting — Master Admin Password Reset                         #
#                                                                           #
#  Resets the password of the MASTER admin account (the first root          #
#  administrator) without editing any config or script files.               #
#                                                                           #
#  Run from the panel installation folder:                                  #
#      sudo bash reset-master-password.sh                                   #
#                                                                           #
#  You will be prompted for the new password twice; if they match the       #
#  password is changed immediately. Safe to run as many times as needed.    #
#  This does NOT affect regular user accounts.                              #
#                                                                           #
#  Password requirements: 12-64 characters, with at least one lowercase     #
#  letter, one uppercase letter, one number and one special character.      #
#  The new password cannot be the same as the current password.             #
#############################################################################

cd "$(dirname "$0")"

if [ ! -f artisan ]; then
  echo "[ERROR] artisan not found - run this script from the panel installation folder." >&2
  exit 1
fi

exec php artisan tdh:reset-master-password
