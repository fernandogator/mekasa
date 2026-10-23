/**
 * Satisfies: UI-007 AC22 (REQ-INV-020 AC1–AC4, AC6)
 */

import { isTypingTarget, pagerPosition, positionLabel, swipeDirection } from './pager';

describe('item pager (UI-007 AC22)', () => {
  const order = ['a', 'b', 'c'];

  it('finds the neighbours in the grid order', () => {
    const middle = pagerPosition(order, 'b');
    expect(middle).toEqual({ index: 1, total: 3, previousId: 'a', nextId: 'c' });
    expect(positionLabel(middle!)).toBe('2 of 3');
  });

  it('does not wrap at the ends', () => {
    expect(pagerPosition(order, 'a')).toMatchObject({ previousId: null, nextId: 'b' });
    expect(pagerPosition(order, 'c')).toMatchObject({ previousId: 'b', nextId: null });
  });

  it('shows no pager for an item outside the grid', () => {
    expect(pagerPosition(order, 'zzz')).toBeNull();
    expect(pagerPosition(order, undefined)).toBeNull();
  });

  it('turns a clear horizontal swipe of 60 px or more into a move', () => {
    expect(swipeDirection(-80, 10)).toBe('next');
    expect(swipeDirection(90, -20)).toBe('previous');
    expect(swipeDirection(-59, 0)).toBeNull();
    expect(swipeDirection(-80, -70)).toBeNull();
  });

  it('ignores arrow keys while typing', () => {
    expect(isTypingTarget(document.createElement('input'))).toBe(true);
    expect(isTypingTarget(document.createElement('textarea'))).toBe(true);
    expect(isTypingTarget(document.createElement('button'))).toBe(false);
    expect(isTypingTarget(null)).toBe(false);
  });
});
