import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import os from 'os';

export function findBestMatches(aiDescription: string, sessionId: string) {
  const DB_NAME = 'dev.db';
  const READ_ONLY_PATH = path.join(process.cwd(), DB_NAME);
  const WRITABLE_PATH = path.join(os.tmpdir(), `dev-${sessionId}.db`);
  if (!fs.existsSync(WRITABLE_PATH)) {
    fs.copyFileSync(READ_ONLY_PATH, WRITABLE_PATH);
  }
  const db = new Database(WRITABLE_PATH);

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
    LIMIT 4
  `);

  const results = stmt.all(aiDescription, aiDescription)
  db.close();
  return results as [{ id: number, image: Buffer }] | undefined;
}