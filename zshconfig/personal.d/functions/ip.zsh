# Show public and/or private IP addresses
function __ip_private {
  # macOS: try common interfaces
  if (( $+commands[ipconfig] )); then
    local iface addr
    for iface in en0 en1 en2 en3; do
      addr=$(ipconfig getifaddr "$iface" 2>/dev/null)
      if [[ -n "$addr" ]]; then
        echo "$addr"
        return
      fi
    done
  fi

  # Linux fallback
  if (( $+commands[hostname] )); then
    hostname -I 2>/dev/null | awk '{print $1}'
    return
  fi

  echo "unknown"
}

function ip {
  case "$1" in
    -h|--help)
      echo "Usage: ip [OPTIONS]"
      echo ""
      echo "Show public and/or private IP addresses."
      echo ""
      echo "Options:"
      echo "  -p, --public   Show only public IP"
      echo "  -l, --private  Show only private IP"
      echo "  -h, --help     Show this help message"
      echo ""
      echo "With no options, displays both public and private IPs."
      return 0
      ;;
    -p|--public)
      curl -s ipinfo.io/ip
      echo
      return
      ;;
    -l|--private)
      __ip_private
      return
      ;;
  esac

  # Default: show both with formatting
  local public private
  public=$(curl -s ipinfo.io/ip)
  private=$(__ip_private)

  print -P "%F{cyan} \uf0ac  %F{8}Public   %f$public"
  print -P "%F{yellow} \uf015  %F{8}Private  %f$private"
}
