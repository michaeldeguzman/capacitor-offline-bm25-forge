import { WebPlugin } from '@capacitor/core';
const UNAVAILABLE = 'OfflineBM25 is not available on web';
export class OfflineBM25Web extends WebPlugin {
    async isAvailable() {
        throw this.unavailable(UNAVAILABLE);
    }
    async upsertMany() {
        throw this.unavailable(UNAVAILABLE);
    }
    async search() {
        throw this.unavailable(UNAVAILABLE);
    }
    async remove() {
        throw this.unavailable(UNAVAILABLE);
    }
    async clear() {
        throw this.unavailable(UNAVAILABLE);
    }
    async getCollectionInfo() {
        throw this.unavailable(UNAVAILABLE);
    }
    async tokenize() {
        throw this.unavailable(UNAVAILABLE);
    }
}
//# sourceMappingURL=web.js.map