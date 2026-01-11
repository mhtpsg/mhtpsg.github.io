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

# Fungsi untuk cek apakah command berhasil
check_success() {
    if [ $? -eq 0 ]; then
        print_success "$1 berhasil!"
    else
        print_error "$1 gagal!"
        exit 1
    fi
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
# STEP 2: Update Termux
# ========================================
print_header "STEP 2: Update Termux"
print_info "Updating dan upgrading Termux..."

apt-get update && apt-get upgrade -y
check_success "Update Termux"

# ========================================
# STEP 3: Install Dependencies
# ========================================
print_header "STEP 3: Install Dependencies"
print_info "Menginstall wget, proot, dan git..."

apt-get install wget -y
check_success "Install wget"

apt-get install proot -y
check_success "Install proot"

apt-get install git -y
check_success "Install git"

apt-get install curl -y
check_success "Install curl"

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
    check_success "Download FFDec"
else
    print_success "FFDec sudah ada, skip download"
fi

# ========================================
# STEP 6: Setup Ubuntu in Termux
# ========================================
print_header "STEP 6: Setup Ubuntu in Termux"
print_info "Downloading dan setup Ubuntu..."

cd ~
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

# ========================================
# STEP 7: Create Ubuntu Setup Script
# ========================================
print_header "STEP 7: Create Ubuntu Setup Script"
print_info "Membuat script setup untuk Ubuntu..."

cat > setup_ubuntu_ffdec.sh << 'EOF'
#!/bin/bash

# Setup script untuk Ubuntu
echo "=========================================="
echo "Setting up Ubuntu environment for FFDec"
echo "=========================================="

# Update Ubuntu
echo "Updating Ubuntu..."
apt update && apt upgrade -y

# Install desktop environment
echo "Installing XFCE desktop environment..."
apt install xfce4 xfce4-goodies -y

# Install VNC server
echo "Installing TigerVNC server..."
apt install tigervnc-standalone-server -y

# Install Java
echo "Installing Java JDK..."
apt install default-jdk -y

# Install additional tools
echo "Installing additional tools..."
apt install nano htop -y

# Setup VNC
echo "Setting up VNC server..."
mkdir -p ~/.vnc

# Create VNC startup script
cat > ~/.vnc/xstartup << 'VNCEOF'
#!/bin/bash
xrdb $HOME/.Xresources 2>/dev/null
startxfce4 &
VNCEOF

chmod +x ~/.vnc/xstartup

# Install FFDec
echo "Installing FFDec..."
cd /sdcard/FFDecAndroid
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
echo "To stop VNC server, run: vncserver -kill :1"
echo "To start FFDec in GUI, run: ffdec"
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
echo "Ubuntu setup completed!"
echo "=========================================="
echo "Run './start_ffdec.sh' to start VNC server"
echo "Run './stop_vnc.sh' to stop VNC server"
echo "=========================================="
EOF

chmod +x setup_ubuntu_ffdec.sh
check_success "Buat script setup Ubuntu"

# ========================================
# STEP 8: Create Main Launcher Scripts
# ========================================
print_header "STEP 8: Create Launcher Scripts"
print_info "Membuat script launcher utama..."

# Script untuk masuk ke Ubuntu dan setup
cat > ~/start_ubuntu_setup.sh << 'EOF'
#!/bin/bash
cd ~/ubuntu-in-termux
echo "Starting Ubuntu and running setup..."
./startubuntu.sh -c "bash ~/setup_ubuntu_ffdec.sh"
EOF

chmod +x ~/start_ubuntu_setup.sh

# Script untuk masuk ke Ubuntu normal
cat > ~/start_ubuntu.sh << 'EOF'
#!/bin/bash
cd ~/ubuntu-in-termux
echo "Starting Ubuntu..."
./startubuntu.sh
EOF

chmod +x ~/start_ubuntu.sh

# Script launcher FFDec
cat > ~/ffdec_launcher.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "FFDec VNC Launcher"
echo "=========================================="
echo "1. Start Ubuntu with FFDec VNC"
echo "2. Start Ubuntu (manual)"
echo "3. Exit"
echo ""
read -p "Pilih opsi [1-3]: " choice

case $choice in
    1)
        echo "Starting Ubuntu and FFDec VNC..."
        cd ~/ubuntu-in-termux
        ./startubuntu.sh -c "bash ~/start_ffdec.sh; bash"
        ;;
    2)
        echo "Starting Ubuntu manually..."
        cd ~/ubuntu-in-termux
        ./startubuntu.sh
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

# Copy setup script ke Ubuntu
print_info "Copying setup script ke Ubuntu..."
cp setup_ubuntu_ffdec.sh ~/ubuntu-fs/root/setup_ubuntu_ffdec.sh 2>/dev/null || true

# ========================================
# STEP 9: Final Setup
# ========================================
print_header "STEP 9: Final Setup"
print_info "Menjalankan setup Ubuntu..."

cd ~/ubuntu-in-termux

# Jalankan setup di Ubuntu
print_info "Masuk ke Ubuntu dan menjalankan setup otomatis..."
print_warning "Ini akan memakan waktu lama, mohon bersabar..."

./startubuntu.sh -c "
cd /root
apt update && apt upgrade -y
apt install xfce4 xfce4-goodies tigervnc-standalone-server default-jdk nano htop -y
mkdir -p ~/.vnc

cat > ~/.vnc/xstartup << 'VNCEOF'
#!/bin/bash
xrdb \$HOME/.Xresources 2>/dev/null
startxfce4 &
VNCEOF

chmod +x ~/.vnc/xstartup

cd /sdcard/FFDecAndroid
dpkg -i ffdec_22.0.2.deb
apt --fix-broken install -y

cat > ~/start_ffdec.sh << 'LAUNCHEREOF'
#!/bin/bash
echo \"Starting VNC Server...\"
vncserver :1 -geometry 1280x720 -localhost no

echo \"\"
echo \"===========================================\"
echo \"VNC Server started successfully!\"
echo \"===========================================\"
echo \"Connect with VNC Viewer using:\"
echo \"Address: localhost:5901\"
echo \"\"
echo \"To stop VNC server, run: vncserver -kill :1\"
echo \"To start FFDec in GUI, run: ffdec\"
echo \"===========================================\"
LAUNCHEREOF

chmod +x ~/start_ffdec.sh

cat > ~/stop_vnc.sh << 'STOPEOF'
#!/bin/bash
echo \"Stopping VNC server...\"
vncserver -kill :1
echo \"VNC server stopped.\"
STOPEOF

chmod +x ~/stop_vnc.sh

echo \"Ubuntu setup completed!\"
"

check_success "Setup Ubuntu dengan FFDec"

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
echo "  • ~/start_ubuntu.sh - Start Ubuntu manual"
echo "  • /storage/emulated/0/FFDecAndroid/ - Folder FFDec"

echo ""
print_info "Cara penggunaan:"
echo "  1. Jalankan: bash ~/ffdec_launcher.sh"
echo "  2. Pilih opsi 1 untuk start VNC"
echo "  3. Buka VNC Viewer di Android"
echo "  4. Connect ke: localhost:5901"
echo "  5. Di desktop XFCE, buka terminal dan ketik: ffdec"

echo ""
print_info "Commands berguna di Ubuntu:"
echo "  • ffdec                 - Start FFDec"
echo "  • vncserver :1          - Start VNC server"
echo "  • vncserver -kill :1    - Stop VNC server"
echo "  • bash ~/start_ffdec.sh - Auto start VNC"
echo "  • bash ~/stop_vnc.sh    - Stop VNC"

echo ""
print_warning "PENTING:"
echo "  • Install VNC Viewer dari Play Store/F-Droid"
echo "  • Saat pertama kali start VNC, Anda akan diminta membuat password"
echo "  • Password ini digunakan untuk koneksi VNC Viewer"

echo ""
print_success "Instalasi selesai! Selamat mencoba! 🎉"

# Optional: Auto start launcher
echo ""
read -p "Apakah Anda ingin langsung menjalankan FFDec launcher? (y/n): " auto_start
if [[ $auto_start =~ ^[Yy]$ ]]; then
    bash ~/ffdec_launcher.sh
fi
