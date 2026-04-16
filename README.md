# 📞 Asterisk 22.9.0 — Prebuilt for aarch64 (Debian 13 Trixie)

![Platform](https://img.shields.io/badge/arch-aarch64%20%7C%20ARM64-blue)
![OS](https://img.shields.io/badge/OS-Debian%2013%20(Trixie)-red)
![Asterisk](https://img.shields.io/badge/Asterisk-22.9.0-green)
![Status](https://img.shields.io/badge/status-stable-brightgreen)
![License](https://img.shields.io/badge/license-GPLv2-lightgrey)

---

## ✨ Overview

Prebuilt **Asterisk 22.9.0** binary for **ARM64 / aarch64** devices running **Debian 14.2.0-19**.  
Optimized for low-resource devices like **Raspberry Pi 3**.

---

## 📦 Download

👉 **Download packages:**
- [Releases](https://github.com/asterisk/asterisk/releases/latest)
  
👉 **Install script:**
- [install.sh](install.sh)

---

## 🤔 Why this exists

Building Asterisk 22 on a Pi 3 requires two non-obvious fixes:

### 1. pjproject endianness bug

The bundled pjproject fails to detect little-endian on aarch64.

**Fix:**
```c
#define PJ_IS_LITTLE_ENDIAN 1
```

📍 On File:
```c
pjlib/include/pj/config.h
```
---

### 2. Low RAM constraints

Raspberry Pi 3 has only **1GB RAM**, so build requires:

- ✅ 2GB swapfile  
- ✅ `-j1` for pjproject  
- ✅ `-j2` for main Asterisk build  

---

## ⚙️ Build flags

```bash
./configure \
  --with-pjproject-bundled \
  --with-jansson-bundled \
  --with-libjwt-bundled \
  --disable-xmldoc \
  CFLAGS="-O1 -pipe -fno-strict-aliasing -g0"
```

---

## 🚀 Quick Install

```bash
sudo bash install.sh
```

---

## 📚 Included Modules

### 📡 Channel
- chan_pjsip

### 🔗 PJSIP
- res_pjsip  
- res_pjsip_session  
- res_pjsip_registrar  
- res_pjsip_outbound_registration  
- res_pjsip_nat  
- res_pjsip_logger  
- res_pjsip_transport_websocket  

### 📶 RTP / SRTP
- res_rtp_asterisk  
- res_srtp  

### 🎧 Codecs
- ulaw  
- alaw  
- gsm  
- opus  
- g722  

### 📞 Applications
- app_dial  
- app_playback  
- app_voicemail  

---

## 🧪 Tested Hardware

| Device           | OS               | Kernel   | Status     |
|------------------|------------------|----------|------------|
| Raspberry Pi 3   | Debian 14.2.0-19 | 6.12.47  | ✅ Working |

---

## 👨‍💻 Author

**Beng Rafik**  
- GitHub: https://github.com/RafikBeng


---

## 📜 License

Asterisk is licensed under **GPLv2**.

🔗 Full license: [LICENSE](LICENSE)

🔗 Asterisk project:
- https://www.asterisk.org/

---
