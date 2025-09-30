# Voir les disques (tu dois voir xvda et xvdb)
lsblk -f

# Vérifier que xvdb a un FS XFS
sudo file -s /dev/xvdb     # doit contenir "XFS filesystem data"

# Le point de montage doit exister et être monté
mount | grep /data || true
df -h | grep /data || true

# Vérifier l’entrée persistante dans /etc/fstab
grep /dev/xvdb /etc/fstab || true
