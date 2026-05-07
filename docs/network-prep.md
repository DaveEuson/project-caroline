# Network Prep: Static IP and SSH

Caroline works best when the server has a stable address on your home network. That keeps the browser URL, Google OAuth notes, SSH access, and troubleshooting commands predictable.

## Best Option: Router Reservation

Use your router's DHCP reservation feature if you can. This is safer than editing Linux network files because the router keeps giving the same IP to the same device.

1. Find the Caroline device in your router's client/device list.
2. Copy its MAC address.
3. Add a DHCP reservation, such as `192.168.1.50`.
4. Reboot the Caroline device.
5. Confirm the IP:

```bash
hostname -I
```

Then open Caroline from another browser:

```text
http://DEVICE-IP:8080/
```

## Enable SSH on Raspberry Pi OS

### During Imaging

In Raspberry Pi Imager:

1. Click the gear icon or **Edit settings**.
2. Set hostname, username, password, Wi-Fi if needed, and locale.
3. Enable **SSH**.
4. Write the card and boot the Pi.

### After Boot

On the Pi:

```bash
sudo raspi-config
```

Go to **Interface Options > SSH > Enable**.

Or run:

```bash
sudo systemctl enable --now ssh
```

Connect from another machine:

```bash
ssh USERNAME@DEVICE-IP
```

## Enable SSH on Ubuntu Server

Ubuntu Server often offers OpenSSH during install. If you skipped it:

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
```

Check the IP:

```bash
hostname -I
```

Connect:

```bash
ssh USERNAME@DEVICE-IP
```

## OS-Level Static IP

Prefer router reservation. If you must set the static IP on the device, make sure you know:

- Desired IP address
- Gateway/router IP
- DNS server
- Network interface name

On Ubuntu Server, use Netplan. First find the interface:

```bash
ip link
```

Then edit the Netplan file:

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```

Example:

```yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 192.168.1.50/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

Apply it:

```bash
sudo netplan apply
```

If the device disappears from the network, plug in a keyboard/monitor and revert the file, or use your router DHCP reservation instead.

## Security Notes

- Do not port-forward Caroline, Node-RED, or SSH to the public internet.
- Use strong passwords or SSH keys.
- Keep Caroline on your LAN, or use a VPN such as Tailscale/WireGuard for remote access.
- Caroline URLs should look like `http://192.168.x.x:8080/`, `http://10.x.x.x:8080/`, or another private LAN address.
