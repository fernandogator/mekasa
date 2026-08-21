/**
 * Superdesign mockup.
 * Spec: UI-003 | Design Artifact: design/mockups/ShoppingList.jsx
 * Preview: https://p.superdesign.dev/draft/b234a6ab-1837-48a9-84d1-a2ed870ae61c
 * Not application code. Do not ship.
 */
export default function ShoppingList() {
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
    <div className="sage-blob" style={{ viewTransitionName: "sage-bg" }}></div>
    
    {/* Header */}
    <header className="shrink-0 pt-14 px-6 z-10" style={{ viewTransitionName: "page-header" }}>
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-black text-brand leading-none mb-1">Saturday list</h1>
          <div className="flex items-center text-[12px] font-bold text-muted uppercase tracking-[0.1em]">
            <span className="flex items-center gap-1"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg> The Rivas House</span>
            <span className="mx-2">·</span>
            <span className="flex items-center gap-1 text-[#2f6b4f]"><div className="w-2 h-2 rounded-full bg-[#2f6b4f]"></div> shared live</span>
          </div>
        </div>
        <button className="w-10 h-10 rounded-full bg-surface-elevated shadow-sm flex items-center justify-center border border-muted">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="6" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="18" cy="12" r="1" fill="currentColor"/></svg>
        </button>
      </div>
    </header>

    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pt-6 pb-32 z-10" style={{ viewTransitionName: "main-content" }}>
      
      {/* List Items Container */}
      <div className="bg-surface-elevated rounded-[32px] p-2 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-muted space-y-1 mb-8">
        
        {/* Item 1: Checked */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="checkbox-custom checked mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
          </div>
          <div className="flex-1 opacity-50">
            <p className="font-bold text-[16px] line-through">2% milk</p>
            <p className="text-[12px] font-semibold text-muted">×2</p>
          </div>
        </div>

        {/* Item 2: Needs Approval */}
        <div className="flex items-center p-3 rounded-[24px] bg-[#fff5f0] transition-colors">
          <div className="w-10 h-10 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden border border-muted">
            <span className="font-bold text-brand text-xs">MA</span>
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-0.5">
              <p className="font-bold text-[16px]">Paper towels</p>
              <span className="text-[10px] font-bold uppercase tracking-wider text-white bg-[#c45c12] px-2 py-0.5 rounded-full">Needs approval</span>
            </div>
            <p className="text-[12px] font-semibold text-[#c45c12]">×1 • Requested by Maya</p>
          </div>
          <div className="flex space-x-2">
            <button className="w-10 h-10 rounded-full border border-muted flex items-center justify-center text-brand bg-white">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M18 6 6 18M6 6l12 12"/></svg>
            </button>
            <button className="w-10 h-10 rounded-full bg-brand text-white flex items-center justify-center">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
            </button>
          </div>
        </div>

        {/* Item 3: Standard */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="checkbox-custom mr-4 shrink-0"></div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Eggs</p>
            <p className="text-[12px] font-semibold text-muted">×1 dozen</p>
          </div>
        </div>

        {/* Item 4: Standard */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="checkbox-custom mr-4 shrink-0"></div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Avocados</p>
            <p className="text-[12px] font-semibold text-muted">×4</p>
          </div>
        </div>

        {/* Item 5: Standard */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="checkbox-custom mr-4 shrink-0"></div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Dish soap</p>
          </div>
        </div>

      </div>

      {/* Add Custom Item Action */}
      <button className="w-full py-4 rounded-[24px] border-2 border-dashed border-[#b7c6c2] text-brand font-bold flex items-center justify-center gap-2 hover:bg-[#e4ecea] transition-colors">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/></svg>
        Add custom item
      </button>

    </main>

    {/* Bottom Navigation */}
    <nav className="absolute bottom-8 left-6 right-6 z-40" style={{ viewTransitionName: "main-nav" }}>
      <div className="bg-brand h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative">
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-white w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M8 6h13M8 12h13M8 18h13"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/></svg>
        </a>
        
        {/* Spacer for FAB */}
        <div className="w-16"></div>
        
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </a>
      </div>
      
      {/* Center Add FAB */}
      <a href="#" className="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-accent rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] active:scale-95 transition-transform" style={{ viewTransitionName: "fab-button" }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M12 5v14M5 12h14"/></svg>
      </a>
    </nav>

  </div>
    </>
  );
}
