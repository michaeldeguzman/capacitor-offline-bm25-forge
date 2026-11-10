export interface OfflineBM25Plugin {
    isAvailable(): Promise<{
        available: boolean;
        tokenizerVersion: number;
    }>;
    upsertMany(options: {
        collection: string;
        items: {
            id: string;
            text: string;
            metadata?: string;
        }[];
    }): Promise<{
        count: number;
        skipped: string[];
    }>;
    search(options: {
        collection: string;
        query: string;
        topK?: number;
        minScore?: number;
        k1?: number;
        b?: number;
    }): Promise<{
        results: {
            id: string;
            score: number;
            metadata: string;
            matchedTerms: number;
        }[];
    }>;
    remove(options: {
        collection: string;
        ids: string[];
    }): Promise<{
        count: number;
    }>;
    clear(options: {
        collection: string;
    }): Promise<void>;
    getCollectionInfo(options: {
        collection: string;
    }): Promise<{
        exists: boolean;
        count: number;
        uniqueTerms: number;
        avgLength: number;
        tokenizerVersion: number;
        currentTokenizerVersion: number;
        needsReindex: boolean;
    }>;
    tokenize(options: {
        text: string;
    }): Promise<{
        tokens: string[];
    }>;
}
