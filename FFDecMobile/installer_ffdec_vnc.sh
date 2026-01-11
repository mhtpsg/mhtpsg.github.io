#!/bin/bash

# ========================================
# FFDec VNC Installer untuk Termux
# Auto installer lengkap dari awal sampai akhir
# ========================================

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk print dengan warna
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${GREEN}"
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo -e "${NC}"
}

# Fungsi untuk menunggu input user
wait_for_input() {
    echo -e "${YELLOW}Tekan Enter untuk melanjutkan...${NC}"
    read
}

# Fungsi untuk cek apakah command berhasil dengan retry
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1 berhasil!"
        return 0
    else
        print_error "$1 gagal!"
        return 1
    fi
}

# Fungsi untuk install package dengan retry
install_package() {
    local package=$1
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Mencoba install $package (attempt $attempt/$max_attempts)..."
        
        if pkg install $package -y; then
            print_success "$package berhasil diinstall!"
            return 0
        else
            print_warning "$package gagal diinstall, mencoba lagi..."
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    print_error "$package gagal diinstall setelah $max_attempts percobaan"
    return 1
}

# Mulai instalasi
clear
print_header "FFDec VNC Installer untuk Termux"
print_info "Script ini akan menginstall FFDec dengan VNC di Termux"
print_info "Pastikan Anda terhubung ke internet"
print_warning "Proses ini membutuhkan waktu 15-30 menit tergantung kecepatan internet"
wait_for_input

# ========================================
# STEP 1: Setup Storage Permission
# ========================================
print_header "STEP 1: Setup Storage Permission"
print_info "Memberikan izin akses storage..."

if ! command -v termux-setup-storage &> /dev/null; then
    print_warning "termux-setup-storage tidak ditemukan, menginstall termux-api..."
    pkg install termux-api -y
fi

termux-setup-storage
check_success "Setup storage permission"

sleep 2

# ========================================
# STEP 2: Fix and Update Termux
# ========================================
print_header "STEP 2: Fix and Update Termux"
print_info "Membersihkan cache dan fixing repositories..."

# Clean cache
pkg clean
rm -rf $PREFIX/var/lib/apt/lists/*

print_info "Updating Termux repositories..."
pkg update -y

if [ $? -ne 0 ]; then
    print_warning "Update gagal, mencoba fix repositories..."
    
    # Try to change repo
    if command -v termux-change-repo &> /dev/null; then
        print_info "Silakan pilih mirror terdekat..."
        termux-change-repo
    else
        print_warning "termux-change-repo tidak tersedia, lanjut dengan repo default"
    fi
    
    pkg update -y
fi

print_info "Upgrading packages..."
pkg upgrade -y
check_success "Update Termux"

# ========================================
# STEP 3: Install Dependencies
# ========================================
print_header "STEP 3: Install Dependencies"
print_info "Menginstall wget, proot, dan git..."

# Install wget
install_package "wget"

# Install proot with multiple methods
print_info "Menginstall proot dengan multiple methods..."

# Method 1: Install proot-distro first (lebih reliable)
if ! command -v proot &> /dev/null; then
    print_info "Method 1: Install proot-distro..."
    install_package "proot-distro"
fi

# Method 2: Direct proot install
if ! command -v proot &> /dev/null; then
    print_info "Method 2: Direct proot install..."
    install_package "proot"
fi

# Method 3: Install additional repos
if ! command -v proot &> /dev/null; then
    print_warning "Mencoba dengan additional repositories..."
    pkg install x11-repo -y
    pkg install root-repo -y
    pkg update -y
    install_package "proot"
fi

# Verify proot
if command -v proot &> /dev/null; then
    print_success "Proot berhasil diinstall!"
    proot --version
else
    print_error "Proot gagal diinstall dengan semua metode!"
    print_info "Akan menggunakan proot-distro sebagai alternatif..."
    
    if ! command -v proot-distro &> /dev/null; then
        print_error "proot-distro juga tidak tersedia. Instalasi dibatalkan."
        exit 1
    fi
    
    USE_PROOT_DISTRO=true
    print_success "Akan menggunakan proot-distro method"
fi

# Install git dan curl
install_package "git"
install_package "curl"

# ========================================
# STEP 4: Create FFDecAndroid Folder
# ========================================
print_header "STEP 4: Create FFDecAndroid Folder"
print_info "Membuat folder FFDecAndroid di storage internal..."

FFDEC_FOLDER="/storage/emulated/0/FFDecAndroid"
mkdir -p "$FFDEC_FOLDER"
check_success "Buat folder FFDecAndroid"

# ========================================
# STEP 5: Download FFDec
# ========================================
print_header "STEP 5: Download FFDec"
print_info "Downloading FFDec 22.0.2..."

cd "$FFDEC_FOLDER"
if [ ! -f "ffdec_22.0.2.deb" ]; then
    wget https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version22.0.2/ffdec_22.0.2.deb
    
    if [ $? -ne 0 ]; then
        print_warning "wget gagal, mencoba dengan curl..."
        curl -L -o ffdec_22.0.2.deb https://github.com/jindrapetrik/jpexs-decompiler/releases/download/version22.0.2/ffdec_22.0.2.deb
    fi
    
    check_success "Download FFDec"
else
    print_success "FFDec sudah ada, skip download"
fi

# ========================================
# STEP 6: Setup Ubuntu/Debian in Termux
# ========================================
print_header "STEP 6: Setup Linux in Termux"

cd ~

if [ "$USE_PROOT_DISTRO" = true ]; then
    print_info "Menggunakan proot-distro method (Debian)..."
    
    # Install Debian
    proot-distro install debian
    check_success "Install Debian via proot-distro"
    
    # Create start script
    cat > ~/start_linux.sh << 'EOF'
#!/bin/bash
proot-distro login debian
EOF
    chmod +x ~/start_linux.sh
    
    LINUX_START_CMD="bash ~/start_linux.sh"
    LINUX_TYPE="debian"
    
else
    print_info "Menggunakan ubuntu-in-termux method..."
    
    if [ ! -d "ubuntu-in-termux" ]; then
        git clone https://github.com/MFDGaming/ubuntu-in-termux.git
        check_success "Clone ubuntu-in-termux"
    else
        print_success "ubuntu-in-termux sudah ada"
    fi
    
    cd ubuntu-in-termux
    chmod +x ubuntu.sh
    check_success "Berikan permission ubuntu.sh"
    
    print_info "Menjalankan instalasi Ubuntu... (ini akan memakan waktu lama)"
    ./ubuntu.sh -y
    check_success "Instalasi Ubuntu"
    
    LINUX_START_CMD="cd ~/ubuntu-in-termux && ./startubuntu.sh"
    LINUX_TYPE="ubuntu"
fi

# ========================================
# STEP 7: Create Ubuntu Setup Script
# ========================================
print_header "STEP 7: Create Linux Setup Script"
print_info "Membuat script setup untuk Linux..."

cat > setup_linux_ffdec.sh << 'EOF'
#!/bin/bash

# Setup script untuk Linux
echo "=========================================="
echo "Setting up Linux environment for FFDec"
echo "=========================================="

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install desktop environment
echo "Installing XFCE desktop environment..."
apt install -y xfce4 xfce4-goodies dbus-x11

# Install VNC server
echo "Installing TigerVNC server..."
apt install -y tigervnc-standalone-server

# Install Java
echo "Installing Java JDK..."
apt install -y default-jdk

# Install additional tools
echo "Installing additional tools..."
apt install -y nano htop wget curl

# Setup VNC
echo "Setting up VNC server..."
mkdir -p ~/.vnc

# Create VNC startup script
cat > ~/.vnc/xstartup << 'VNCEOF'
#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-$(id -u)
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
xrdb $HOME/.Xresources 2>/dev/null
startxfce4 &
VNCEOF

chmod +x ~/.vnc/xstartup

# Install FFDec
echo "Installing FFDec..."
cd /sdcard/FFDecAndroid || cd /storage/emulated/0/FFDecAndroid
dpkg -i ffdec_22.0.2.deb
apt --fix-broken install -y

# Create FFDec launcher script
cat > ~/start_ffdec.sh << 'LAUNCHEREOF'
#!/bin/bash
echo "Starting VNC Server..."
vncserver :1 -geometry 1280x720 -localhost no

echo ""
echo "=========================================="
echo "VNC Server started successfully!"
echo "=========================================="
echo "Connect with VNC Viewer using:"
echo "Address: localhost:5901"
echo ""
echo "Commands:"
echo "  - Stop VNC: vncserver -kill :1"
echo "  - Start FFDec: ffdec"
echo "=========================================="
LAUNCHEREOF

chmod +x ~/start_ffdec.sh

# Create stop VNC script
cat > ~/stop_vnc.sh << 'STOPEOF'
#!/bin/bash
echo "Stopping VNC server..."
vncserver -kill :1
echo "VNC server stopped."
STOPEOF

chmod +x ~/stop_vnc.sh

echo ""
echo "=========================================="
echo "Linux setup completed!"
echo "=========================================="
echo "Run: bash ~/start_ffdec.sh"
echo "=========================================="
EOF

chmod +x setup_linux_ffdec.sh
check_success "Buat script setup Linux"

# ========================================
# STEP 8: Create Main Launcher Scripts
# ========================================
print_header "STEP 8: Create Launcher Scripts"
print_info "Membuat script launcher utama..."

# Script untuk masuk ke Linux normal
if [ "$USE_PROOT_DISTRO" = true ]; then
    cat > ~/start_linux.sh << 'EOF'
#!/bin/bash
echo "Starting Debian..."
proot-distro login debian
EOF
else
    cat > ~/start_linux.sh << 'EOF'
#!/bin/bash
cd ~/ubuntu-in-termux
echo "Starting Ubuntu..."
./startubuntu.sh
EOF
fi

chmod +x ~/start_linux.sh

# Script launcher FFDec
cat > ~/ffdec_launcher.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "FFDec VNC Launcher"
echo "=========================================="
echo "1. Start Linux with FFDec VNC"
echo "2. Start Linux (manual)"
echo "3. Exit"
echo ""
read -p "Pilih opsi [1-3]: " choice

case $choice in
    1)
        echo "Starting Linux and FFDec VNC..."
        bash ~/start_linux.sh -c "bash ~/start_ffdec.sh; bash" || bash ~/start_linux.sh
        ;;
    2)
        echo "Starting Linux manually..."
        bash ~/start_linux.sh
        ;;
    3)
        echo "Keluar..."
        exit 0
        ;;
    *)
        echo "Pilihan tidak valid"
        ;;
esac
EOF

chmod +x ~/ffdec_launcher.sh

# ========================================
# STEP 9: Final Setup
# ========================================
print_header "STEP 9: Final Setup"
print_info "Menjalankan setup Linux..."

if [ "$USE_PROOT_DISTRO" = true ]; then
    print_info "Setup di Debian..."
    proot-distro login debian -- bash -c "
        cd /root
        cp /data/data/com.termux/files/home/setup_linux_ffdec.sh ~/
        bash ~/setup_linux_ffdec.sh
    "
else
    print_info "Setup di Ubuntu..."
    cd ~/ubuntu-in-termux
    
    # Copy script
    cp ~/setup_linux_ffdec.sh ~/ubuntu-fs/root/setup_linux_ffdec.sh 2>/dev/null
    
    # Jalankan setup
    print_warning "Ini akan memakan waktu lama, mohon bersabar..."
    
    ./startubuntu.sh -c "bash ~/setup_linux_ffdec.sh"
fi

check_success "Setup Linux dengan FFDec"

# ========================================
# INSTALLATION COMPLETED
# ========================================
clear
print_header "INSTALASI SELESAI!"

echo -e "${GREEN}"
echo "=========================================="
echo "FFDec VNC berhasil diinstall!"
echo "=========================================="
echo -e "${NC}"

print_info "Files yang dibuat:"
echo "  • ~/ffdec_launcher.sh - Script launcher utama"
echo "  • ~/start_linux.sh - Start Linux manual"
echo "  • /storage/emulated/0/FFDecAndroid/ - Folder FFDec"

echo ""
print_info "Cara penggunaan:"
echo "  1. Jalankan: ${YELLOW}bash ~/ffdec_launcher.sh${NC}"
echo "  2. Pilih opsi 1 untuk start VNC"
echo "  3. Buka VNC Viewer di Android"
echo "  4. Connect ke: ${YELLOW}localhost:5901${NC}"
echo "  5. Di desktop XFCE, buka terminal dan ketik: ${YELLOW}ffdec${NC}"

echo ""
print_info "Commands berguna di Linux:"
echo "  • ${YELLOW}ffdec${NC}                 - Start FFDec"
echo "  • ${YELLOW}vncserver :1${NC}          - Start VNC server"
echo "  • ${YELLOW}vncserver -kill :1${NC}    - Stop VNC server"
echo "  • ${YELLOW}bash ~/start_ffdec.sh${NC} - Auto start VNC"
echo "  • ${YELLOW}bash ~/stop_vnc.sh${NC}    - Stop VNC"

echo ""
print_warning "PENTING:"
echo "  • Install VNC Viewer dari Play Store/F-Droid"
echo "  • Saat pertama kali start VNC, Anda akan diminta membuat password"
echo "  • Password ini digunakan untuk koneksi VNC Viewer"
echo "  • Linux type: ${LINUX_TYPE}"

echo ""
print_success "Instalasi selesai! Selamat mencoba! 🎉"

# Optional: Auto start launcher
echo ""
read -p "Apakah Anda ingin langsung menjalankan FFDec launcher? (y/n): " auto_start
if [[ $auto_start =~ ^[Yy]$ ]]; then
    bash ~/ffdec_launcher.sh
fi
