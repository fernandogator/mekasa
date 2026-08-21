/**
 * Superdesign mockup.
 * Spec: UI-002 | Design Artifact: design/mockups/OnboardingStoreSelection.jsx
 * Preview: https://p.superdesign.dev/draft/afdeeaad-6431-495e-9674-5231b3993dca
 * Not application code. Do not ship.
 */
export default function OnboardingStoreSelection() {
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
    
    {/* Onboarding Header */}
    <header className="shrink-0 pt-14 px-6 z-10">
      <div className="flex flex-col items-center justify-center space-y-1">
        <p className="text-[10px] font-bold uppercase tracking-[0.1em] text-muted">Step 4 of 6</p>
        <h1 className="text-xl font-black text-brand tracking-tight">Mekasa</h1>
      </div>
    </header>

    {/* Main Content Area with View Transition */}
    <main className="flex-1 overflow-y-auto px-6 pt-10 pb-32 z-10 flex flex-col" style={{ viewTransitionName: "main-content" }}>
      
      {/* Header Section */}
      <div className="mb-8">
        <h2 className="text-[32px] font-black text-brand leading-tight mb-3">Where do you shop?</h2>
        <p className="text-[16px] font-semibold text-muted">
          We'll look within 15 miles of 1842 Magnolia Ave.
        </p>
      </div>

      {/* Search Field */}
      <div className="relative mb-6">
        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
        </div>
        <input 
          type="text" 
          placeholder="Search for a store..."
          className="w-full h-[56px] pl-12 pr-4 bg-surface-elevated border border-muted rounded-[24px] text-[16px] font-semibold focus:outline-none focus:border-brand shadow-sm"
         />
      </div>

      {/* Store List Container */}
      <div className="bg-surface-elevated rounded-[40px] p-2 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-muted flex-1 overflow-y-auto space-y-1">
        
        {/* Store Row: Selected */}
        <label className="flex items-center justify-between p-4 rounded-[32px] bg-[#171e19] text-white cursor-pointer transition-colors">
          <div className="flex items-center">
            <div className="w-12 h-12 rounded-full bg-white flex items-center justify-center mr-4 shrink-0 overflow-hidden">
               {/* Placeholder for store logo, using text for now */}
               <span className="text-brand font-black text-sm">H-E-B</span>
            </div>
            <div>
              <p className="font-extrabold text-[16px]">H-E-B</p>
              <p className="text-[12px] font-bold text-[#b7c6c2] uppercase tracking-wider">0.8 mi</p>
            </div>
          </div>
          <div className="w-8 h-8 rounded-full bg-accent flex items-center justify-center">
             <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
          </div>
        </label>

        {/* Store Row: Selected */}
        <label className="flex items-center justify-between p-4 rounded-[32px] bg-[#171e19] text-white cursor-pointer transition-colors">
          <div className="flex items-center">
            <div className="w-12 h-12 rounded-full bg-white flex items-center justify-center mr-4 shrink-0 overflow-hidden">
               <span className="text-brand font-black text-sm">Costco</span>
            </div>
            <div>
              <p className="font-extrabold text-[16px]">Costco</p>
              <p className="text-[12px] font-bold text-[#b7c6c2] uppercase tracking-wider">4.2 mi</p>
            </div>
          </div>
          <div className="w-8 h-8 rounded-full bg-accent flex items-center justify-center">
             <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="m5 12 5 5L20 7"/></svg>
          </div>
        </label>

        {/* Store Row: Unselected */}
        <label className="flex items-center justify-between p-4 rounded-[32px] hover:bg-[#f8f9f8] cursor-pointer transition-colors">
          <div className="flex items-center">
            <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
               <span className="text-brand font-black text-sm">Kroger</span>
            </div>
            <div>
              <p className="font-extrabold text-[16px]">Kroger</p>
              <p className="text-[12px] font-bold text-muted uppercase tracking-wider">2.1 mi</p>
            </div>
          </div>
          <input type="checkbox" className="store-checkbox" />
        </label>

        {/* Store Row: Unselected */}
        <label className="flex items-center justify-between p-4 rounded-[32px] hover:bg-[#f8f9f8] cursor-pointer transition-colors">
          <div className="flex items-center">
            <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
               <span className="text-brand font-black text-xs">Walmart</span>
            </div>
            <div>
              <p className="font-extrabold text-[16px]">Walmart Supercenter</p>
              <p className="text-[12px] font-bold text-muted uppercase tracking-wider">6.7 mi</p>
            </div>
          </div>
          <input type="checkbox" className="store-checkbox" />
        </label>

        {/* Store Row: Unselected */}
        <label className="flex items-center justify-between p-4 rounded-[32px] hover:bg-[#f8f9f8] cursor-pointer transition-colors">
          <div className="flex items-center">
            <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
               <span className="text-brand font-black text-sm">Target</span>
            </div>
            <div>
              <p className="font-extrabold text-[16px]">Target</p>
              <p className="text-[12px] font-bold text-muted uppercase tracking-wider">5.4 mi</p>
            </div>
          </div>
          <input type="checkbox" className="store-checkbox" />
        </label>

      </div>
    </main>

    {/* Sticky Bottom CTA (No Tab Bar) */}
    <div className="absolute bottom-0 left-0 right-0 p-6 pt-4 bg-gradient-to-t from-[#eeebe3] via-[#eeebe3] to-transparent z-40">
      <a href="#" 
         
         className="flex items-center justify-center w-full h-[56px] bg-accent text-white rounded-[24px] font-extrabold text-[18px] shadow-[0_8px_16px_rgba(202,0,19,0.2)] active:scale-[0.98] transition-transform">
        Confirm stores
      </a>
      
      {/* Progress indicator track beneath CTA */}
      <div className="mt-6 w-full h-1 bg-[#d5ddd9] rounded-full overflow-hidden">
         <div className="h-full bg-brand w-[66%]"></div>
      </div>
    </div>

  </div>
    </>
  );
}
