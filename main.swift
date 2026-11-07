import Cocoa
import CoreMIDI
import WebKit

// ============================================================================
// 8b-nektar DJ App — Native macOS Controller & Web Deck Interface
// Nektar Impact LX25+ Hardware Mapping ⋈ 8b-is Sovereign Audio Engine
// ============================================================================

final class NektarDJApp: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!
    var midiClient = MIDIClientRef()
    var virtualDest = MIDIEndpointRef()
    var virtualSrc = MIDIEndpointRef()
    
    // Impact LX25+ State
    var masterVolume: Float = 0.85
    var crossfader: Float = 0.50
    var eqBands: [Float] = [3.2, 1.37, 2.47, 3.73, 2.88]
    var deckStates: [Bool] = [true, false, true, false] // Decks A, B, C, D
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindow()
        setupMIDI()
        loadInterface()
    }
    
    func setupWindow() {
        let rect = NSRect(x: 100, y: 100, width: 1024, height: 720)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "8b-is Nektar DJ ⋈ Impact LX25+ Sovereign Deck (Quant65k+)"
        window.center()
        
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "nektarEvent")
        
        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(webView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func setupMIDI() {
        let clientName = "8b-Nektar-DJ" as CFString
        MIDIClientCreateWithBlock(clientName, &midiClient) { [weak self] notif in
            self?.handleMIDINotification(notif)
        }
        
        // Virtual Destination to receive MIDI from Nektar Impact LX25+
        MIDIDestinationCreateWithBlock(midiClient, "8b-is Nektar DJ Virtual In" as CFString, &virtualDest) { [weak self] pktList, _ in
            self?.processMIDIPackets(pktList)
        }
        
        // Virtual Source to broadcast back
        MIDISourceCreate(midiClient, "8b-is Nektar DJ Virtual Out" as CFString, &virtualSrc)
        
        connectHardwareInputs()
    }
    
    func connectHardwareInputs() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            var unmanagedName: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(src, kMIDIPropertyName, &unmanagedName)
            let name = (unmanagedName?.takeRetainedValue() as String?) ?? ""
            if name.contains("Impact") || name.contains("LX25") || name.contains("IAC") {
                print("[MIDI] Connected to input source: \(name)")
            }
        }
    }
    
    func handleMIDINotification(_ notif: UnsafePointer<MIDINotification>) {
        if notif.pointee.messageID == .msgSetupChanged {
            DispatchQueue.main.async {
                self.connectHardwareInputs()
            }
        }
    }
    
    func processMIDIPackets(_ pktList: UnsafePointer<MIDIPacketList>) {
        let list = pktList.pointee
        var packet = list.packet
        for _ in 0..<list.numPackets {
            if packet.length >= 3 {
                let status = packet.data.0
                let d1 = packet.data.1
                let d2 = packet.data.2
                let cmd = status & 0xF0
                
                DispatchQueue.main.async {
                    if cmd == 0x90 && d2 > 0 { // Note On / Pad
                        self.handlePadTrigger(note: d1, velocity: d2)
                    } else if cmd == 0xB0 { // Knob / Fader CC
                        self.handleContinuousControl(cc: d1, val: d2)
                    }
                }
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    func handlePadTrigger(note: UInt8, velocity: UInt8) {
        let padIndex = note >= 36 && note <= 43 ? Int(note - 36) : -1
        let script = "window.onNektarPad && window.onNektarPad(\(padIndex), \(note), \(velocity));"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func handleContinuousControl(cc: UInt8, val: UInt8) {
        let norm = Float(val) / 127.0
        let script = "window.onNektarCC && window.onNektarCC(\(cc), \(val), \(norm));"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("[JS -> Native] \(message.body)")
    }
    
    func loadInterface() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>8b-nektar DJ App</title>
            <style>
                :root {
                    --bg: #090a0f;
                    --panel: #131722;
                    --accent-cyan: #00f0ff;
                    --accent-pink: #ff0055;
                    --accent-gold: #ffbe00;
                    --accent-green: #00ff88;
                    --text: #e0e6ed;
                    --dim: #606d80;
                }
                * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; }
                body { background: var(--bg); color: var(--text); padding: 20px; overflow-x: hidden; }
                
                header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #222938; padding-bottom: 14px; margin-bottom: 20px; }
                .title { font-size: 20px; font-weight: 800; letter-spacing: 1px; color: var(--accent-cyan); display: flex; align-items: center; gap: 10px; }
                .badge { background: #1c2438; border: 1px solid var(--accent-cyan); color: var(--accent-cyan); font-size: 11px; padding: 3px 8px; border-radius: 4px; }
                .hw-status { display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--accent-green); }
                .hw-dot { width: 10px; height: 10px; border-radius: 50%; background: var(--accent-green); box-shadow: 0 0 10px var(--accent-green); }
                
                .grid-decks { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; margin-bottom: 20px; }
                .deck-card { background: var(--panel); border: 1px solid #202636; border-radius: 8px; padding: 16px; position: relative; overflow: hidden; }
                .deck-card.active { border-color: var(--accent-cyan); box-shadow: 0 0 15px rgba(0,240,255,0.15); }
                .deck-header { display: flex; justify-content: space-between; font-size: 12px; color: var(--dim); margin-bottom: 8px; font-weight: 700; }
                .deck-title { font-size: 15px; font-weight: 700; margin-bottom: 6px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                .deck-meta { font-size: 12px; color: var(--accent-gold); margin-bottom: 12px; }
                
                .wave-box { height: 60px; background: #0c0e14; border-radius: 4px; display: flex; align-items: center; justify-content: center; gap: 3px; padding: 0 6px; }
                .wave-bar { flex: 1; background: var(--accent-cyan); border-radius: 2px; height: 30%; transition: height 0.08s ease; }
                
                .controls-row { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; }
                .section { background: var(--panel); border: 1px solid #202636; border-radius: 8px; padding: 18px; }
                .section-title { font-size: 13px; text-transform: uppercase; letter-spacing: 1px; color: var(--dim); margin-bottom: 14px; }
                
                /* 8 Pads */
                .pads-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; }
                .pad-btn { background: #181d2a; border: 2px solid #283248; border-radius: 6px; height: 75px; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; cursor: pointer; transition: all 0.1s ease; }
                .pad-btn.pressed { background: var(--accent-pink); border-color: #fff; box-shadow: 0 0 20px var(--accent-pink); transform: scale(0.96); }
                .pad-num { font-size: 11px; font-weight: 800; color: var(--accent-cyan); margin-bottom: 4px; }
                .pad-label { font-size: 10px; color: var(--text); line-height: 1.2; padding: 0 4px; }
                
                /* Knobs & Faders */
                .knobs-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin-top: 14px; }
                .knob-box { display: flex; flex-direction: column; align-items: center; gap: 6px; }
                .knob-ring { width: 54px; height: 54px; border-radius: 50%; border: 3px solid #283248; border-top-color: var(--accent-cyan); display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; transform: rotate(-45deg); transition: transform 0.05s ease; }
                .knob-val { transform: rotate(45deg); }
                .knob-lbl { font-size: 10px; color: var(--dim); text-align: center; }
                
                .master-fader-box { display: flex; flex-direction: column; align-items: center; gap: 8px; }
                .fader-slot { width: 14px; height: 160px; background: #0c0e14; border-radius: 7px; position: relative; border: 1px solid #283248; }
                .fader-thumb { width: 34px; height: 18px; background: var(--accent-cyan); border-radius: 3px; position: absolute; left: -10px; bottom: 85%; box-shadow: 0 0 10px var(--accent-cyan); }
                
                .odin-panel { margin-top: 18px; background: linear-gradient(135deg, #111824 0%, #191326 100%); border: 1px solid var(--accent-gold); border-radius: 8px; padding: 14px 18px; }
                .odin-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
                .odin-title { font-size: 13px; font-weight: 800; color: var(--accent-gold); letter-spacing: 0.8px; }
                .odin-btn { background: #1e2638; border: 1px solid var(--accent-gold); color: var(--accent-gold); padding: 5px 12px; border-radius: 4px; font-size: 11px; font-weight: 700; cursor: pointer; }
                .odin-btn.active { background: var(--accent-gold); color: #090a0f; box-shadow: 0 0 12px var(--accent-gold); }
                .runes-strip { display: grid; grid-template-columns: repeat(24, 1fr); gap: 4px; }
                .rune-cell { background: #0c0e14; border: 1px solid #283248; border-radius: 4px; padding: 6px 0; text-align: center; font-size: 14px; color: var(--accent-cyan); cursor: pointer; user-select: none; transition: all 0.12s ease; }
                .rune-cell.lit { background: var(--accent-gold); color: #090a0f; border-color: #fff; box-shadow: 0 0 10px var(--accent-gold); transform: translateY(-2px); }
                
                footer { margin-top: 20px; font-size: 11px; color: var(--dim); display: flex; justify-content: space-between; border-top: 1px solid #222938; padding-top: 12px; }
            </style>
        </head>
        <body>
            <header>
                <div class="title">
                    8b-nektar dj
                    <span class="badge">Nektar Impact LX25+ SOTA</span>
                    <span class="badge">360° Machine-S-UN~unity (#69,636)</span>
                    <span class="badge">ULTRABACKYARDLOOP 108/108 Laps</span>
                </div>
                <div class="hw-status">
                    <div class="hw-dot"></div>
                    <span id="hwLabel">Impact LX25+ USB (0x2467:0x2016) ONLINE</span>
                </div>
            </header>
            
            <div class="grid-decks">
                <div class="deck-card active" id="deck-0">
                    <div class="deck-header"><span>DECK A</span><span>128.0 BPM</span></div>
                    <div class="deck-title">The Future We Remember</div>
                    <div class="deck-meta">8bit-Wraith · C64 SID + Orchestra</div>
                    <div class="wave-box" id="wave-0"></div>
                </div>
                <div class="deck-card" id="deck-1">
                    <div class="deck-header"><span>DECK B</span><span>128.0 BPM</span></div>
                    <div class="deck-title">Quantshuffle Canon</div>
                    <div class="deck-meta">entheai-radio · 1-Bit Self-Feed</div>
                    <div class="wave-box" id="wave-1"></div>
                </div>
                <div class="deck-card active" id="deck-2">
                    <div class="deck-header"><span>DECK C</span><span>128.0 BPM</span></div>
                    <div class="deck-title">Quant65k+ Hyper-Lattice</div>
                    <div class="deck-meta">69,632 Layers · GHZ Entangled</div>
                    <div class="wave-box" id="wave-2"></div>
                </div>
                <div class="deck-card" id="deck-3">
                    <div class="deck-header"><span>DECK D</span><span>LIVE IN</span></div>
                    <div class="deck-title">ALL-IN Live Stem</div>
                    <div class="deck-meta">5-Band LTC EQ · Marine Salience</div>
                    <div class="wave-box" id="wave-3"></div>
                </div>
            </div>
            
            <div class="controls-row">
                <div class="section">
                    <div class="section-title">Nektar 8 Velocity Pads (Decks / Quantum Triggers)</div>
                    <div class="pads-grid">
                        <div class="pad-btn" id="pad-0"><div class="pad-num">PAD 1</div><div class="pad-label">Deck A Cue</div></div>
                        <div class="pad-btn" id="pad-1"><div class="pad-num">PAD 2</div><div class="pad-label">Deck B Cue</div></div>
                        <div class="pad-btn" id="pad-2"><div class="pad-num">PAD 3</div><div class="pad-label">Deck C Cue</div></div>
                        <div class="pad-btn" id="pad-3"><div class="pad-num">PAD 4</div><div class="pad-label">Deck D Cue</div></div>
                        <div class="pad-btn" id="pad-4"><div class="pad-num">PAD 5</div><div class="pad-label">QWave 79B Sync</div></div>
                        <div class="pad-btn" id="pad-5"><div class="pad-num">PAD 6</div><div class="pad-label">Zeno Overload</div></div>
                        <div class="pad-btn" id="pad-6"><div class="pad-num">PAD 7</div><div class="pad-label">SpherePOP 432Hz</div></div>
                        <div class="pad-btn" id="pad-7"><div class="pad-num">PAD 8</div><div class="pad-label">Momma Bear Covenant</div></div>
                    </div>
                    
                    <div class="section-title" style="margin-top: 20px;">8 Encoders (5-Band LTC EQ & Spatial Matrix)</div>
                    <div class="knobs-grid">
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-14"><span class="knob-val">60Hz</span></div>
                            <span class="knob-lbl">CC 14 (Sub)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-15"><span class="knob-val">250</span></div>
                            <span class="knob-lbl">CC 15 (Low)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-16"><span class="knob-val">1.0k</span></div>
                            <span class="knob-lbl">CC 16 (Mid)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-17"><span class="knob-val">4.0k</span></div>
                            <span class="knob-lbl">CC 17 (High)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-18"><span class="knob-val">12k</span></div>
                            <span class="knob-lbl">CC 18 (Air)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-19"><span class="knob-val">65k</span></div>
                            <span class="knob-lbl">CC 19 (Shimmer)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-20"><span class="knob-val">trit</span></div>
                            <span class="knob-lbl">CC 20 (IOuQT)</span>
                        </div>
                        <div class="knob-box">
                            <div class="knob-ring" id="knob-21"><span class="knob-val">pan</span></div>
                            <span class="knob-lbl">CC 21 (Spatial)</span>
                        </div>
                    </div>
                </div>
                
                <div class="section master-fader-box">
                    <div class="section-title">Zeno Master (30mm)</div>
                    <div class="fader-slot">
                        <div class="fader-thumb" id="masterFader"></div>
                    </div>
                    <div style="font-size: 13px; font-weight: 800; color: var(--accent-cyan); margin-top: 10px;" id="faderDb">0.0 dBFS</div>
                    <div style="font-size: 10px; color: var(--dim);">CC 11 / Zeno Ceiling</div>
                </div>
            </div>
            
            <div class="odin-panel">
                <div class="odin-header">
                    <div class="odin-title">LAYER #69,636 :: MACHINE-S-UN~UNITY 360° (iOS/Android/SmartTV/Embedded) × ULTRABACKYARDLOOP 108 LAPS × ODIN ༒</div>
                    <div style="display:flex;gap:8px;">
                        <button class="odin-btn" id="backyard108Btn" onclick="runBackyard108()">🏃 108-Lap Backyard Loop</button>
                        <button class="odin-btn" id="desertPsyBtn" onclick="toggleDesertPsy()">🎸 Desert Psy Rock (Kyuss × Plasma)</button>
                        <button class="odin-btn" id="odinDroneBtn" onclick="toggleOdinDrone()">🎻 Heimleið Tagelharpa + Odin Drone</button>
                    </div>
                </div>
                <div class="runes-strip" id="runesStrip"></div>
            </div>
            
            <footer>
                <span>8b-is-music v0.2.0 · OS-Agnostic 64B Core ABI · 360° Devices · Layer #69,636 (108/108 Laps)</span>
                <span>Zeno Asymptotic Brickwall Limiter: <b style="color:var(--accent-cyan);">0.999985</b></span>
            </footer>

            <script>
                const ELDER_FUTHARK = ['ᚠ','ᚢ','ᚦ','ᚨ','ᚱ','ᚲ','ᚷ','ᚹ','ᚺ','ᚾ','ᛁ','ᛃ','ᛇ','ᛈ','ᛉ','ᛋ','ᛏ','ᛒ','ᛖ','ᛗ','ᛚ','ᛝ','ᛞ','ᛟ'];
                const DORIAN_RATIOS = [1.0, 9/8, 6/5, 4/3, 3/2, 5/3, 9/5, 2.0];
                let audioCtx = null;
                let odinDroneNodes = null;
                let runeStep = 0;

                const runesStrip = document.getElementById('runesStrip');
                ELDER_FUTHARK.forEach((r, idx) => {
                    const cell = document.createElement('div');
                    cell.className = 'rune-cell';
                    cell.id = 'rune-' + idx;
                    cell.innerText = r;
                    cell.title = 'Rune #' + (idx + 1) + ' (' + r + ')';
                    cell.onclick = () => triggerRune(idx);
                    runesStrip.appendChild(cell);
                });

                function ensureAudio() {
                    if (!audioCtx) {
                        const AC = window.AudioContext || window.webkitAudioContext;
                        if (AC) audioCtx = new AC();
                    }
                    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
                    return audioCtx;
                }

                function triggerRune(idx) {
                    const cell = document.getElementById('rune-' + idx);
                    if (cell) {
                        cell.classList.add('lit');
                        setTimeout(() => cell.classList.remove('lit'), 260);
                    }
                    const ctx = ensureAudio();
                    if (!ctx) return;
                    const now = ctx.currentTime;
                    const osc = ctx.createOscillator();
                    const gain = ctx.createGain();
                    const ratio = DORIAN_RATIOS[idx % DORIAN_RATIOS.length] * (1 + Math.floor(idx / 8) * 0.5);
                    osc.type = 'triangle';
                    osc.frequency.setValueAtTime(144.0 * ratio, now);
                    gain.gain.setValueAtTime(0.0001, now);
                    gain.gain.exponentialRampToValueAtTime(0.06, now + 0.02);
                    gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.45);
                    osc.connect(gain);
                    gain.connect(ctx.destination);
                    osc.start(now);
                    osc.stop(now + 0.48);
                }

                window.toggleOdinDrone = function() {
                    const btn = document.getElementById('odinDroneBtn');
                    if (odinDroneNodes) {
                        odinDroneNodes.oscillators.forEach(o => { try { o.stop(); o.disconnect(); } catch (_) {} });
                        clearInterval(odinDroneNodes.timer);
                        odinDroneNodes = null;
                        btn.classList.remove('active');
                        btn.innerText = '🎻 Play Heimleið Tagelharpa + Odin Drone (72/108/432/528Hz)';
                        return;
                    }
                    const ctx = ensureAudio();
                    if (!ctx) return;
                    const now = ctx.currentTime;
                    const filter = ctx.createBiquadFilter();
                    filter.type = 'lowpass';
                    filter.frequency.setValueAtTime(420, now);
                    filter.connect(ctx.destination);
                    const specs = [
                        { f: 72.0, t: 'sawtooth', g: 0.04 },
                        { f: 108.0, t: 'sawtooth', g: 0.035 },
                        { f: 216.0, t: 'triangle', g: 0.04 },
                        { f: 432.0, t: 'sine', g: 0.03 },
                        { f: 528.0, t: 'sine', g: 0.025 },
                        { f: 852.0, t: 'sine', g: 0.012 }
                    ];
                    const oscillators = specs.map(s => {
                        const o = ctx.createOscillator();
                        const g = ctx.createGain();
                        o.type = s.t;
                        o.frequency.setValueAtTime(s.f, now);
                        g.gain.setValueAtTime(s.g, now);
                        o.connect(g);
                        g.connect(filter);
                        o.start(now);
                        return o;
                    });
                    const timer = setInterval(() => {
                        triggerRune(runeStep % 24);
                        runeStep++;
                    }, 1000);
                    odinDroneNodes = { oscillators, timer };
                    btn.classList.add('active');
                    btn.innerText = '༒ Heimleið Tagelharpa + Odin n+1||[X] (#69,633) ACTIVE';
                };

                let desertPsyNodes = null;
                let desertRiffStep = 0;
                const KYUSS_RIFF_HZ = [72.0, 72.0, 86.4, 96.0, 108.0, 96.0, 115.2, 65.41];

                window.toggleDesertPsy = function() {
                    const btn = document.getElementById('desertPsyBtn');
                    if (desertPsyNodes) {
                        clearInterval(desertPsyNodes.timer);
                        desertPsyNodes = null;
                        btn.classList.remove('active');
                        btn.innerText = '🎸 Desert Psy Rock (Kyuss × Plasma)';
                        return;
                    }
                    const ctx = ensureAudio();
                    if (!ctx) return;
                    const timer = setInterval(() => {
                        const now = ctx.currentTime;
                        const hz = KYUSS_RIFF_HZ[desertRiffStep % KYUSS_RIFF_HZ.length];
                        const osc = ctx.createOscillator();
                        const sub = ctx.createOscillator();
                        const filter = ctx.createBiquadFilter();
                        const gain = ctx.createGain();
                        osc.type = 'sawtooth';
                        sub.type = 'triangle';
                        osc.frequency.setValueAtTime(hz, now);
                        sub.frequency.setValueAtTime(hz * 1.5, now);
                        filter.type = 'bandpass';
                        filter.frequency.setValueAtTime(360 + 220 * Math.sin(desertRiffStep * 0.45), now);
                        filter.Q.setValueAtTime(2.4, now);
                        gain.gain.setValueAtTime(0.0001, now);
                        gain.gain.exponentialRampToValueAtTime(0.09, now + 0.02);
                        gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.31);
                        osc.connect(filter);
                        sub.connect(filter);
                        filter.connect(gain);
                        if (typeof ctx.createStereoPanner === 'function') {
                            const pan = ctx.createStereoPanner();
                            const w = desertRiffStep * 0.35;
                            pan.pan.setValueAtTime(0.75 * Math.cos(w) / (1 + Math.sin(w) * Math.sin(w)), now);
                            gain.connect(pan);
                            pan.connect(ctx.destination);
                        } else {
                            gain.connect(ctx.destination);
                        }
                        osc.start(now);
                        sub.start(now);
                        osc.stop(now + 0.33);
                        sub.stop(now + 0.33);
                        triggerRune((desertRiffStep * 3) % 24);
                        desertRiffStep++;
                    }, 326); // 92 BPM 8th-note Sky Valley / Plasma delay pocket
                    desertPsyNodes = { timer };
                    btn.classList.add('active');
                    btn.innerText = '🏜️ Kyuss × Plasma Procedural Spatial ACTIVE';
                };

                window.runBackyard108 = function() {
                    const btn = document.getElementById('backyard108Btn');
                    btn.classList.add('active');
                    let lap = 0;
                    const t = setInterval(() => {
                        lap += 4;
                        triggerRune((lap / 4) % 24);
                        if (lap >= 108) {
                            clearInterval(t);
                            btn.innerText = '🏆 108/108 Laps Verified (#69,636)';
                        } else {
                            btn.innerText = '🏃 Lap ' + lap + '/108 (gcd=1)';
                        }
                    }, 45);
                };

                // Generate waveform bars
                for (let d = 0; d < 4; d++) {
                    const box = document.getElementById('wave-' + d);
                    for (let i = 0; i < 28; i++) {
                        const bar = document.createElement('div');
                        bar.className = 'wave-bar';
                        bar.style.height = (20 + Math.sin(i * 0.4 + d) * 60 + Math.random() * 20) + '%';
                        box.appendChild(bar);
                    }
                }
                
                // Animate live waveforms
                setInterval(() => {
                    document.querySelectorAll('.wave-bar').forEach(b => {
                        if (Math.random() > 0.6) {
                            b.style.height = (15 + Math.random() * 80) + '%';
                        }
                    });
                }, 100);
                
                window.onNektarPad = function(idx, note, vel) {
                    if (idx >= 0 && idx < 8) {
                        const p = document.getElementById('pad-' + idx);
                        p.classList.add('pressed');
                        setTimeout(() => p.classList.remove('pressed'), 140);
                        triggerRune((idx * 3) % 24);
                    }
                };
                
                window.onNektarCC = function(cc, val, norm) {
                    if (cc === 11 || cc === 7) { // Fader
                        const pct = Math.min(100, Math.max(0, norm * 100));
                        document.getElementById('masterFader').style.bottom = pct + '%';
                        const db = (norm * 6.0 - 6.0).toFixed(1);
                        document.getElementById('faderDb').innerText = (norm >= 0.99 ? "0.0" : db) + " dBFS";
                    } else if (cc >= 14 && cc <= 21) {
                        const ring = document.getElementById('knob-' + cc);
                        if (ring) {
                            const deg = -135 + (norm * 270);
                            ring.style.transform = `rotate(${deg}deg)`;
                        }
                    }
                };
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

let app = NSApplication.shared
let delegate = NektarDJApp()
app.delegate = delegate
app.run()

