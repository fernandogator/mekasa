/**
 * Superdesign mockup.
 * Spec: UI-004 | Design Artifact: design/mockups/AddItems.jsx
 * Preview: https://p.superdesign.dev/draft/eee7d5dd-5cc6-4c4a-8c91-2717e1973660
 * Not application code. Do not ship.
 */
export default function AddItems() {
  return (
    <>
      <style>{`  @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap');
  :root {
    --color-brand: #171e19;
    --color-brand-muted: #b7c6c2;
    --color-surface: #eeebe3;
    --color-surface-elevated: #ffffff;
    --color-text: #171e19;
    --color-text-muted: #6d7a76;
    --color-accent: #ca0013;
    --color-danger: #ca0013;
    --color-success: #2f6b4f;
    --color-warning: #c45c12;
    --color-overlay: rgba(183, 198, 194, 0.20);
  }
  .mekasa-screen {
    font-family: Nunito, sans-serif;
    background-color: var(--color-surface);
    color: var(--color-text);
  }
  .mekasa-screen .text-brand { color: var(--color-brand); }
  .mekasa-screen .text-muted { color: var(--color-text-muted); }
  .mekasa-screen .bg-brand { background-color: var(--color-brand); }
  .mekasa-screen .bg-accent { background-color: var(--color-accent); }
  .mekasa-screen .bg-surface-elevated { background-color: var(--color-surface-elevated); }
  .mekasa-screen .border-muted { border-color: rgba(183, 198, 194, 0.3); }
  .mekasa-screen .sage-blob {
    position: absolute;
    top: -50px;
    right: -50px;
    width: 300px;
    height: 300px;
    border-radius: 50%;
    background: var(--color-overlay);
    filter: blur(40px);
    z-index: 0;
    pointer-events: none;
  }
  .mekasa-screen .store-checkbox {
    appearance: none;
    width: 24px;
    height: 24px;
    border: 2px solid var(--color-brand-muted);
    border-radius: 50%;
    outline: none;
    cursor: pointer;
    position: relative;
  }
  .mekasa-screen .store-checkbox:checked {
    background-color: var(--color-accent);
    border-color: var(--color-accent);
  }
  .mekasa-screen .checkbox-custom {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 2px solid var(--color-brand-muted);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .mekasa-screen .checkbox-custom.checked {
    background-color: var(--color-accent);
    border-color: var(--color-accent);
    color: white;
  }`}</style>
      <div className="mekasa-screen w-full h-screen flex flex-col relative overflow-hidden bg-[#eeebe3]">
    <div className="sage-blob"></div>
    
    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pt-14 pb-32 z-10 space-y-6" style={{ viewTransitionName: "main-content" }}>
      
      <div className="mb-8">
          <h1 className="text-[32px] font-black text-brand leading-tight mb-2">Add to the house</h1>
          <p className="text-[16px] text-muted font-semibold">Each path lets you confirm before anything saves.</p>
      </div>

      <div className="space-y-4">
          
          {/* Scan Barcode */}
          <a href="#barcode-scanner" className="block bg-surface-elevated rounded-[24px] p-5 shadow-sm border border-muted hover:bg-[#f8f9f8] transition-colors">
              <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 rounded-full bg-[#f1f4f3] flex items-center justify-center shrink-0">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M4 7v10M7 4v16M10 7v10M13 4v16M16 7v10M20 7v10"/></svg>
                  </div>
                  <div>
                      <h2 className="text-[18px] font-extrabold text-brand">Scan barcode</h2>
                      <p className="text-[14px] font-semibold text-muted truncate">Fastest for packaged pantry items</p>
                  </div>
              </div>
          </a>

          {/* Scan Receipt */}
          <a href="#receipt-scanner" className="block bg-surface-elevated rounded-[24px] p-5 shadow-sm border border-muted hover:bg-[#f8f9f8] transition-colors">
              <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 rounded-full bg-[#f1f4f3] flex items-center justify-center shrink-0">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M4 2v20l3-2 3 2 3-2 3 2 3-2 3 2V2l-3 2-3-2-3 2-3-2-3 2z"/><path d="M8 10h8M8 14h5"/></svg>
                  </div>
                  <div>
                      <h2 className="text-[18px] font-extrabold text-brand">Scan receipt</h2>
                      <p className="text-[14px] font-semibold text-muted truncate">Add full grocery hauls instantly</p>
                  </div>
              </div>
          </a>

          {/* Say it out loud */}
          <a href="#voice-input" className="block bg-surface-elevated rounded-[24px] p-5 shadow-sm border border-muted hover:bg-[#f8f9f8] transition-colors">
              <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 rounded-full bg-[#f1f4f3] flex items-center justify-center shrink-0">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v4"/></svg>
                  </div>
                  <div>
                      <h2 className="text-[18px] font-extrabold text-brand">Say it out loud</h2>
                      <p className="text-[14px] font-semibold text-muted truncate">Hands-free when cooking or unpacking</p>
                  </div>
              </div>
          </a>

          {/* Type it in */}
          <a href="#manual-entry" className="block bg-surface-elevated rounded-[24px] p-5 shadow-sm border border-muted hover:bg-[#f8f9f8] transition-colors">
              <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 rounded-full bg-[#f1f4f3] flex items-center justify-center shrink-0">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h.01M10 10h.01M14 10h.01M18 10h.01M8 14h8"/></svg>
                  </div>
                  <div>
                      <h2 className="text-[18px] font-extrabold text-brand">Type it in</h2>
                      <p className="text-[14px] font-semibold text-muted truncate">Manual entry for produce or loose items</p>
                  </div>
              </div>
          </a>

          {/* Trash Station */}
          <a href="#" className="block bg-surface-elevated rounded-[24px] p-5 shadow-sm border border-muted hover:bg-[#fce5e7] transition-colors">
              <div className="flex items-center space-x-4">
                  <div className="w-14 h-14 rounded-full bg-[#fce5e7] flex items-center justify-center shrink-0">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/></svg>
                  </div>
                  <div>
                      <h2 className="text-[18px] font-extrabold text-accent">Trash station</h2>
                      <p className="text-[14px] font-semibold text-muted truncate">Mark things gone to restock them later</p>
                  </div>
              </div>
          </a>

      </div>

    </main>

    {/* Bottom Navigation */}
    <div className="absolute bottom-8 left-6 right-6 z-40" style={{ viewTransitionName: "main-nav" }}>
      <div className="bg-brand h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative">
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12 hover:text-white transition-colors">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12 hover:text-white transition-colors">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M8 6h13M8 12h13M8 18h13"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/></svg>
        </a>
        
        {/* Spacer for FAB */}
        <div className="w-16"></div>
        
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12 hover:text-white transition-colors">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12 hover:text-white transition-colors">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </a>
      </div>
      
      {/* Center Add FAB (Visually Active) */}
      <button className="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-accent rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] scale-105 transition-transform">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M18 6 6 18M6 6l12 12"/></svg>
      </button>
    </div>

  </div>
    </>
  );
}
