#!/usr/bin/env bash

###############
# PREPARATION #
###############

#[CONSOLE]
#KEYBOARD LAYOUT
#localectl list-keymaps | grep be
loadkeys be-latin1

#FONT SIZE
#location /sys/share/kbd/consolefonts/
setfont ter-v24n

#[INTERNET CONNECTION]
#LAN
#ip link

#WIFI
#iwctl (through iwd.service)
#[iwd] device list
#[iwd] device [name|adatper] set-property Prowered on
#[iwd] station name scan
#[iwd] station name get-networks
#[iwd] station name [connect|connect-hidden] SSID
wifipass=
ssid=
read -p "Enter SSID: " ssid
read -p "Enter WiFi passphrase: " -s wifipass
iwctl --passphrase $wifipass station name connect $ssid
wifipass=
ssid=

ping -c www.archlinux.org

#[SSH]
systemctl start sshd
#root passwd
passwd

#[SYSTEM CLOCK]
timedatectl set-timezone Europe/Brussels
timedatectl set-ntp true
#timedatectl list-timezones | grep Brussel
timedatectl status

#[SHOW IP FOR SSH]
ip a #get ip and log in into the other computer

#-------------------------------------------------------

#################
# CONFIGURATION #
#################

#ssh root@ip_address

#[DISKS]
lsblk -f #identify disk to use
read -p "Enter disk name to use (/dev/[disk_name]): " disk

#wiping all on disk
wipefs -af $disk
sgdisk --zap-all --clear $disk
partprobe $disk

#Overwrite existing data with random values
cryptsetup open --type plain -d /dev/urandom $disk cryptarget #target is temporary for writting random data
dd if=/dev/zero of=/dev/mapper/cryptarget oflag=direct bs=1M status=progress
cryptsetup close cryptarget

# creation of the partitions
#[Command]: o #create new empty partition table
#[Command]: Y
#[Command]: n #create new partion
#[Command]: #partition number
#[Command]: #partition first sector
#[Command]: +1G #partition last sector (size of the partition)
#[Command]: ef00 #partition code EFI system partition

sgdisk -n 1:0:+512MiB -t 1:ef00 -c 1:ESP -n 2:0:0 -t 2:8309 -c 2:LUKS $disk

#[Command]: n #create new partion
#[Command]: #partition number
#[Command]: #partition first sector
#[Command]: #partition last sector (size of the partition)
#[Command]: #partition code Linux filesystem
#[Command]: w #write gpt data
#[Command]: Y

# formatting partitions
#[LUKS]
cryptsetup luksFormat /dev/disk_partition_name #(p2)
#YES
#Enter passphrase for disk encryption
cryptsetup luksOpen /dev/disk_partition_name cryptroot
#Enter passphrase for disk encryption
mkfs.btrfs /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
cd /mnt
btrfs subvolume create @
btrfs subvolume create @home
cd
unmount /mnt

mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@ /dev/mapper/cryptroot /mnt
mkdir /mnt/home
mount -o noatime,ssd,compress=zstd,space_cache=v2,discard=async,subvol=@home /dev/mapper/cryptroot /mnt/home
mkfs.fat -F32 /dev/disk_partition_name #(p1)
mkdir /mnt/boot
mount /dev/disk_partition_name /mnt/boot

#[PACMAN]
#/etc/pacman.conf
#[multilib]

#[MIRROR LIST]
reflector -c Belgium -a 12 --sort rate --save /etc/pacman.d/mirrorlist

#[PACKAGES]
pacstrap /mnt base base-devel linux linux-headers linux-firmware btrfs-progs lvm2 intel-ucode git vim

#[FSTAB]
genfstab -U -p /mnt >> /mnt/etc/fstab

#[STEP INTO SYSTEM]
arch-chroot /mnt

#------------------------------------------------------------------------------------------------------------

######################
# POST-CONFIGURATION #
######################

#[DEPENDENCIES]
pacman -S sudo grub grub-btrfs efibootmgr networkmanager openssh iptables-nft ipset firewalld acpid polkit reflector man-db man-pages texinfo bluez bluez-utils pipewire alsa-utils pipewire-pulse pipewire-jack ttf-meslo-nerd alacritty firefox
#NVIDIA, add: nvidia-dkms nvidia-utils lib32-nvidia-utils egl-wayland

#[LOCALE]
ln -sF /usr/share/zoneinfo/Europe/Brussels /etc/localtime
hwclock --systohc
vim /etc/locale.gen #=> uncomment fr_BE.UTF-8
locale-gen
echo "LANG=fr_BE.UTF-8" >> /etc/locale.conf

#[HOSTNAME]
echo "arch" >> /etc/hostname
#/etc/hosts
#replace hostname with new hostname on localdomain

#[ROOTUSER]
passwd

#[USER]
useradd -m -g users -G wheel blondi
passwd blondi
echo "blondi ALL=(ALL) ALL" >> /etc/sudoers.d/blondi

#[MKINITCPIO]
vim /etc/mkinitcpio.conf
#MODULES=(btrfs)
#=> if nvidia, add also after btrfs nvidia nvidia_modeset nvidia_uvm nvidia_drm
#HOOKS=( ... encrypt lvm2 filesystems ... )
mkinitcpio -p linux

#[GRUB]
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
blkid /dev/disk_partition_name #GET UUID
vim /etc/default/grub
#GRUB_CMDLINE_LINUX_DEFAULT= ... cryptdevice=UUID=uuidnumbers:cryptroot root=dev/mapper/cryptroot"
grub-mkconfig -o /boot/grub/grub.cfg

#[SERVICES]
systemctl enable NetworkManager
#systemctl enable bluetooth
#systemctl enable sshd
#systemctl enable firewalld
#systemctl enable reflector.timer
#systemctl enable fstrim.timer
#systemctl enable acpid

#------------------------------------------------------------------------------------------------

#[YAY]
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

#[ZRAM]
yay -S zramd
sudo systemctl enable --now zramd.service
lsblk #should see zram there

sudo vim /etc/default/zramd #change max_size=16384

#[AUTO CPU FREQ]
yay -S auto-cpufreq
sudo systemctl enable --now auto-cpufreq.service

#[TIMESHIFT]
yay -S timeshift timeshift-autosnap
sudo timeshift --create --comments "[message]" --tags D

sudo systemctl edit --full grub-btrfsd
#ExecStart= ... remove /.snapshot and replace with "-t"
sudo grub-mkconfig -o /boot/grub/grub.cfg

sudo pacman -S gnome
sudo systemctl enable gdm

#[ENV for HYPRLAND config]
#env = LIBVA_DRIVER_NAME,nvidia
#env = __GLX_VENDOR_LIBRARY_NAME,nvidia