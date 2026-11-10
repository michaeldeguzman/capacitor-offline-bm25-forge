import { WebPlugin } from '@capacitor/core';
import type { OfflineBM25Plugin } from './definitions';
export declare class OfflineBM25Web extends WebPlugin implements OfflineBM25Plugin {
    isAvailable(): Promise<{
        available: boolean;
        tokenizerVersion: number;
    }>;
    upsertMany(): Promise<{
        count: number;
        skipped: string[];
    }>;
    search(): Promise<{
        results: {
            id: string;
            score: number;
            metadata: string;
            matchedTerms: number;
        }[];
    }>;
    remove(): Promise<{
        count: number;
    }>;
    clear(): Promise<void>;
    getCollectionInfo(): Promise<{
        exists: boolean;
        count: number;
        uniqueTerms: number;
        avgLength: number;
        tokenizerVersion: number;
        currentTokenizerVersion: number;
        needsReindex: boolean;
    }>;
    tokenize(): Promise<{
        tokens: string[];
    }>;
}
