#!/bin/bash

# TODO: add support for multiple vm's

DESCRIPTION="Libvirt multiuser shell v0.1"

VPS_DATA='vps.data'
VIRSH='sudo virsh'
ISO_DIR='/var/lib/libvirt/images'
CDROM_DEVICE='sda'

function toggle_autostart {
	MY_VPS="${1}"

	${VIRSH} list --autostart --name | grep -q "${MY_VPS}"
	if [[ ${?} -eq 0 ]]; then
		${VIRSH} autostart ${MY_VPS} --disable
	else
		${VIRSH} autostart ${MY_VPS}
	fi
}

function run_status {
	MY_VPS="${1}"
	sudo virsh list --all | egrep "^Id|^-|${MY_VPS}"
}

function run_start {
	MY_VPS="${1}"
	sudo virsh start "${MY_VPS}"
}

function run_shutdown {
	MY_VPS="${1}"
	sudo virsh shutdown "${MY_VPS}"
}

function run_reset {
	MY_VPS="${1}"
	sudo virsh reset "${MY_VPS}"
}

function run_reboot {
	MY_VPS="${1}"
	sudo virsh reboot "${MY_VPS}"
}

function run_attach_iso {
	MY_VPS="${1}"

	echo "== The following iso images are available for installation:"
	sudo find "${ISO_DIR}" -type f -name \*.iso | sed -e "s,${ISO_DIR}/,,g"
	echo ""
	echo -n "Your choice: "
	read ISO_FNAME

	# TODO: Add security checks
	ISO="${ISO_DIR}/${ISO_FNAME}"
	if [[ ! -f "${ISO}" ]]; then
		echo "ERROR: ${ISO_FNAME} does not exist"
		return
	fi

	${VIRSH} change-media "${MY_VPS}" "${CDROM_DEVICE}" --update "${ISO}"
}

function run_detach_iso {
  MY_VPS="${1}"

  CURRENT="$(${VIRSH} domblklist ${MY_VPS} | awk '/^sda/{ print $2 }')"
	if [[ "${CURRENT}" != '-' ]]; then
		${VIRSH} change-media "${MY_VPS}" "${CDROM_DEVICE}" --update
	fi
}

function show_console_info {
  MY_VPS="${1}"
  SPICE_PORT="${2}"
  SPICE_PASS="${3}"

  cat <<EOF

You can connect to the console of your VPS by first setting up a ssh tunnel towards $(hostname -s) for your console
port, after which you can use your favourite SPICE client to connect to the console.

The following details are configured for ${MY_VPS}:

host:     127.0.0.1
port:     ${SPICE_PORT}
password: ${SPICE_PASS}

EOF
}

function show_help {
	MY_VPS="${1}"
	cat <<EOF
${DESCRIPTION}

Your actions will apply to ${MY_VPS}

autostart   Toggle autostarting on boot of hypervisor
status      Show the status for your vps
start       Start your vps
shutdown    Shutdown your vps
reset       Reset your vps
reboot      Reboot your vps
attach_iso  Attach an iso to your vps
detach_iso  Eject an iso from your vps
console     Show information for connecting to the console of your vps
help        Show this help
quit        Disconnect from this session
EOF
}

# Main script starts here
if [[ -z "${USER}" ]]; then
	echo "ERROR: USER cannot be empty"
	exit 1
fi

MY_VPS="$(grep "^${USER}:" "${VPS_DATA}" | awk -F: '{ print $2 }' | awk -F, '{ print $1 }')"
if [[ -z "${MY_VPS}" ]]; then
	echo "ERROR: You dont have any registered vps"
	exit 1
fi
SPICE_PORT="$(grep "^${USER}:" "${VPS_DATA}" | awk -F: '{ print $2 }' | awk -F, '{ print $5 }')"
SPICE_PASS="$(grep "^${USER}:" "${VPS_DATA}" | awk -F: '{ print $2 }' | awk -F, '{ print $6 }')"

show_help ${MY_VPS}

while :; do
	echo -n ">>> "
	read ANSWER
	COMMAND="$(echo "${ANSWER}" | awk '{ print $1 }')"
	ARGS="$(echo "${ANSWER}" | awk '{ print $2 }')"
	case "${COMMAND}" in
		"autostart")
			toggle_autostart "${MY_VPS}"
			;;
		"status")
			run_status "${MY_VPS}"
			;;
		"start")
			run_start "${MY_VPS}"
			;;
		"shutdown")
			run_shutdown "${MY_VPS}"
			;;
		"reboot")
			run_reboot "${MY_VPS}"
			;;
		"reset")
			run_reset "${MY_VPS}"
			;;
		"attach_iso")
			run_attach_iso "${MY_VPS}"
			;;
	  "detach_iso")
	    run_detach_iso "${MY_VPS}"
	    ;;
	  "console")
	    show_console_info "${MY_VPS}" "${SPICE_PORT}" "${SPICE_PASS}"
	    ;;
		"help")
			show_help
			;;
		"quit")
			break
			;;
	esac
done
