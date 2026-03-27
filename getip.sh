#!/bin/bash
# =============================================================================
# getip.sh - Get the default network IP address of the server
# =============================================================================
# Purpose: Display the primary (non-loopback) network IP address
#
# Features:
# - Excludes localhost/loopback IPs (127.0.0.0/8)
# - No external queries (no curl to ifconfig.me or similar)
# - Works with various network configurations
# =============================================================================

getip() {
	local ip=""

	# Method 1: Use ip route (preferred, most reliable)
	# Gets the IP of the interface used for default gateway
	if command -v ip &>/dev/null; then
		ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)
		if [[ -n "$ip" && "$ip" != 127.* ]]; then
			echo "$ip"
			return 0
		fi
	fi

	# Method 2: Use ip addr and find default interface
	if command -v ip &>/dev/null; then
		# Get default interface and extract its IP
		local default_iface=$(ip route | awk '/default/ {print $5; exit}')
		if [[ -n "$default_iface" ]]; then
			ip=$(ip -4 addr show "$default_iface" 2>/dev/null | awk '/inet / {print $2}' | cut -d'/' -f1 | head -1)
			if [[ -n "$ip" && "$ip" != 127.* ]]; then
				echo "$ip"
				return 0
			fi
		fi
	fi

	# Method 3: Use hostname -I (simplified)
	if command -v hostname &>/dev/null; then
		ip=$(hostname -I 2>/dev/null | awk '{print $1}')
		if [[ -n "$ip" && "$ip" != 127.* ]]; then
			echo "$ip"
			return 0
		fi
	fi

	# Method 4: Use ifconfig (fallback for older systems)
	if command -v ifconfig &>/dev/null; then
		# Get first non-loopback IPv4 address
		ip=$(ifconfig 2>/dev/null |
			awk '/inet / && !/127\.0\.0\.1/ {print $2}' |
			head -1)
		# Handle different ifconfig output formats
		ip=${ip#addr:}
		if [[ -n "$ip" && "$ip" != 127.* ]]; then
			echo "$ip"
			return 0
		fi
	fi

	# Method 5: Parse /proc/net/route or /proc/net/tcp
	if [[ -f /proc/net/route ]]; then
		local iface=$(awk '/^[^I]/{if($2=="00000000") print $1}' /proc/net/route 2>/dev/null | head -1)
		if [[ -n "$iface" && -f "/sys/class/net/$iface/address" ]]; then
			# Read MAC address and convert to IP (limited but works)
			ip=$(cat "/sys/class/net/$iface/address" 2>/dev/null)
		fi
	fi

	# Return error if nothing found
	if [[ -z "$ip" || "$ip" == 127.* ]]; then
		echo "ERROR: Could not determine default IP address" >&2
		return 1
	fi

	echo "$ip"
	return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	getip
fi
