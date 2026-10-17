/** Receipt image checks and in-browser downscaling (UI-007 AC10). */

export const ACCEPTED_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const MAX_BYTES = 10 * 1024 * 1024;
export const LONG_EDGE = 2048;

export function validateReceiptFile(file: { type: string; size: number }): string | null {
  if (!(ACCEPTED_TYPES as readonly string[]).includes(file.type)) return 'Use a JPEG, PNG or WebP photo.';
  if (file.size > MAX_BYTES) return 'That photo is over 10 MB. Try a smaller one.';
  return null;
}

export function scaledSize(width: number, height: number, longEdge = LONG_EDGE): { width: number; height: number } {
  const longest = Math.max(width, height);
  if (longest <= longEdge) return { width, height };
  const scale = longEdge / longest;
  return { width: Math.round(width * scale), height: Math.round(height * scale) };
}

/** Returns the photo as base64 JPEG (no data: prefix), long edge ≤ 2048 px. */
export async function toReceiptJpegBase64(file: Blob): Promise<string> {
  const bitmap = await createImageBitmap(file);
  const { width, height } = scaledSize(bitmap.width, bitmap.height);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Canvas unavailable');
  context.drawImage(bitmap, 0, 0, width, height);
  bitmap.close();
  const blob = await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob((result) => (result ? resolve(result) : reject(new Error('Encode failed'))), 'image/jpeg', 0.85),
  );
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}
