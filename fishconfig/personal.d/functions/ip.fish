function ip --description "Show public and/or private IP addresses"
    argparse 'h/help' 'p/public' 'l/private' -- $argv
    or return 1

    if set -q _flag_help
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
    end

    # Just public IP
    if set -q _flag_public
        echo (curl -s ipinfo.io/ip)
        return
    end

    # Just private IP
    if set -q _flag_private
        __ip_private
        return
    end

    # Default: show both with formatting
    set -l public (curl -s ipinfo.io/ip)
    set -l private (__ip_private)

    set_color cyan
    printf " \uf0ac  "
    set_color brblack
    printf "Public   "
    set_color normal
    echo $public

    set_color yellow
    printf " \uf015  "
    set_color brblack
    printf "Private  "
    set_color normal
    echo $private
end

function __ip_private --description "Get private IP address"
    # macOS: try common interfaces
    if type -q ipconfig
        for iface in en0 en1 en2 en3
            set -l addr (ipconfig getifaddr $iface 2>/dev/null)
            if test -n "$addr"
                echo $addr
                return
            end
        end
    end

    # Linux fallback
    if type -q hostname
        hostname -I 2>/dev/null | awk '{print $1}'
        return
    end

    echo "unknown"
end
