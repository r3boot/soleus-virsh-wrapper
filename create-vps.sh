#!/bin/bash

MEMBER_VG='system'
VPS_DATA='vps.data'
VPS_TEMPLATE='newvps.template'

function help_and_exit {
  echo "Usage: $(basename ${0}) VPS_NAME ISO"
  exit 1
}

function create_vps {
  OWNER="${1}"
  VPS_NAME="${2}"
  NUM_CORES="${3}"
  MEM_IN_MB="${4}"
  DISK_IN_GB="${5}"
  SPICE_PORT="${6}"
  SPICE_PASS="${7}"
  ISO="${8}"
  UUID="$(uuidgen)"
  MACADDR="$(hexdump -n3 -e'/3 "00:20:91" 3/1 ":%02X"' /dev/random)"

  XML_DEFINITION="/etc/libvirt/qemu/${VPS_NAME}.xml"

  # Check if vm is already defined
  if [[ -f "${XML_DEFINITION}" ]]; then
    echo "ERROR: ${VPS_NAME} already exists, exiting ..."
    exit 1
  fi

  # Create logical volume
  lvs "${MEMBER_VG}" | grep -q "${VPS_NAME}"
  if [[ ${?} -eq 0 ]]; then
    echo "ERROR: Found an existing LV for ${VPS_NAME}, exiting ..."
    exit 1
  fi
  lvcreate -yL"${DISK_IN_GB}G" -n "${VPS_NAME}" "${MEMBER_VG}"

  # TODO: add configurable osinfo
  TMPFILE="$(mktemp)"
  cat "${VPS_TEMPLATE}" | sed \
    -e "s,%VPS_NAME%,${VPS_NAME},g" \
    -e "s,%NUM_CORES%,${NUM_CORES},g" \
    -e "s,%MEM_IN_MB%,${MEM_IN_MB},g" \
    -e "s,%SPICE_PORT%,${SPICE_PORT},g" \
    -e "s,%SPICE_PASS%,${SPICE_PASS},g" \
    -e "s,%ISO%,${ISO},g" \
    -e "s,%MEMBER_VG%,${MEMBER_VG},g" \
    -e "s,%UUID%,${UUID},g" \
    -e "s,%MACADDR%,${MACADDR},g" \
    > ${TMPFILE}
  virsh define "${TMPFILE}"
  virsh autostart "${VPS_NAME}"
  rm -f "${TMPFILE}"

  echo "VPS is defined. Installation is up to the user now."
}

# Main script starts here
if [[ "$(whoami)" != 'root' ]]; then
  echo 'ERROR: You need to run this script as root'
  exit 1
fi

if [[ ${#} -ne 2 ]]; then
  help_and_exit
fi
VPS_NAME="${1}"
ISO="${2}"

# Fetch VPS data and create vps
DATA="$(grep "${VPS_NAME}" "${VPS_DATA}")"
OWNER="$(echo ${DATA} | cut -d: -f1)"
ALL_VMS="$(echo ${DATA} | cut -d: -f2)"
for VM in ${ALL_VMS}; do
  VM_NAME="$(echo "${VM}" | cut -d, -f1)"
  NUM_CORES="$(echo "${VM}" | cut -d, -f2)"
  MEM_IN_MB="$(echo "${VM}" | cut -d, -f3)"
  DISK_IN_GB="$(echo "${VM}" | cut -d, -f4)"
  SPICE_PORT="$(echo "${VM}" | cut -d, -f5)"
  SPICE_PASS="$(echo "${VM}" | cut -d, -f6)"

  if [[ "${VM_NAME}" != "${VPS_NAME}" ]]; then
    continue
  fi

  create_vps "${OWNER}" "${VM_NAME}" "${NUM_CORES}" "${MEM_IN_MB}" "${DISK_IN_GB}" "${SPICE_PORT}" "${SPICE_PASS}" "${ISO}"
done
