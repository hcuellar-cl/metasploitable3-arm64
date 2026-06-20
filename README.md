# Metasploitable 3 ARM64 Port for macOS (UTM / Apple Virtualization)

This repository contains the scripts and configurations required to build, deploy, and provision a **100% functional Metasploitable 3 (Linux variant) Virtual Machine natively on Apple Silicon (M1/M2/M3/M4/M5)**.

Instead of emulating the entire guest OS using slow QEMU translation, this port leverages native **Apple Virtualization** to run an Ubuntu Server ARM64 VM at host-speed, while using user-space emulation (`qemu-user-static`) exclusively for the few legacy x86_64 CTF binaries.

---

## Technical Enhancements & Fixes in this Port

To make the legacy Metasploitable 3 recipes run on a modern Ubuntu ARM64 environment, the following fixes were implemented:
1. **x86_64 Emulation Support:** Enabled multiarch support (`amd64`), installed emulation libraries, and integrated Bionic's legacy `libssl1.0.0` and `zlib` for `amd64`.
2. **Tanuki Java Service Wrapper Symlink:** Fixed Apache Continuum startup failures by routing the legacy x86_64 wrapper through QEMU transparently.
3. **Ruby 2.7 conversions Patch:** Patched the Rails `readme_app` boot sequence to resolve the `SystemStackError` caused by `Fixnum` and `Bignum` recursion in newer Ruby runtimes.
4. **Bypass challenge loader:** Configured the Sinatra service to execute `server.rb` directly via Ruby, bypassing the Crystal challenge loader which relies on the original x86 VM's `/etc/passwd` MD5 hash.
5. **Network Interface Autodetection:** Configured `knockd` to dynamically detect the VM's active network interface (such as `enp0s1` under Apple Virtualization) instead of hardcoding `eth0`.
6. **Chatbot Service Adaptations:** Migrated the Node.js Chatbot service to a modern Systemd `forking` service that executes the custom background scripts correctly.

---

## Project Structure

* [download_assets.sh](download_assets.sh) - Host script that pulls all legacy source code archives and packages them.
* [provision_arm.sh](provision_arm.sh) - Guest script that compiles, configures, and deploys all vulnerable services.
* [deploy_to_vm.sh](deploy_to_vm.sh) - Host wrapper that automates packaging, uploading, and executing the provisioner.
* [audit_services.sh](audit_services.sh) - Auditing tool to verify all ports and services inside the VM.
* `configs/` - Local configuration templates for services, firewall, and CTF cards.

---

## Getting Started

### Prerequisites
1. A Mac with Apple Silicon (M-series chip).
2. [UTM](https://mac.getutm.app/) installed.
3. An [Ubuntu Server 20.04 LTS ARM64](http://cdimage.ubuntu.com/releases/focal/release/) virtual machine configured with Apple Virtualization and Shared Network (NAT).

### Installation
Clone this repository to your host Mac and navigate into it:
```bash
git clone https://github.com/hcuellar-cl/metasploitable3-arm64.git
cd metasploitable3-arm64
```

### Configuration (`utm.env`)
Create a file named `utm.env` in the root of the project on your host Mac. Note that the values below are an example, and you must replace them with the actual settings configured when installing your Ubuntu ARM virtual machine (making sure the SSH server is enabled):
```env
UTM_HOST_IP=192.168.64.29
UTM_USER=msfadmin
UTM_PASSWORD=msfadmin
UTM_SSH_PORT=22
```

### Deployment
Run the automated deployment script from your Mac terminal:
```bash
chmod +x deploy_to_vm.sh
./deploy_to_vm.sh
```


---

## Service & Vulnerability Audit

Once provisioning completes, you can log in to the VM and run the auditing tool:
```bash
sudo ./audit_services.sh
cat metasploitable_audit.txt
```

This will confirm that all 12 services (ProFTPD, Apache, Samba, UnrealIRCd, Rails, Sinatra, Continuum, Node Chatbot, Five of Diamonds, etc.) are active, listening on their respective ports, and configured with the original CTF cards.

---

## Comparison Table: Metasploitable 3 ARM64 vs. Metasploitable 3 Vagrant (Original)

| Feature / Component | Metasploitable 3 Vagrant (Original) | Metasploitable 3 ARM64 (This Port) |
| :--- | :--- | :--- |
| **Architecture** | Native `x86_64` (Intel/AMD) | Native `ARM64` (Apple Silicon) + `qemu-user-static` for legacy x86_64 binaries. |
| **Virtualization Engine** | VirtualBox / VMware | UTM / Apple Virtualization Framework (natively optimized on macOS). |
| **Host System Compatibility** | Designed for Intel/AMD Macs and PCs. | Designed specifically for Apple Silicon Macs (M1/M2/M3/M4/M5). |
| **Guest Operating System** | Ubuntu 14.04 LTS (Trusty Tahr - EOL) | Ubuntu Server 20.04 LTS (Focal Fossa - ARM64). |
| **Compilation Approach** | Uses pre-packaged binaries or Chef recipes. | Compiles core services (PHP, UnrealIRCd, ProFTPD) natively from source for ARM64. |
| **Ruby Version & Patches** | Legacy Ruby (2.3/2.4) | Ruby 2.7 (Patched boot sequence to fix `Fixnum`, `Bignum`, and `BigDecimal.new` errors). |
| **Sinatra App Execution** | Executed via Crystal loader/wrapper. | Bypasses Crystal loader to execute `server.rb` directly via Ruby (eliminating host hash mismatches). |
| **Network Interface** | Hardcoded to `eth0` in configuration templates. | Dynamically autodetect active interface (e.g., `enp0s1`) for `knockd` and firewall configuration. |
| **Service Manager** | Upstart / SysVinit | Systemd (Modernized service files for Apache, ProFTPD, Rails, Sinatra, Chatbot, etc.). |
| **Overall Performance** | Extremely slow when emulated on Apple Silicon. | Native performance with minimal overhead. |

