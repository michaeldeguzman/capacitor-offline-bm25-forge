import { registerPlugin } from '@capacitor/core';

import type { OfflineBM25Plugin } from './definitions';

const OfflineBM25 = registerPlugin<OfflineBM25Plugin>('OfflineBM25', {
  web: () => import('./web').then(m => new m.OfflineBM25Web()),
});

export * from './definitions';
export { OfflineBM25 };
