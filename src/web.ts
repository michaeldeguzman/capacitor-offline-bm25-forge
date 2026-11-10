import { WebPlugin } from '@capacitor/core';

import type { OfflineBM25Plugin } from './definitions';

const UNAVAILABLE = 'OfflineBM25 is not available on web';

export class OfflineBM25Web extends WebPlugin implements OfflineBM25Plugin {
  async isAvailable(): Promise<{ available: boolean; tokenizerVersion: number }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async upsertMany(): Promise<{ count: number; skipped: string[] }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async search(): Promise<{
    results: { id: string; score: number; metadata: string; matchedTerms: number }[];
  }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async remove(): Promise<{ count: number }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async clear(): Promise<void> {
    throw this.unavailable(UNAVAILABLE);
  }

  async getCollectionInfo(): Promise<{
    exists: boolean;
    count: number;
    uniqueTerms: number;
    avgLength: number;
    tokenizerVersion: number;
    currentTokenizerVersion: number;
    needsReindex: boolean;
  }> {
    throw this.unavailable(UNAVAILABLE);
  }

  async tokenize(): Promise<{ tokens: string[] }> {
    throw this.unavailable(UNAVAILABLE);
  }
}
