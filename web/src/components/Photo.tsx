import { Apple, Beef, Coffee, Milk, Package, Snowflake, SprayCan, Wheat } from 'lucide-react';
import { useEffect, useState } from 'react';

import { useHousehold } from '../household/HouseholdProvider';
import { classifyPhoto } from '../photos/photoLinks';

const categoryIcons: Record<string, typeof Package> = {
  Produce: Apple,
  Dairy: Milk,
  Pantry: Wheat,
  Meat: Beef,
  Frozen: Snowflake,
  Beverages: Coffee,
  Household: SprayCan,
};

export function CategoryTile({ category, className = '' }: { category: string; className?: string }) {
  const Icon = categoryIcons[category] ?? Package;
  return (
    <div className={`flex items-center justify-center bg-success-tint text-accent-text ${className}`}>
      <Icon aria-hidden className="h-1/3 w-1/3 max-h-16 max-w-16" strokeWidth={1.6} />
    </div>
  );
}

/**
 * Product or item picture: external URLs load directly, API photo paths go
 * through signed links (UI-007 AC12), anything else shows the category tile.
 */
export function Photo({ url, alt, category, className = '' }: { url: string | null | undefined; alt: string; category: string; className?: string }) {
  const { photos } = useHousehold();
  const source = classifyPhoto(url);
  const [resolved, setResolved] = useState<string | null>(source.kind === 'direct' ? source.url : null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
    if (source.kind === 'direct') {
      setResolved(source.url);
      return;
    }
    setResolved(null);
    if (source.kind !== 'api') return;
    let live = true;
    photos
      .resolve(source.path)
      .then((link) => live && setResolved(link))
      .catch(() => live && setFailed(true));
    return () => {
      live = false;
    };
  }, [url, photos]);

  if (!resolved || failed) return <CategoryTile category={category} className={className} />;
  return <img src={resolved} alt={alt} loading="lazy" onError={() => setFailed(true)} className={`object-cover ${className}`} />;
}
