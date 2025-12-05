#!/bin/bash

# ===========================================
# UNIVERSAL TOOL INSTALLER
# ===========================================

# Warna
G='\e[32m'
R='\e[31m'
C='\e[36m'
Y='\e[33m'
N='\e[0m'

# -------------------------------------------
# Helper: Deteksi arch & install Go 1.25.4
# -------------------------------------------
ensure_go() {
    if command -v go >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${Y}[+] Go belum terinstall, menginstall Go 1.25.4...${N}"

    arch=$(uname -m)
    case "$arch" in
        x86_64)
            GO_FILE="go1.25.4.linux-amd64.tar.gz"
            ;;
        i386|i686)
            GO_FILE="go1.25.4.linux-386.tar.gz"
            ;;
        aarch64)
            GO_FILE="go1.25.4.linux-arm64.tar.gz"
            ;;
        armv6l|armv7l)
            GO_FILE="go1.25.4.linux-armv6l.tar.gz"
            ;;
        *)
            echo -e "${R}[!] Arsitektur tidak dikenal: $arch. Batal install Go.${N}"
            return 1
            ;;
    esac

    GO_URL="https://go.dev/dl/${GO_FILE}"

    echo -e "${Y}[*] Downloading Go dari: ${GO_URL}${N}"
    wget -q "$GO_URL" -O /tmp/go.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${R}[!] Gagal download Go. Cek koneksi internet.${N}"
        return 1
    fi

    echo -e "${Y}[*] Menghapus instalasi Go lama (jika ada)...${N}"
    sudo rm -rf /usr/local/go

    echo -e "${Y}[*] Extract Go ke /usr/local ...${N}"
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz

    # Tambah PATH ke ~/.profile jika belum ada
    if ! grep -q "/usr/local/go/bin" "$HOME/.profile" 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.profile"
    fi

    # Apply untuk session sekarang
    export PATH="$PATH:/usr/local/go/bin"

    if command -v go >/dev/null 2>&1; then
        echo -e "${G}[✓] Go berhasil diinstall: $(go version)${N}"
        return 0
    else
        echo -e "${R}[!] Go masih belum terdeteksi setelah install.${N}"
        return 1
    fi
}

# -------------------------------------------
# Helper: apt install + auto repair
# -------------------------------------------
apt_install_or_fix() {
    local pkg="$1"
    echo -e "${Y}[*] Menginstall paket APT: ${pkg}${N}"
    if sudo apt install -y "$pkg"; then
        return 0
    fi

    echo -e "${R}[!] Gagal install ${pkg}, mencoba perbaikan otomatis...${N}"
    sudo apt --fix-broken install -y || true
    sudo dpkg --configure -a || true
    sudo apt update -y || true

    if sudo apt install -y "$pkg"; then
        echo -e "${G}[✓] Berhasil install ${pkg} setelah perbaikan.${N}"
        return 0
    else
        echo -e "${R}[!] Tetap gagal install ${pkg}. Silakan cek manual.${N}"
        return 1
    fi
}

# -------------------------------------------
# PDTM helper
# -------------------------------------------
ensure_pdtm() {
    ensure_go || return 1
    if ! command -v pdtm >/dev/null 2>&1; then
        echo -e "${Y}[*] Menginstall PDTM...${N}"
        go install -v github.com/projectdiscovery/pdtm/cmd/pdtm@latest
        sudo mv -f "$HOME/go/bin/pdtm" /usr/bin/ 2>/dev/null || true
    fi
    if ! command -v pdtm >/dev/null 2>&1; then
        echo -e "${R}[!] Gagal menyiapkan pdtm.${N}"
        return 1
    fi
    return 0
}

install_pdtm_tool() {
    local name="$1"

    # Naabu dependency khusus
    if [ "$name" = "naabu" ]; then
        apt_install_or_fix libpcap-dev
        apt_install_or_fix nmap
    fi

    ensure_pdtm || return 1
    echo -e "${Y}[*] Menginstall ${name} via pdtm...${N}"
    pdtm -i "$name" || {
        echo -e "${R}[!] Gagal install ${name} via pdtm.${N}"
        return 1
    }
    echo -e "${G}[✓] ${name} via pdtm terinstall.${N}"
}

uninstall_pdtm_tool() {
    local name="$1"
    echo -e "${Y}[*] Menghapus PDTM tool: ${name}${N}"
    rm -f "$HOME/.config/pdtm/bin/$name" 2>/dev/null || true
    echo -e "${G}[✓] Selesai hapus (jika ada).${N}"
}

# -------------------------------------------
# APT tools
# -------------------------------------------
install_apt_tool() {
    local bin="$1"
    local pkg="${2:-$1}"
    if command -v "$bin" >/dev/null 2>&1; then
        echo -e "${G}[✓] ${bin} sudah terinstall${N}"
    else
        apt_install_or_fix "$pkg"
    fi
}

uninstall_apt_tool() {
    local pkg="$1"
    echo -e "${Y}[*] Menghapus paket APT: ${pkg}${N}"
    sudo apt remove --purge -y "$pkg" 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    echo -e "${G}[✓] Selesai hapus (jika ada).${N}"
}

# -------------------------------------------
# GO / other tools
# -------------------------------------------
install_dalfox() {
    if command -v dalfox >/dev/null 2>&1; then
        echo -e "${G}[✓] dalfox sudah ada${N}"
        return
    fi
    ensure_go || return
    echo -e "${Y}[*] Menginstall dalfox...${N}"
    go install github.com/hahwul/dalfox/v2@latest
    sudo mv -f "$HOME/go/bin/dalfox" /usr/bin/ 2>/dev/null || true
    echo -e "${G}[✓] dalfox terinstall${N}"
}

uninstall_dalfox() {
    sudo rm -f /usr/bin/dalfox "$HOME/go/bin/dalfox" 2>/dev/null || true
    echo -e "${G}[✓] dalfox dihapus (jika ada).${N}"
}

install_gf() {
    if command -v gf >/dev/null 2>&1; then
        echo -e "${G}[✓] gf sudah ada${N}"
    else
        ensure_go || return
        go install github.com/tomnomnom/gf@latest
        sudo mv -f "$HOME/go/bin/gf" /usr/bin/ 2>/dev/null || true
    fi

    mkdir -p "$HOME/.gf"
    if [ ! -d "$HOME/tools/Gf-Patterns" ]; then
        git clone https://github.com/1ndianl33t/Gf-Patterns "$HOME/tools/Gf-Patterns" 2>/dev/null || true
    fi
    cp "$HOME/tools/Gf-Patterns"/*.json "$HOME/.gf/" 2>/dev/null || true
    echo -e "${G}[✓] gf + patterns siap${N}"
}

uninstall_gf() {
    sudo rm -f /usr/bin/gf 2>/dev/null || true
    rm -rf "$HOME/.gf" "$HOME/tools/Gf-Patterns" 2>/dev/null || true
    echo -e "${G}[✓] gf + patterns dihapus (jika ada).${N}"
}

install_waybackurls() {
    if command -v waybackurls >/dev/null 2>&1; then
        echo -e "${G}[✓] waybackurls sudah ada${N}"
        return
    fi
    ensure_go || return
    go install github.com/tomnomnom/waybackurls@latest
    sudo mv -f "$HOME/go/bin/waybackurls" /usr/bin/ 2>/dev/null || true
    echo -e "${G}[✓] waybackurls terinstall${N}"
}

uninstall_waybackurls() {
    sudo rm -f /usr/bin/waybackurls "$HOME/go/bin/waybackurls" 2>/dev/null || true
    echo -e "${G}[✓] waybackurls dihapus (jika ada).${N}"
}

install_anew() {
    if command -v anew >/dev/null 2>&1; then
        echo -e "${G}[✓] anew sudah ada${N}"
        return
    fi
    ensure_go || return
    go install github.com/tomnomnom/anew@latest
    sudo mv -f "$HOME/go/bin/anew" /usr/bin/ 2>/dev/null || true
    echo -e "${G}[✓] anew terinstall${N}"
}

uninstall_anew() {
    sudo rm -f /usr/bin/anew "$HOME/go/bin/anew" 2>/dev/null || true
    echo -e "${G}[✓] anew dihapus (jika ada).${N}"
}

install_gau() {
    if command -v gau >/dev/null 2>&1; then
        echo -e "${G}[✓] gau sudah ada${N}"
    else
        ensure_go || return
        go install github.com/lc/gau/v2/cmd/gau@latest
        sudo mv -f "$HOME/go/bin/gau" /usr/bin/ 2>/dev/null || true
    fi

    cat << 'EOF' > "$HOME/.gau.toml"
threads = 2
verbose = false
retries = 15
subdomains = false
parameters = false
providers = ["wayback","commoncrawl","otx","urlscan"]
blacklist = ["ttf","woff","svg","png","jpg"]
json = false

[urlscan]
  apikey = ""

[filters]
  from = ""
  to = ""
  matchstatuscodes = []
  matchmimetypes = []
  filterstatuscodes = []
  filtermimetypes = ["image/png", "image/jpg", "image/svg+xml"]
EOF

    echo -e "${G}[✓] gau + .gau.toml siap${N}"
}

uninstall_gau() {
    sudo rm -f /usr/bin/gau "$HOME/go/bin/gau" "$HOME/.gau.toml" 2>/dev/null || true
    echo -e "${G}[✓] gau + config dihapus (jika ada).${N}"
}

install_paramspider() {
    # venv di ~/venv
    if [ ! -d "$HOME/venv" ]; then
        echo -e "${Y}[*] Membuat virtualenv di ~/venv...${N}"
        python3 -m venv "$HOME/venv"
    fi

    if ! grep -q "alias venv=" "$HOME/.bashrc" 2>/dev/null; then
        echo "alias venv='source ~/venv/bin/activate'" >> "$HOME/.bashrc"
        echo -e "${C}[!] Alias 'venv' ditambahkan ke ~/.bashrc${N}"
    fi

    # install paramspider
    source "$HOME/venv/bin/activate"
    if [ ! -d "$HOME/paramspider" ]; then
        git clone https://github.com/devanshbatham/paramspider "$HOME/paramspider" 2>/dev/null || true
    fi
    cd "$HOME/paramspider" || return
    pip install . >/dev/null 2>&1
    deactivate
    cd "$HOME" || return

    echo -e "${G}[✓] ParamSpider terinstall di venv${N}"
    echo -e "${Y}[!] Jalankan: source ~/.bashrc (sekali saja)${N}"
}

uninstall_paramspider() {
    rm -rf "$HOME/paramspider" "$HOME/venv" 2>/dev/null || true
    sed -i '/alias venv=/d' "$HOME/.bashrc" 2>/dev/null || true
    echo -e "${G}[✓] ParamSpider + venv dihapus (jika ada).${N}"
}

install_feroxbuster() {
    if command -v feroxbuster >/dev/null 2>&1; then
        echo -e "${G}[✓] feroxbuster sudah ada${N}"
        return
    fi
    # coba via snap dulu
    if sudo snap install feroxbuster; then
        echo -e "${G}[✓] feroxbuster berhasil diinstall via snap${N}"
    else
        echo -e "${R}[!] Gagal menginstall feroxbuster via snap, silakan install manual.${N}"
    fi
}

# -------------------------------------------
# Helper: Cek dan tampilkan tools terinstall
# -------------------------------------------
check_installed_tools() {
    local tools_found=0

    # Daftar tools dan perintah untuk mengeceknya
    declare -A tools=(
        ["nmap"]="nmap --version"
        ["masscan"]="masscan --version"
        ["naabu"]="naabu -version"
        ["subfinder"]="subfinder -version"
        ["assetfinder"]="assetfinder --version"
        ["sublist3r"]="sublist3r --help"
        ["dnsutils"]="dig --version"
        ["feroxbuster"]="feroxbuster --version"
        ["john"]="john --version"
        ["hashcat"]="hashcat --version"
        ["gobuster"]="gobuster version"
        ["dirsearch"]="dirsearch --version"
        ["nikto"]="nikto -Version"
        ["wapiti"]="wapiti --version"
        ["zap"]="zap --version"
        ["sqlmap"]="sqlmap --version"
        ["sslyze"]="sslyze --version"
        ["whatweb"]="whatweb --version"
        ["wafw00f"]="wafw00f --version"
        ["httprobe"]="httprobe --help"
        ["httpx"]="httpx -version"
        ["uncover"]="uncover --version"
        ["chaos-client"]="chaos-client --version"
        ["asnmap"]="asnmap --version"
        ["urlfinder"]="urlfinder --help"
        ["proxify"]="proxify --help"
        ["anew"]="anew --help"
        ["paramspider"]="paramspider --help"
    )

    for tool in "${!tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${G}✓${N} $tool"
                    ((tools_found++))
                fi
            done

            if [ $tools_found -eq 0 ]; then
                echo -e "  ${R}Tidak ada tools yang terinstall${N}"
            fi
        }

# -------------------------------------------
# Helper: Cek dan tampilkan tools yang hilang
# -------------------------------------------
check_missing_tools() {
    local tools_missing=0

    # Daftar tools dan perintah untuk mengeceknya
    declare -A tools=(
        ["nmap"]="nmap --version"
        ["masscan"]="masscan --version"
        ["naabu"]="naabu -version"
        ["subfinder"]="subfinder -version"
        ["assetfinder"]="assetfinder --version"
        ["sublist3r"]="sublist3r --help"
        ["dnsutils"]="dig --version"
        ["feroxbuster"]="feroxbuster --version"
        ["john"]="john --version"
        ["hashcat"]="hashcat --version"
        ["gobuster"]="gobuster version"
        ["dirsearch"]="dirsearch --version"
        ["nikto"]="nikto -Version"
        ["wapiti"]="wapiti --version"
        ["zap"]="zap --version"
        ["sqlmap"]="sqlmap --version"
        ["sslyze"]="sslyze --version"
        ["whatweb"]="whatweb --version"
        ["wafw00f"]="wafw00f --version"
        ["httprobe"]="httprobe --help"
        ["httpx"]="httpx -version"
        ["uncover"]="uncover --version"
        ["chaos-client"]="chaos-client --version"
        ["asnmap"]="asnmap --version"
        ["urlfinder"]="urlfinder --help"
        ["proxify"]="proxify --help"
        ["anew"]="anew --help"
        ["paramspider"]="paramspider --help"
    )

    for tool in "${!tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo -e "${R}✗${N} $tool"
                    ((tools_missing++))
                fi
            done

            if [ $tools_missing -eq 0 ]; then
                echo -e "  ${G}Semua tools telah terinstall${N}"
            fi
        }

uninstall_feroxbuster() {
    uninstall_apt_tool feroxbuster
}

# ===========================================
# MAP NOMOR -> AKSI INSTALL / UNINSTALL
# ===========================================
install_by_id() {
    case "$1" in
        # PDTM TOOLS (1-22)
        1) install_pdtm_tool nuclei ;;
        2) install_pdtm_tool httpx ;;
        3) install_pdtm_tool naabu ;;
        4) install_pdtm_tool subfinder ;;
        5) install_pdtm_tool uncover ;;
        6) install_pdtm_tool proxify ;;
        7) install_pdtm_tool urlfinder ;;
        8) install_pdtm_tool asnmap ;;
        9) install_pdtm_tool chaos-client ;;
        10) install_pdtm_tool interactsh-client ;;
        11) install_pdtm_tool interactsh-server ;;
        12) install_pdtm_tool pdtm ;;
        13) install_pdtm_tool vulnx ;;
        14) install_pdtm_tool katana ;;
        15) install_pdtm_tool dnsx ;;
        16) install_pdtm_tool tlsx ;;
        17) install_pdtm_tool mapcidr ;;
        18) install_pdtm_tool tunnelx ;;
        19) install_pdtm_tool cdncheck ;;
        20) install_pdtm_tool cloudlist ;;
        21) install_pdtm_tool tldfinder ;;
        22) install_pdtm_tool shuffledns ;;

        # APT TOOLS (23-44)
        23) install_apt_tool sqlmap sqlmap ;;
        24) install_apt_tool nmap nmap ;;
        25) install_apt_tool wfuzz wfuzz ;;
        26) install_apt_tool whatweb whatweb ;;
        27) install_apt_tool whois whois ;;
        28) install_apt_tool dirsearch dirsearch ;;
        29) install_apt_tool wapiti wapiti ;;
        30) install_apt_tool nikto nikto ;;
        31) install_apt_tool gobuster gobuster ;;
        32) install_apt_tool tcpdump tcpdump ;;
        33) install_apt_tool traceroute traceroute ;;
        34) install_apt_tool aircrack-ng aircrack-ng ;;
        35) install_apt_tool wireshark wireshark ;;
        36) install_apt_tool bluez bluez ;;
        37) install_apt_tool bully bully ;;
        38) install_apt_tool reaver reaver ;;
        39) install_apt_tool apktool apktool ;;
        40) install_apt_tool radare2 radare2 ;;
        41) install_apt_tool yara yara ;;
        42) install_apt_tool binwalk binwalk ;;
        43) install_apt_tool dex2jar dex2jar ;;
        44) install_apt_tool autopsy autopsy ;;

        # APT EXTRA (45-48)
        45) install_apt_tool sublist3r sublist3r ;;
        46) install_apt_tool dnsutils dnsutils ;;
        47) install_apt_tool feroxbuster feroxbuster ;;
        48) install_apt_tool john john ;;
        49) install_apt_tool hashcat hashcat ;;
        50) install_apt_tool exiftool exiftool ;;
        51) install_apt_tool tmux tmux ;;
        52) install_apt_tool netcat-openbsd netcat-openbsd ;;
        53) install_apt_tool hping3 hping3 ;;
        54) install_apt_tool ncat ncat ;;
        55) install_apt_tool sublist3r sublist3r ;;
        56) install_apt_tool dnsutils dnsutils ;;
        57) install_dalfox ;;
        58) install_gf ;;
        59) install_gau ;;
        60) install_waybackurls ;;
        61) install_anew ;;
        62) install_paramspider ;;
        50) install_apt_tool exiftool exiftool ;;
        51) install_apt_tool tmux tmux ;;
        52) install_apt_tool netcat-openbsd netcat-openbsd ;;
        53) install_apt_tool hping3 hping3 ;;
        54) install_apt_tool ncat ncat ;;
        55) install_apt_tool sublist3r sublist3r ;;
        56) install_apt_tool dnsutils dnsutils ;;
        57) install_dalfox ;;
        58) install_gf ;;
        59) install_gau ;;
        60) install_waybackurls ;;
        61) install_anew ;;
        62) install_paramspider ;;

        *)
            echo -e "${R}[!] ID tidak dikenal: $1${N}"
            ;;
    esac
}

uninstall_by_id() {
    case "$1" in
        # PDTM TOOLS
        1) uninstall_pdtm_tool nuclei ;;
        2) uninstall_pdtm_tool httpx ;;
        3) uninstall_pdtm_tool naabu ;;
        4) uninstall_pdtm_tool subfinder ;;
        5) uninstall_pdtm_tool uncover ;;
        6) uninstall_pdtm_tool proxify ;;
        7) uninstall_pdtm_tool urlfinder ;;
        8) uninstall_pdtm_tool asnmap ;;
        9) uninstall_pdtm_tool chaos-client ;;
        10) uninstall_pdtm_tool interactsh-client ;;
        11) uninstall_pdtm_tool interactsh-server ;;
        12) uninstall_pdtm_tool pdtm ;;
        13) uninstall_pdtm_tool vulnx ;;
        14) uninstall_pdtm_tool katana ;;
        15) uninstall_pdtm_tool dnsx ;;
        16) uninstall_pdtm_tool tlsx ;;
        17) uninstall_pdtm_tool mapcidr ;;
        18) uninstall_pdtm_tool tunnelx ;;
        19) uninstall_pdtm_tool cdncheck ;;
        20) uninstall_pdtm_tool cloudlist ;;
        21) uninstall_pdtm_tool tldfinder ;;
        22) uninstall_pdtm_tool shuffledns ;;

        # APT
        23) uninstall_apt_tool sqlmap ;;
        24) uninstall_apt_tool nmap ;;
        25) uninstall_apt_tool wfuzz ;;
        26) uninstall_apt_tool whatweb ;;
        27) uninstall_apt_tool whois ;;
        28) uninstall_apt_tool dirsearch ;;
        29) uninstall_apt_tool wapiti ;;
        30) uninstall_apt_tool nikto ;;
        31) uninstall_apt_tool gobuster ;;
        32) uninstall_apt_tool tcpdump ;;
        33) uninstall_apt_tool traceroute ;;
        34) uninstall_apt_tool aircrack-ng ;;
        35) uninstall_apt_tool wireshark ;;
        36) uninstall_apt_tool bluez ;;
        37) uninstall_apt_tool bully ;;
        38) uninstall_apt_tool reaver ;;
        39) uninstall_apt_tool apktool ;;
        40) uninstall_apt_tool radare2 ;;
        41) uninstall_apt_tool yara ;;
        42) uninstall_apt_tool binwalk ;;
        43) uninstall_apt_tool dex2jar ;;
        44) uninstall_apt_tool autopsy ;;
        45) uninstall_apt_tool sublist3r ;;
        46) uninstall_apt_tool dnsutils ;;
        47) uninstall_apt_tool feroxbuster ;;
        48) uninstall_apt_tool john ;;
        49) uninstall_apt_tool hashcat ;;
        50) uninstall_apt_tool exiftool ;;
        51) uninstall_apt_tool tmux ;;
        52) uninstall_apt_tool netcat-openbsd ;;
        53) uninstall_apt_tool hping3 ;;
        54) uninstall_apt_tool ncat ;;
        55) uninstall_apt_tool sublist3r ;;
        56) uninstall_apt_tool dnsutils ;;
        57) uninstall_dalfox ;;
        58) uninstall_gf ;;
        59) uninstall_gau ;;
        60) uninstall_waybackurls ;;
        61) uninstall_anew ;;
        62) uninstall_paramspider ;;
        50) uninstall_apt_tool exiftool ;;
        51) uninstall_apt_tool tmux ;;
        52) uninstall_apt_tool netcat-openbsd ;;
        53) uninstall_apt_tool hping3 ;;
        54) uninstall_apt_tool ncat ;;

        # GO / PY
        55) uninstall_dalfox ;;
        56) uninstall_gf ;;
        57) uninstall_gau ;;
        58) uninstall_waybackurls ;;
        59) uninstall_anew ;;
        60) uninstall_paramspider ;;
        61) uninstall_feroxbuster ;;

        *)
            echo -e "${R}[!] ID tidak dikenal: $1${N}"
            ;;
    esac
}

install_all() {
    for id in $(seq 1 62); do
        install_by_id "$id"
    done
}

uninstall_all() {
    for id in $(seq 1 62); do
        uninstall_by_id "$id"
    done
}

# ===========================================
# MAIN MENU
# ===========================================
while true; do
    clear
    echo -e "${C}==============================================${N}"
    echo -e "${C}          UNIVERSAL TOOL INSTALLER           ${N}"
    echo -e "${C}==============================================${N}"
    echo
    echo -e "${Y}[PDTM]                 [APT]                     [GO/Python]${N}"
    echo    "  1) nuclei            23) sqlmap               55) dalfox"
    echo    "  2) httpx             24) nmap                 56) gf + patterns"
    echo    "  3) naabu*            25) wfuzz                57) gau + .gau.toml"
    echo    "  4) subfinder         26) whatweb              58) waybackurls"
    echo    "  5) uncover           27) whois               59) anew"
    echo    "  6) proxify           28) dirsearch           60) paramspider (venv)"
    echo    "  7) urlfinder         29) wapiti              61) dalfox"
    echo    "  8) asnmap            30) nikto               62) gf + patterns"
    echo    "  9) chaos-client      31) gobuster            63) gau"
    echo    " 10) interactsh-client 32) tcpdump             64) waybackurls"
    echo    " 11) interactsh-server 33) traceroute          65) feroxbuster"
    echo    " 12) pdtm              34) aircrack-ng         66) sublist3r"
    echo    " 13) vulnx             35) wireshark           67) dnsutils"
    echo    " 14) katana            36) bluez               68) john"
    echo    " 15) dnsx              37) bully               69) hashcat"
    echo    " 16) tlsx              38) reaver              70) exiftool"
    echo    " 17) mapcidr           39) apktool             71) tmux"
    echo    " 18) tunnelx           40) radare2             72) netcat-openbsd"
    echo    " 19) cdncheck          41) yara                73) hping3"
    echo    " 20) cloudlist         42) binwalk             74) ncat"
    echo    " 21) tldfinder         43) dex2jar"
    echo    " 22) shuffledns        44) autopsy"
    echo    " 10) interactsh-client 32) tcpdump"
    echo    " 11) interactsh-server 33) traceroute"
    echo    " 12) pdtm              34) aircrack-ng"
    echo    " 13) vulnx             35) wireshark"
    echo    " 14) katana            36) bluez"
    echo    " 15) dnsx              37) bully"
    echo    " 16) tlsx              38) reaver"
    echo    " 17) mapcidr           39) apktool"
    echo    " 18) tunnelx           40) radare2"
    echo    " 19) cdncheck          41) yara"
    echo    " 20) cloudlist         42) binwalk"
    echo    " 21) tldfinder         43) dex2jar"
    echo    " 22) shuffledns        44) autopsy"
    echo    "                       45) sublist3r"
    echo    "                       46) dnsutils"
    echo    "                       47) feroxbuster"
    echo    "                       48) john"
    echo    "                       49) hashcat"
    echo    "                       50) exiftool"
    echo    "                       51) tmux"
    echo    "                       52) netcat-openbsd"
    echo    "                       53) hping3"
    echo    "                       54) ncat"
    echo    "                       55) sublist3r"
    echo    "                       56) dnsutils"
    echo    "                       57) dalfox"
    echo    "                       58) gf + patterns"
    echo    "                       59) gau"
    echo    "                       60) waybackurls"
    echo    "                       61) anew"
    echo    "                       62) paramspider (venv)"
    echo    "                       50) exiftool"
    echo    "                       51) tmux"
    echo    "                       52) netcat-openbsd"
    echo    "                       53) hping3"
    echo    "                       54) ncat"
    echo
    echo -e "${Y}* naabu requires: libpcap-dev + nmap (auto handled)${N}"
    echo
    echo -e "${C}[OPTIONS]${N}"
    echo    " 63) INSTALL ALL"
    echo    " 64) DELETE (one/multiple)"
    echo    " 65) DELETE ALL"
    echo    "  0) EXIT"
    echo
    read -rp "Pilih (bisa multi, contoh: 1,2,55): " input

    # Exit
    if [ "$input" = "0" ]; then
        exit 0
    fi

    if [ "$input" = "63" ]; then
        install_all
    elif [ "$input" = "64" ]; then
        read -rp "Masukkan ID yang mau dihapus (multi: 1,2,55): " delids
        delids="${delids//,/ }"
        for id in $delids; do
            uninstall_by_id "$id"
        done
    elif [ "$input" = "65" ]; then
        read -rp "Yakin hapus SEMUA tools? (y/n): " ans
        if [[ "$ans" =~ ^[Yy]$ ]]; then
            uninstall_all
        else
            echo "Batal hapus semua."
        fi
    else
        # Multi install
        ids="${input//,/ }"
        for id in $ids; do
            install_by_id "$id"
        done
    fi

    # Tampilkan laporan instalasi
    echo
    echo -e "${C}=== LAPORAN INSTALASI ===${N}"
    echo
    echo -e "${G}Tools yang berhasil terinstall:${N}"
    check_installed_tools
    echo
    echo -e "${R}Tools yang belum terinstall:${N}"
    check_missing_tools

    echo
    echo -e "${C}Tekan ENTER untuk kembali ke menu...${N}"
    read -r
done
