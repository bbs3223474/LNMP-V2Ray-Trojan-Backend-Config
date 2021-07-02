#!/bin/sh
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
sudo add-apt-repository ppa:danielrichter2007/grub-customizer -y
sudo apt-get update
sudo apt-get install figlet
sudo apt-get install pv
sudo apt-get install cgpt
sudo apt-get install gparted
sudo apt-get install grub-customizer
sudo gparted
sudo figlet -c "SUBSCRIBE TO"
sudo figlet -c Kedar
sudo figlet -c Nimbalkar
sudo echo https://www.youtube.com/user/kedar123456889
echo "Please enter partition name for Chrome OS multi boot install. For e.g. sda5";
read partition
sudo sfdisk -l /dev/$partition
size=$(sudo fdisk -l /dev/$partition | awk '$1=="Disk" && $2 ~ /^\/dev\/.*/ {print int($3)}')
while true; do
    read -p "Do you wish to format and install chrome os on $partition?(type yes to continue)" yn
    case $yn in
        [Yy]* ) echo "Ok, Proceeding installation on $partition";
                mkdir -p ~/tmpmount;
                sudo mount /dev/$partition ~/tmpmount;
                sudo bash chromeos-install.sh -src rammus_recovery.bin -dst ~/tmpmount/chromos.img -s $size;
                sudo umount ~/tmpmount;
				echo "Copy the above grub menu entry in grub customizer";
                sudo grub-customizer;
		rm -f .multi_installer.sh;
                break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
else
    echo "You are Offline. Please connect to the internet before running installation"
    rm -f .multi_installer.sh
fi
