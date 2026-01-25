import Database from 'better-sqlite3';

export function findBestMatches(aiDescription: string) {
  const dbPath = process.env.DATABASE_URL?.replace("file:", "") || './dev.db';
  const db = new Database(dbPath);

  db.function('COUNT_OVERLAP', (desc1: string, desc2: string) => {
    if (!desc1 || !desc2) return 0;
    
    const words1 = new Set(desc1.toLowerCase().split(/\s+/));
    const words2 = desc2.toLowerCase().split(/\s+/);
    
    let count = 0;
    for (const w of words2) {
      if (words1.has(w)) count++;
    }

    return count;
  });

  const stmt = db.prepare(`
    SELECT id, image
    FROM FoundItem
    WHERE COUNT_OVERLAP(descriptions, ?) > 2
    ORDER BY COUNT_OVERLAP(descriptions, ?) DESC
    LIMIT 5
  `);

  return stmt.all(aiDescription, aiDescription) as [{ id: number, image: Buffer }] | undefined;
}