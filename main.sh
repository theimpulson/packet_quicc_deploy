#!/bin/bash

# root setup script is installing byobu, parted, git and zsh

# Add users, and copy public keys
BASEDIR=$(dirname "$0")
for user in $(ls $BASEDIR/keys); do
  useradd -m $user
  usermod -aG sudo $user
  chsh -s /bin/bash $user
  cp -R $BASEDIR/keys/$user/. /home/$user/
  chown -R $user:$user /home/$user
done
sed -i "s/^%sudo/# %sudo/" /etc/sudoers
echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
touch /var/lib/cloud/instance/warnings/.skip

# Initialize disks
uninit_dsks=$(lsblk -r --output NAME,MOUNTPOINT | awk -F \/ '/sd/ { dsk=substr($1,1,3);dsks[dsk]+=1 } END { for ( i in dsks ) { if (dsks[i]==1) print i } }')
dsks=()
for dsk in $uninit_dsks; do
  parted /dev/$dsk --script -- mklabel gpt mkpart primary 0% 100%;
  dsks+=("/dev/${dsk}1")
done;

NVME_DEV="/dev/nvme0n1"
if [ -e "$NVME_DEV" ]; then
  dsks+=("$NVME_DEV")
fi

sleep 5
echo y | mdadm --create --verbose --level=0 --metadata=1.2 --raid-devices=${#dsks[@]} /dev/md/build "${dsks[@]}"
echo 'DEVICE partitions' > /etc/mdadm.conf
mdadm --detail --scan >> /etc/mdadm.conf
mdadm --assemble --scan
mkfs.ext4 /dev/md/build
mkdir -p /raid
mount /dev/md/build /raid

# Populate fstab
RAID_UUID=$(blkid -s UUID -o value /dev/md/build)
echo -e "UUID=${RAID_UUID}\t/raid\text4\trw,relatime,defaults\t0\t1" >> /etc/fstab

chown -R theimpulson:theimpulson /raid

# Android build env setup
git config --global user.email "aayushgupta219@gmail.com"
git config --global user.name "Aayush Gupta"
