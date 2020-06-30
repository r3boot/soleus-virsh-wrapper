#!/bin/bash

if [[ "$(whoami)" != "root" ]]; then
  echo "ERROR: You need to be root to run this command"
  exit 1
fi

VPS_DATA='vps.data'
SUDOERS_FILE='/etc/sudoers.d/virsh-wrapper'

TMPFILE="$(mktemp)"
trap "rm -vf ${TMPFILE}" QUIT TERM # Huh? why is this not working??

cat ${VPS_DATA} | egrep -v '^#' | while read LINE; do
  OWNER="$(echo "${LINE}" | cut -d: -f1)"
  VM_DATA="$(echo "${LINE}" | cut -d: -f2)"

  if [[ -z "${OWNER}" ]]; then
    echo "WARNING: OWNER cannot be empty, skipping ..."
    continue
  fi

  if [[ -z "${VM_DATA}" ]]; then
    echo "WARNING: No hostnames found for ${OWNER}, skipping ..."
    continue
  fi

  for VM in ${VM_DATA}; do
    NAME="$(echo "${VM}" | cut -d, -f1)"
    cat >> ${TMPFILE} <<EOF
${OWNER} ALL=(ALL) NOPASSWD: \\
  /bin/find /var/lib/libvirt/images -type f -name \*.iso, \\
  /bin/virsh autostart ${NAME}, \\
  /bin/virsh autostart ${NAME} --disable, \\
  /bin/virsh start ${NAME}, \\
  /bin/virsh shutdown ${NAME}, \\
  /bin/virsh reset ${NAME}, \\
  /bin/virsh reboot ${NAME}, \\
  /bin/virsh domblklist ${NAME}, \\
  /bin/virsh change-media ${NAME} sda --eject, \\
  /bin/virsh change-media ${NAME} sda /var/lib/libvirt/images/*.iso --insert, \\
  /bin/virsh list --autostart --name, \\
  /bin/virsh list --all

EOF
  done
done

install -o root -g root -m 0400 "${TMPFILE}" "${SUDOERS_FILE}"
rm -f "${TMPFILE}"
