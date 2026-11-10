#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(OfflineBM25Plugin, "OfflineBM25",
  CAP_PLUGIN_METHOD(isAvailable, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(upsertMany, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(search, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(remove, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(clear, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(getCollectionInfo, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(tokenize, CAPPluginReturnPromise);
)
