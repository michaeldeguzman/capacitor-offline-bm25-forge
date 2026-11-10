var capacitorOfflineBM25 = (function (exports, core) {
    'use strict';

    const OfflineBM25 = core.registerPlugin('OfflineBM25', {
        web: () => Promise.resolve().then(function () { return web; }).then(m => new m.OfflineBM25Web()),
    });

    const UNAVAILABLE = 'OfflineBM25 is not available on web';
    class OfflineBM25Web extends core.WebPlugin {
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

    var web = /*#__PURE__*/Object.freeze({
        __proto__: null,
        OfflineBM25Web: OfflineBM25Web
    });

    exports.OfflineBM25 = OfflineBM25;

    Object.defineProperty(exports, '__esModule', { value: true });

    return exports;

})({}, capacitorExports);
//# sourceMappingURL=plugin.js.map
