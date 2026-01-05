
# IP 

| Nom             | Adresse IP    | Rôle          |
|-----------------|---------------|---------------|
| controlplane-01 | 192.168.25.50 | Control Plane |
| controlplane-02 | 192.168.25.51 | Control Plane |
| controlplane-03 | 192.168.25.52 | Control Plane |
| worker-01       | 192.168.25.60 | Worker        |
| worker-02       | 192.168.25.61 | Worker        |


# Génération config 

```bash
talosctl gen config boud-labs-talos https://192.168.25.50:6443 --with-secrets ./secrets.yaml

# Apply a patch to config 

talosctl gen config boud-labs-talos https://192.168.25.50:6443 --config-patch @patch.yaml --with-secrets ./secrets.yaml
```

# Start ISO wihout seeding 

Boot WM on iso

Press e on the boot time. And set the IP parameters for the VM

```
ip=<client-ip>:<server-ip>:<gw-ip>:<netmask>:<hostname>:<device>:<autoconf>:<dns0-ip>:<dns1-ip>:<ntp0-ip>

ip=192.168.25.50::192.168.25.1:255.255.255.0:master01:S:false:8.8.8.8:1.1.1.1:d

ip=192.168.25.50::192.168.25.1:255.255.255.0:master01:eth0:off:8.8.8.8:1.1.1.1
ip=192.168.25.51::192.168.25.1:255.255.255.0:master01:eth0:off:8.8.8.8:1.1.1.1ta
ip=192.168.25.52::192.168.25.1:255.255.255.0:master01:eth0:off:8.8.8.8:1.1.1.1

ip=192.168.25.60::192.168.25.1:255.255.255.0:master01:eth0:off:8.8.8.8:1.1.1.1
ip=192.168.25.61::192.168.25.1:255.255.255.0:master01:eth0:off:8.8.8.8:1.1.1.1
```

Verify 

```bash
talosctl get disks --insecure --nodes 192.168.25.50
NODE   NAMESPACE   TYPE   ID      VERSION   SIZE     READ ONLY   TRANSPORT   ROTATIONAL   WWID   MODEL           SERIAL
       runtime     Disk   loop0   2         4.1 kB   true
       runtime     Disk   loop1   2         696 kB   true
       runtime     Disk   loop2   2         475 kB   true
       runtime     Disk   loop3   2         73 MB    true
       runtime     Disk   sda     2         107 GB   false       virtio                          QEMU HARDDISK
       runtime     Disk   sr0     2         306 MB   false       sata                            QEMU DVD-ROM

```

```bash
# Appliquer la configuration sur les nœuds controlplane
talosctl apply-config --insecure -n 192.168.25.50 --file controlplane.yaml
talosctl apply-config --insecure -n 192.168.25.51 --file controlplane.yaml
talosctl apply-config --insecure -n 192.168.25.52 --file controlplane.yaml

# Appliquer la configuration sur les nœuds worker
talosctl apply-config --insecure -n 192.168.25.60 --file worker.yaml
talosctl apply-config --insecure -n 192.168.25.61 --file worker.yaml
```

# Promox Cloud Init 

# Bootstrap kuberntes 

```bash
talosctl bootstrap -e 192.168.25.50 --talosconfig ./talosconfig  --nodes 192.168.25.50
# Get kubeconfig 
$ talosctl kubeconfig -e 192.168.25.50 --talosconfig ./talosconfig  --nodes 192.168.25.50
```

# Troobleshooting kuberntes 

Logs 
```bash
talosctl.exe dmesg --talosconfig=./talosconfig  -e 192.168.25.50 -n 192.168.25.50
```

# Install CNI -> Cilium 

```bash
cilium install \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set securityContext.capabilities.ciliumAgent="{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}" \
    --set securityContext.capabilities.cleanCiliumState="{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}" \
    --set cgroup.autoMount.enabled=false \
    --set cgroup.hostRoot=/sys/fs/cgroup \
    --set k8sServiceHost=localhost \
    --set k8sServicePort=7445 \
    --set gatewayAPI.enabled=true \
    --set gatewayAPI.enableAlpn=true \
    --set gatewayAPI.enableAppProtocol=true
```

Verification 

```bash
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
master01   Ready    control-plane   20m   v1.34.0
master02   Ready    control-plane   20m   v1.34.0
master03   Ready    control-plane   11m   v1.34.0
worker01   Ready    <none>          20m   v1.34.0
worker02   Ready    <none>          20m   v1.34.0


kubectl get pod -n kube-system
NAME                               READY   STATUS    RESTARTS      AGE
cilium-2zk7j                       1/1     Running   0             13h
cilium-envoy-hfn4q                 1/1     Running   0             13h
cilium-envoy-n5vd2                 1/1     Running   0             13h
cilium-envoy-qmg7j                 1/1     Running   0             13h
cilium-envoy-vplwm                 1/1     Running   0             13h
cilium-envoy-zhcfr                 1/1     Running   0             13h
cilium-ggsxl                       1/1     Running   0             13h
cilium-operator-f4576477c-rnnt7    1/1     Running   0             13h
cilium-r896t                       1/1     Running   0             13h
cilium-xds98                       1/1     Running   0             13h
cilium-z9ljv                       1/1     Running   0             13h
coredns-7bb49dc74c-64m5n           1/1     Running   0             13h
coredns-7bb49dc74c-9z8w9           1/1     Running   0             13h
kube-apiserver-master01            1/1     Running   0             13h
kube-apiserver-master02            1/1     Running   0             13h
kube-apiserver-master03            1/1     Running   0             13h
kube-controller-manager-master01   1/1     Running   3 (13h ago)   13h
kube-controller-manager-master02   1/1     Running   0             13h
kube-controller-manager-master03   1/1     Running   0             13h
kube-scheduler-master01            1/1     Running   3 (13h ago)   13h
kube-scheduler-master02            1/1     Running   0             13h
kube-scheduler-master03            1/1     Running   0             13h

```

# Définir les endpoint dans la talos config

```bash
talosctl --talosconfig=./talosconfig config endpoint 192.168.25.50 192.168.25.51 192.168.25.52 # Control plane
talosctl --talosconfig=./talosconfig config node 192.168.25.50 192.168.25.51 192.168.25.52 192.168.25.60 192.168.25.61 # controle plane + nodes
talosctl config merge ./talosconfig
```