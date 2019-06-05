systemctl stop docker
cp -au /var/lib/docker /var/lib/docker.bk

echo '{ "storage-driver": "overlay2" }' > /etc/docker/daemon.json

systemctl start docker