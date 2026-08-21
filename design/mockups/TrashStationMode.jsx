/**
 * Superdesign mockup.
 * Spec: UI-005 | Design Artifact: design/mockups/TrashStationMode.jsx
 * Preview: https://p.superdesign.dev/draft/a8a15416-6c7a-4f32-b1b0-c233c57f0cd1
 * Not application code. Do not ship.
 */
export default function TrashStationMode() {
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

    <header className="shrink-0 pt-14 px-6 z-10">
      <div className="flex items-center justify-between mb-6">
        <a href="#" className="w-10 h-10 rounded-full bg-surface-elevated shadow-sm flex items-center justify-center border border-muted">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M18 6 6 18M6 6l12 12"/></svg>
        </a>
        <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-muted">Focused mode</p>
        <div className="w-10"></div>
      </div>
      <h1 className="text-3xl font-black text-brand leading-none mb-2">Trash station</h1>
      <p className="text-[16px] font-semibold text-muted">Tap what just ran out.</p>
    </header>

    <main className="flex-1 overflow-y-auto px-6 pt-6 pb-32 z-10">
      <div className="relative mb-4">
        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
        </div>
        <input type="text" placeholder="Search inventory..." className="w-full h-[56px] pl-12 pr-4 bg-surface-elevated border border-muted rounded-[24px] text-[16px] font-semibold focus:outline-none focus:border-brand shadow-sm" />
      </div>

      <div className="flex gap-2 mb-6">
        <button className="px-4 h-10 rounded-full bg-brand text-white text-[12px] font-bold uppercase tracking-wider">Kitchen</button>
        <button className="px-4 h-10 rounded-full bg-surface-elevated border border-muted text-muted text-[12px] font-bold uppercase tracking-wider">Fridge</button>
      </div>

      <div className="bg-surface-elevated rounded-[40px] p-2 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-muted space-y-1">
        <button className="w-full flex items-center p-4 rounded-[32px] hover:bg-[#f8f9f8] transition-colors text-left">
          <div className="w-14 h-14 rounded-[16px] bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M8 2h8l1 4H7z"/><path d="M7 6h10v14a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2z"/></svg>
          </div>
          <div className="flex-1">
            <p className="font-extrabold text-[18px]">Milk</p>
            <p className="text-[12px] font-bold text-muted uppercase tracking-wider">1 left · Kitchen</p>
          </div>
          <div className="w-12 h-12 rounded-full border-2 border-muted flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M5 12h14"/></svg>
          </div>
        </button>

        <button className="w-full flex items-center p-4 rounded-[32px] hover:bg-[#f8f9f8] transition-colors text-left">
          <div className="w-14 h-14 rounded-[16px] bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M12 22c4.5 0 8-5 8-11a8 8 0 1 0-16 0c0 6 3.5 11 8 11z"/></svg>
          </div>
          <div className="flex-1">
            <p className="font-extrabold text-[18px]">Eggs</p>
            <p className="text-[12px] font-bold text-muted uppercase tracking-wider">Low · Fridge</p>
          </div>
          <div className="w-12 h-12 rounded-full border-2 border-muted flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M5 12h14"/></svg>
          </div>
        </button>

        <button className="w-full flex items-center p-4 rounded-[32px] hover:bg-[#f8f9f8] transition-colors text-left">
          <div className="w-14 h-14 rounded-[16px] bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/></svg>
          </div>
          <div className="flex-1">
            <p className="font-extrabold text-[18px]">Spinach</p>
            <p className="text-[12px] font-bold text-muted uppercase tracking-wider">Fridge</p>
          </div>
          <div className="w-12 h-12 rounded-full border-2 border-muted flex items-center justify-center">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M5 12h14"/></svg>
          </div>
        </button>

        <div className="w-full flex items-center p-4 rounded-[32px] bg-[#eaf1ec] text-left">
          <div className="w-14 h-14 rounded-[16px] bg-white flex items-center justify-center mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M17 8h1a4 4 0 0 1 0 8h-1"/><path d="M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"/><path d="M6 2v2M10 2v2M14 2v2"/></svg>
          </div>
          <div className="flex-1">
            <p className="font-extrabold text-[18px] text-[#2f6b4f]">Coffee pods</p>
            <p className="text-[12px] font-bold uppercase tracking-wider text-[#2f6b4f]">Removed · added to list</p>
          </div>
          <div className="w-12 h-12 rounded-full bg-[#2f6b4f] flex items-center justify-center text-white">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
          </div>
        </div>
      </div>
    </main>

    <div className="absolute bottom-0 left-0 right-0 p-6 pt-4 bg-gradient-to-t from-[#eeebe3] via-[#eeebe3] to-transparent z-40">
      <a href="#" className="flex items-center justify-center w-full h-[56px] bg-white border border-muted text-brand rounded-[24px] font-extrabold text-[18px] active:scale-[0.98] transition-transform">
        Done
      </a>
    </div>
  </div>
    </>
  );
}
