import { registerPlugin } from '@capacitor/core';
const OfflineBM25 = registerPlugin('OfflineBM25', {
    web: () => import('./web').then(m => new m.OfflineBM25Web()),
});
export * from './definitions';
export { OfflineBM25 };
//# sourceMappingURL=index.js.map