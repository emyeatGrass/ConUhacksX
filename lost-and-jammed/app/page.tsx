'use client';
import { useState, useCallback, useRef } from 'react';

const UploadIcon = () => (
  <svg className="w-8 h-8 mb-3 text-zinc-400 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
  </svg>
);

const SearchIcon = () => (
  <svg className="w-8 h-8 mb-3 text-zinc-400 transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
  </svg>
);

export default function Home() {
  const [response, setResponse] = useState('');
  const [returnedImage, setReturnedImage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isAdding, setIsAdding] = useState(true);
  const [isDragging, setIsDragging] = useState(false);
  
  const [showGame, setShowGame] = useState(false);
  
  const resultsRef = useRef<HTMLDivElement>(null);

  const resetUI = () => {
    setResponse('');
    setReturnedImage(null);
    setShowGame(false);
  };

  const handleTabChange = (adding: boolean) => {
    if (isLoading || adding === isAdding) return;
    setIsAdding(adding);
    resetUI();
  };

  const checkIsDesktop = () => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia("(pointer: fine) and (min-width: 1024px)").matches;
  };

  const handleSkip = () => {
    setShowGame(false);
    setTimeout(() => {
      resultsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 100);
  };

  const processFile = (file: File) => {
    if (!file) return;

    resetUI();
    setIsLoading(true);
    setResponse('Scanning item...');

    const reader = new FileReader();
    reader.onloadend = () => {
      const img = new Image();
      img.onload = async () => {
        const canvas = document.createElement('canvas');
        const MAX_SIDE = 500;
        let { width, height } = img;

        if (width > height ? width > MAX_SIDE : height > MAX_SIDE) {
          const ratio = MAX_SIDE / Math.max(width, height);
          width *= ratio;
          height *= ratio;
        }

        canvas.width = width;
        canvas.height = height;
        canvas.getContext('2d')?.drawImage(img, 0, 0, width, height);
        const compressedBase64 = canvas.toDataURL('image/jpeg', 0.5).split(',')[1];

        try {
          const res = await fetch('/api/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ image: compressedBase64, mimeType: 'image/jpeg', isAdding }),
          });

          const data = await res.json();
          setResponse(data.text);
          if (data.image) {
            let base64 = data.image;
            while (base64.length % 4 !== 0) base64 += '=';
            setReturnedImage(base64);
            
            if (checkIsDesktop()) {
               setShowGame(true);
            }
          }
        } catch (error) {
          setResponse('Connection jammed. Try again.');
        } finally {
          setIsLoading(false);
        }
      };
      img.src = reader.result as string;
    };
    reader.readAsDataURL(file);
  };

  const onDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const onDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  }, []);

  const onDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      processFile(e.dataTransfer.files[0]);
    }
  }, [isAdding]);

  const activeColor = isAdding ? 'bg-sky-500' : 'bg-orange-500';
  const activeHover = isAdding ? 'hover:bg-sky-600' : 'hover:bg-orange-600';
  const activeBorder = isAdding ? 'border-sky-200 dark:border-sky-900' : 'border-orange-200 dark:border-orange-900';
  const textColor = isAdding ? 'text-sky-500' : 'text-orange-500';
  const dragBorder = isAdding ? 'border-sky-500 bg-sky-50 dark:bg-sky-900/20' : 'border-orange-500 bg-orange-50 dark:bg-orange-900/20';

  return (
    <main className={`min-h-screen flex flex-col items-center pt-12 p-6 relative overflow-x-hidden transition-colors duration-700 ${isAdding ? 'bg-slate-50 dark:bg-slate-950' : 'bg-orange-50/30 dark:bg-zinc-950'}`}>

      <div className="z-10 w-full max-w-md flex flex-col gap-6">
        
        <div className="text-center space-y-2">
          <h1 className="text-5xl font-extrabold tracking-tight text-transparent bg-clip-text bg-gradient-to-r from-zinc-800 to-zinc-500 dark:from-zinc-100 dark:to-zinc-400">
            Lost<span className={textColor}>&</span>Jammed
          </h1>
          <p className="text-sm font-medium text-zinc-500 dark:text-zinc-400">
            {isAdding ? "Deposit a lost item." : "Scan to retrieve your missing item."}
          </p>
        </div>

        <div className="bg-white/80 dark:bg-zinc-900/80 backdrop-blur-xl border border-white/20 shadow-2xl rounded-3xl p-6 transition-all duration-300">
          
          <div className="relative flex bg-zinc-100 dark:bg-zinc-800 p-1 rounded-xl mb-8">
            <div 
              className={`
                absolute top-1 bottom-1 left-1 w-[calc(50%-4px)] 
                rounded-lg shadow-sm bg-white dark:bg-zinc-700 
                transition-transform duration-300 ease-spring
                ${isAdding ? 'translate-x-0' : 'translate-x-full'}
              `}
            ></div>
            <button 
              onClick={() => handleTabChange(true)}
              className={`relative z-10 flex-1 py-2.5 text-sm font-bold transition-colors duration-300 ${isAdding ? 'text-zinc-900 dark:text-white' : 'text-zinc-500'}`}
              disabled={isLoading}
            >
              Add Item
            </button>
            <button 
              onClick={() => handleTabChange(false)}
              className={`relative z-10 flex-1 py-2.5 text-sm font-bold transition-colors duration-300 ${!isAdding ? 'text-zinc-900 dark:text-white' : 'text-zinc-500'}`}
              disabled={isLoading}
            >
              Find Item
            </button>
          </div>

          <div 
            onDragOver={onDragOver}
            onDragLeave={onDragLeave}
            onDrop={onDrop}
            className={`
              group relative flex flex-col items-center justify-center w-full h-64 
              border-2 rounded-2xl transition-all duration-300 
              ${isLoading ? 'opacity-50 grayscale' : '' /* Removed hover:border-opacity-100 */}
              ${isDragging ? `${dragBorder} border-solid` : `border-dashed ${activeBorder} bg-zinc-50/50 dark:bg-zinc-800/50` /* Removed hover:bg-zinc-100 and dark:hover:bg-zinc-800 */}
            `}
          >
            
            {isAdding ? <UploadIcon /> : <SearchIcon />}
            
            <p className="mb-4 text-sm font-medium text-zinc-500 dark:text-zinc-400 transition-colors">
              {isLoading ? "Processing..." : (isDragging ? "Drop it!" : (isAdding ? "Drop found item photo here" : "Upload photo of lost item"))}
            </p>

            <label className={`relative cursor-pointer px-6 py-2.5 rounded-full font-semibold text-white shadow-lg transition-all duration-300 ${activeColor} ${activeHover} ${isLoading ? 'cursor-not-allowed' : ''}`}>
              <span>{isLoading ? "Scanning..." : "Select Photo"}</span>
              <input 
                type="file" 
                accept="image/*" 
                onChange={(e) => e.target.files && processFile(e.target.files[0])} 
                disabled={isLoading} 
                className="hidden" 
              />
            </label>
            
            {isLoading && (
              <div className="absolute inset-0 flex items-center justify-center bg-white/50 dark:bg-zinc-900/50 backdrop-blur-sm rounded-2xl pointer-events-none">
                <div className={`w-10 h-10 border-4 border-t-transparent rounded-full animate-spin ${isAdding ? 'border-sky-500' : 'border-orange-500'}`}></div>
              </div>
            )}
          </div>
        </div>

        <div 
          ref={resultsRef}
          className={`transition-all duration-500 ease-out ${response || returnedImage ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-4'}`}
        >
          {response && (
            <div className={`p-4 mb-4 rounded-2xl border bg-white dark:bg-zinc-900 shadow-sm ${activeBorder}`}>
              <div className="flex items-center gap-2 mb-2">
                <span className="text-xs font-bold tracking-wider uppercase text-zinc-400">Analysis</span>
              </div>
              <p className="text-sm leading-relaxed text-zinc-700 dark:text-zinc-300">{response}</p>
            </div>
          )}

          {returnedImage && (
            <div className="relative">
              <div className="relative bg-white dark:bg-zinc-900 rounded-2xl p-2 shadow-xl ring-1 ring-zinc-200 dark:ring-zinc-800">
                 <div className="flex items-center justify-between px-2 py-2 mb-1 text-center">
                    <span className="text-xs font-bold text-zinc-400 uppercase tracking-widest w-full">COME BY AND PICK IT UP!</span>
                 </div>
                 
                 <div className="aspect-square w-56 mx-auto bg-zinc-100 dark:bg-zinc-800 relative rounded-xl">
                   
                   {showGame && (
                     <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[700px] h-[500px] z-50 bg-zinc-950 flex flex-col items-center justify-start rounded-xl shadow-2xl animate-in fade-in duration-300 border border-zinc-800">
                       <div className="w-full h-full bg-black relative flex items-center justify-center rounded-xl overflow-hidden">
                         <span className="text-zinc-500 font-mono text-[10px] tracking-widest animate-pulse">
                           GAME LOADING...
                         </span>
                         
                         {/* SKIP BUTTON */}
                         <button 
                           onClick={handleSkip}
                           className="absolute top-2 right-2 bg-red-600 hover:bg-red-700 text-white text-[9px] font-bold uppercase px-2 py-1 rounded shadow-lg transition-colors z-50"
                         >
                           Skip {'>>'}
                         </button>
                         
                         {/* <iframe src="/game/index.html" className="w-full h-full" /> */}
                       </div>
                     </div>
                   )}

                   <img 
                      src={`data:image/jpeg;base64,${returnedImage}`} 
                      alt="Found match" 
                      className="w-full h-full object-cover rounded-xl"
                    />
                 </div>
              </div>
            </div>
          )}
        </div>

      </div>
    </main>
  );
}