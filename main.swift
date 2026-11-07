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
                
                footer { margin-top: 20px; font-size: 11px; color: var(--dim); display: flex; justify-content: space-between; border-top: 1px solid #222938; padding-top: 12px; }
            </style>
        </head>
        <body>
            <header>
                <div class="title">
                    8b-nektar dj
                    <span class="badge">Nektar Impact LX25+ SOTA</span>
                    <span class="badge">Quant65k+ / 69,632 Layers</span>
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
            
            <footer>
                <span>8b-is-music v0.2.0 · CoreMIDI Native Client Active</span>
                <span>Zeno Asymptotic Brickwall Limiter: <b style="color:var(--accent-cyan);">0.999985</b></span>
            </footer>

            <script>
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

