/**
 * Superdesign mockup.
 * Spec: UI-001 | Design Artifact: design/mockups/Dashboard.jsx
 * Preview: https://p.superdesign.dev/draft/69d15b18-61b1-45ec-92f6-5f89e59a7ee9
 * Not application code. Do not ship.
 */
export default function Dashboard() {
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
      <div className="mekasa-screen w-full h-screen flex flex-col relative overflow-hidden bg-[#eeebe3]" >
    <div className="sage-blob" ></div>
    
    {/* Header */}
    <header className="shrink-0 pt-14 px-6 z-10" >
      <div className="flex justify-between items-start" >
        <div >
          <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-muted mb-1" >Good Morning</p>
          <h1 className="text-3xl font-black text-brand leading-none" >The Rodriguez House</h1>
        </div>
        <button className="w-10 h-10 rounded-full bg-surface-elevated shadow-sm flex items-center justify-center border border-muted" >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>
          <div className="absolute top-2 right-2 w-2 h-2 bg-accent rounded-full border border-white" ></div>
        </button>
      </div>
    </header>

    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pt-6 pb-32 z-10 space-y-8" style={{ viewTransitionName: "main-content" }} >
      
      {/* Quick Stats */}
      <div className="grid grid-cols-2 gap-4" >
        <div className="bg-surface-elevated p-5 rounded-[24px] shadow-sm border border-muted" >
          <div className="flex items-center space-x-2 mb-2" >
            <div className="w-8 h-8 rounded-full bg-[#fce5e7] flex items-center justify-center" >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4"><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></svg>
            </div>
            <span className="text-sm font-bold text-muted" >Low Stock</span>
          </div>
          <div className="text-2xl font-black" >12 items</div>
        </div>
        <div className="bg-surface-elevated p-5 rounded-[24px] shadow-sm border border-muted" >
          <div className="flex items-center space-x-2 mb-2" >
            <div className="w-8 h-8 rounded-full bg-[#eaf1ec] flex items-center justify-center" >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4"><path d="M20 7H4a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h16a1 1 0 0 0 1-1V8a1 1 0 0 0-1-1z"/><path d="M16 12h.01"/></svg>
            </div>
            <span className="text-sm font-bold text-muted" >Spend</span>
          </div>
          <div className="text-2xl font-black" >$430 <span className="text-sm text-muted font-semibold" >/wk</span></div>
        </div>
      </div>

      {/* Needs Approval */}
      <section >
        <div className="flex justify-between items-center mb-4" >
          <h2 className="text-[20px] font-extrabold" >Needs Approval</h2>
          <button className="text-sm font-bold text-muted uppercase tracking-wider" >View All</button>
        </div>
        <div className="bg-surface-elevated rounded-[32px] p-2 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-muted space-y-1" >
          {/* Item 1 */}
          <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors" >
            <div className="w-10 h-10 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0" >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M8 2h8l1 4H7z"/><path d="M7 6h10v14a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2z"/></svg>
            </div>
            <div className="flex-1" >
              <p className="font-bold text-[16px]" >Oat Milk</p>
              <p className="text-[12px] font-semibold text-muted" >Requested by Leo</p>
            </div>
            <div className="flex space-x-2" >
              <button className="w-10 h-10 rounded-full border border-muted flex items-center justify-center text-brand" >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M18 6 6 18M6 6l12 12"/></svg>
              </button>
              <button className="w-10 h-10 rounded-full bg-brand text-white flex items-center justify-center" >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
              </button>
            </div>
          </div>
          {/* Item 2 */}
          <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors" >
            <div className="w-10 h-10 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0" >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="12" r="9"/><circle cx="8" cy="10" r="1" fill="currentColor"/><circle cx="15" cy="9" r="1" fill="currentColor"/><circle cx="10" cy="15" r="1" fill="currentColor"/></svg>
            </div>
            <div className="flex-1" >
              <p className="font-bold text-[16px]" >Oreos</p>
              <p className="text-[12px] font-semibold text-muted" >Requested by Mia</p>
            </div>
            <div className="flex space-x-2" >
              <button className="w-10 h-10 rounded-full border border-muted flex items-center justify-center text-brand" >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M18 6 6 18M6 6l12 12"/></svg>
              </button>
              <button className="w-10 h-10 rounded-full bg-brand text-white flex items-center justify-center" >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Recent Activity */}
      <section >
        <h2 className="text-[20px] font-extrabold mb-4" >Recent Activity</h2>
        <div className="space-y-4" >
          <div className="flex items-start" >
            <div className="w-2 h-2 rounded-full bg-[#c45c12] mt-2 mr-4" ></div>
            <div >
              <p className="text-[16px] font-semibold" >Eggs marked as depleted</p>
              <p className="text-[12px] font-bold text-muted uppercase tracking-wider mt-1" >2 hours ago</p>
            </div>
          </div>
          <div className="flex items-start" >
            <div className="w-2 h-2 rounded-full bg-[#2f6b4f] mt-2 mr-4" ></div>
            <div >
              <p className="text-[16px] font-semibold" >H-E-B run completed</p>
              <p className="text-[12px] font-bold text-muted uppercase tracking-wider mt-1" >Yesterday</p>
            </div>
          </div>
        </div>
      </section>
    </main>

    {/* Bottom Navigation */}
    <div className="absolute bottom-8 left-6 right-6 z-40 nav-persistent" >
      <div className="bg-brand h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative" >
        <a href="#" className="flex flex-col items-center justify-center text-white w-12" >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12" >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M8 6h13M8 12h13M8 18h13"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/></svg>
        </a>
        
        {/* Spacer for FAB */}
        <div className="w-16" ></div>
        
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12" >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12" >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </a>
      </div>
      
      {/* Center Add FAB */}
      <a href="#" className="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-accent rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] active:scale-95 transition-transform cursor-pointer block" >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M12 5v14M5 12h14"/></svg>
      </a>
    </div>

  </div>
    </>
  );
}
