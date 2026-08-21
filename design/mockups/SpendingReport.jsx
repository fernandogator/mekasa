/**
 * Superdesign mockup.
 * Spec: spending report | Design Artifact: design/mockups/SpendingReport.jsx
 * Preview: https://p.superdesign.dev/draft/a45a3eab-e709-415e-8a81-19f333a3c88b
 * Not application code. Do not ship.
 */
export default function SpendingReport() {
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
    
    {/* Header */}
    <header className="shrink-0 pt-14 px-6 z-10">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-black text-brand leading-none">This month</h1>
        <div className="bg-surface-elevated rounded-full p-1 border border-muted flex items-center shadow-sm">
            <button className="px-3 py-1 rounded-full text-[12px] font-bold text-muted">W</button>
            <button className="px-3 py-1 rounded-full text-[12px] font-bold bg-brand text-white">M</button>
            <button className="px-3 py-1 rounded-full text-[12px] font-bold text-muted">Y</button>
        </div>
      </div>
    </header>

    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pb-32 z-10 space-y-8" style={{ viewTransitionName: "main-content" }}>
      
      {/* Hero Amount */}
      <div className="flex flex-col items-center justify-center py-6">
        <p className="text-[12px] font-bold uppercase tracking-[0.1em] text-muted mb-2">Total Spend</p>
        <h2 className="text-[56px] font-black text-brand leading-none tracking-tight">$186<span className="text-[32px] text-muted">.40</span></h2>
      </div>

      {/* Categories */}
      <section className="bg-surface-elevated rounded-[40px] p-6 shadow-sm border border-muted space-y-6">
        <h3 className="text-[20px] font-extrabold mb-4">By Category</h3>
        
        {/* Category 1: Groceries */}
        <div className="space-y-2">
            <div className="flex justify-between items-end">
                <span className="text-[16px] font-bold">Groceries</span>
                <span className="text-[16px] font-black">$112.50</span>
            </div>
            <div className="h-4 w-full bg-[#eaf1ec] rounded-full overflow-hidden">
                <div className="h-full bg-brand rounded-full" style={{ width: "65%" }}></div>
            </div>
            <p className="text-[10px] font-bold text-muted uppercase tracking-wider">$200 Budget</p>
        </div>

        {/* Category 2: Household (Over budget) */}
        <div className="space-y-2">
            <div className="flex justify-between items-end">
                <span className="text-[16px] font-bold">Household</span>
                <span className="text-[16px] font-black text-[#ca0013]">$48.90</span>
            </div>
            <div className="h-4 w-full bg-[#fce5e7] rounded-full overflow-hidden">
                <div className="h-full bg-accent rounded-full" style={{ width: "100%" }}></div>
            </div>
            <p className="text-[10px] font-bold text-[#ca0013] uppercase tracking-wider">$40 Budget (Over)</p>
        </div>

        {/* Category 3: Pets */}
        <div className="space-y-2">
            <div className="flex justify-between items-end">
                <span className="text-[16px] font-bold">Pets</span>
                <span className="text-[16px] font-black">$15.00</span>
            </div>
            <div className="h-4 w-full bg-[#eaf1ec] rounded-full overflow-hidden">
                <div className="h-full bg-brand rounded-full" style={{ width: "25%" }}></div>
            </div>
            <p className="text-[10px] font-bold text-muted uppercase tracking-wider">$60 Budget</p>
        </div>

        {/* Category 4: Personal */}
        <div className="space-y-2">
            <div className="flex justify-between items-end">
                <span className="text-[16px] font-bold">Personal</span>
                <span className="text-[16px] font-black">$10.00</span>
            </div>
            <div className="h-4 w-full bg-[#eaf1ec] rounded-full overflow-hidden">
                <div className="h-full bg-brand rounded-full" style={{ width: "15%" }}></div>
            </div>
            <p className="text-[10px] font-bold text-muted uppercase tracking-wider">$80 Budget</p>
        </div>
      </section>

      {/* Top Store */}
      <div className="bg-surface-elevated p-5 rounded-[40px] shadow-sm border border-muted flex items-center">
        <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><path d="M3 6h18M16 10a4 4 0 0 1-8 0"/></svg>
        </div>
        <div>
            <p className="text-[12px] font-bold text-muted uppercase tracking-wider">Top Store</p>
            <p className="text-[20px] font-extrabold">H-E-B</p>
        </div>
      </div>

    </main>

    {/* Bottom Navigation */}
    <div className="absolute bottom-8 left-6 right-6 z-40" style={{ viewTransitionName: "nav" }}>
      <div className="bg-brand h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative">
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M8 6h13M8 12h13M8 18h13"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/></svg>
        </a>
        
        {/* Spacer for FAB */}
        <div className="w-16"></div>
        
        <a href="#" className="flex flex-col items-center justify-center text-white w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </a>
      </div>
      
      {/* Center Add FAB */}
      <a href="#" className="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-accent rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] active:scale-95 transition-transform">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M12 5v14M5 12h14"/></svg>
      </a>
    </div>

  </div>
    </>
  );
}
