# Build
gh workflow run build-disk.yml --ref main -f platform=amd64 -f upload-to-s3=false

# Watch job
gh run watch job_id --exit-status

# Run test VM
qemu-system-x86_64 -enable-kvm -m 8G -smp 4 \
  -cdrom /home/liana/blueberry/output/artifact/bootiso/install.iso \
  -drive file=/tmp/blueberry-test.qcow2,format=qcow2,if=virtio \
  -netdev user,id=n0 -device virtio-net,netdev=n0 -vga virtio
