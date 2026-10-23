/**
 * Previous / next item in the item detail panel, in the grid's order.
 *
 * Satisfies: UI-007 AC22 (REQ-INV-020 AC1–AC4, AC6)
 * Spec version: 1.0
 */

export interface PagerPosition {
  /** Zero-based index in the order. */
  index: number;
  total: number;
  previousId: string | null;
  nextId: string | null;
}

/** Where `id` sits in `order`, or null when it isn't there (no pager). Never wraps. */
export function pagerPosition(order: readonly string[], id: string | undefined): PagerPosition | null {
  if (!id) return null;
  const index = order.indexOf(id);
  if (index < 0) return null;
  return {
    index,
    total: order.length,
    previousId: index > 0 ? order[index - 1] : null,
    nextId: index < order.length - 1 ? order[index + 1] : null,
  };
}

/** "3 of 24". */
export function positionLabel(position: PagerPosition): string {
  return `${position.index + 1} of ${position.total}`;
}

export const SWIPE_MIN_PX = 60;

/**
 * A finished touch drag as a move: left is next, right is previous. It must
 * travel at least 60 px and clearly more sideways than up or down.
 */
export function swipeDirection(dx: number, dy: number): 'next' | 'previous' | null {
  if (Math.abs(dx) < SWIPE_MIN_PX || Math.abs(dx) < Math.abs(dy) * 1.5) return null;
  return dx < 0 ? 'next' : 'previous';
}

/** Arrow keys move only when the user isn't typing. */
export function isTypingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || target.isContentEditable === true;
}
