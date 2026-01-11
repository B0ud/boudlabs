# Proxmox Template Creation Guide

This guide details how to manually create a Debian 13 (Trixie) Cloud-Init capable template on Proxmox. This template is required for the HAProxy automation.

## Debian 13 (Trixie) Template

**Template ID**: `9001`
**Name**: `debian-13-trixie-template`

### 1. Connect to Proxmox
Open a shell on your Proxmox node (via SSH or the Web Console).

### 2. Download the Image
Download the latest Debian 13 "Generic Cloud" image (Trixie).
> [!IMPORTANT]
> Do NOT use the `nocloud` image as it may lack the `cloud-init` package. Use `genericcloud` instead.

```bash
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2
```

### 3. Create the VM
Create a new VM with the ID `9001`.
```bash
qm create 9001 --name "debian-13-trixie-template" --memory 2048 --net0 virtio,bridge=vmbr1
```

### 4. Import the Disk
Import the downloaded QCOW2 image into the local storage.
```bash
qm importdisk 9001 debian-13-genericcloud-amd64.qcow2 local --format qcow2
```

### 5. Attach the Disk
Attach the imported disk to the VM as a SCSI drive.
```bash
qm set 9001 --scsihw virtio-scsi-pci --scsi0 local:9001/vm-9001-disk-0.qcow2
```

### 6. Configure Boot & Cloud-Init
Set the boot order and attach the Cloud-Init drive.
```bash
qm set 9001 --boot c --bootdisk scsi0
qm set 9001 --ide2 local:cloudinit
```

### 7. Configure Display
Set the display to standard VGA and enable the serial console (useful for logs).
```bash
qm set 9001 --serial0 socket --vga std
```

### 8. Convert to Template
Finalize the setup by converting the VM to a template.
```bash
qm template 9001
```

### 9. Cleanup
Remove the downloaded image to save space.
```bash
rm debian-13-genericcloud-amd64.qcow2
```

---
> [!NOTE]
> Once this template is created, Terraform can clone it to provision the HAProxy VM.
