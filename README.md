# `8b-nektar` DJ App — Nektar Impact LX25+ Sovereign Hardware Bridge

> **"the 1.58-bit lane :: add and add and add until the order does not matter"**  
> *Hardware Bridge for Nektar Impact LX25+ (USB 0x2467:0x2016) ⋈ 8b-is-music Quant65k+ (69,632 Layers)*

---

## 1. Hardware Overview

- **Device**: Nektar Impact LX25+
- **USB Bus**: 12 Mbps Full-Speed USB Composite Device (`VendorID: 9319 / 0x2467`, `ProductID: 8214 / 0x2016`)
- **Control Topology**:
  - **8 Velocity-Sensitive Drum Pads**: Notes `36..43` (`C1..G1`) mapped to 4 DJ Decks + Quantum/Zeno Triggers.
  - **8 360° Continuous Encoders**: CC `14..21` mapped to 5-Band Liquid Time-Constant (LTC) EQ (`60Hz, 250Hz, 1kHz, 4kHz, 12kHz`) + Quant65k+ Shimmer + IOuQT Trit Density + Spatial Stereo Pan.
  - **1 30mm Master Pitch/Volume Fader**: CC `11` / CC `7` mapped to Zeno Paradox Asymptotic Brickwall Limiter (`0.999985`).
  - **Transport & DAW Integration**: Cycle (`CC 113`), Rewind (`CC 114`), Forward (`CC 115`), Stop (`CC 116`), Play (`CC 117`), Record (`CC 118`).

---

## 2. CoreMIDI Virtual Ports

The app establishes full duplex CoreMIDI virtual endpoints:
- **`8b-is Nektar DJ Virtual In`**: Ingestion port for pads, faders, and encoders from the Impact LX25+ hardware and virtual MIDI routers.
- **`8b-is Nektar DJ Virtual Out`**: Feedback port transmitting LED state, deck cue feedback, and waveform sync.

---

## 3. Running the App

```bash
cd /Users/peterlodri/workspace/peterlodri-sec/8b-nektar
./8b-nektar-dj
```
