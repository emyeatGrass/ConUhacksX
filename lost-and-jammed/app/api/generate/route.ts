import { GoogleGenerativeAI } from "@google/generative-ai";
import { NextResponse } from "next/server";
import { findBestMatches } from "@/lib/sqlite-helper";
import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import os from 'os';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
export async function POST(req: Request) {
  const { image, mimeType, isAdding, sessionId } = await req.json();

  const DB_NAME = 'dev.db';
  const READ_ONLY_PATH = path.join(process.cwd(), DB_NAME);
  const WRITABLE_PATH = path.join(os.tmpdir(), `dev-${sessionId}.db`);
  if (!fs.existsSync(WRITABLE_PATH)) {
    fs.copyFileSync(READ_ONLY_PATH, WRITABLE_PATH);
  }

  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: {temperature: 0, topP: 1, topK: 1} });

  const contents = [{ inlineData: { mimeType, data: image } }, { text: "Return a string containing a list of words separated by spaces that visually describe in detail the visible main item(s) in the image I sent you (and its attributes, such as name, synonyms of name, colour, shape, size, brand, and more). Focus only on the main item(s); IGNORE people, the environmental background, the image quality, the view angle and the lighting." }];

  const result = await model.generateContent(contents);
  const aiResponse = await result.response.text();
  console.log("Descriptions: " + aiResponse);

  let deletedRecord: any = null;
  if (isAdding) {
    try {
      const db = new Database(WRITABLE_PATH);
      db.prepare('INSERT INTO FoundItem (descriptions, image) VALUES (?, ?)').run(aiResponse, Buffer.from(image, 'base64'));
      db.close();
    } catch (dbError) {
      console.error("Database Save Failed:", dbError);
    }
  } else {
    const bestMatches = findBestMatches(aiResponse, sessionId);
    const bestMatchesIds = bestMatches?.map(match => ({id: match.id }));
    const bestMatchesImages = bestMatches?.map(match => Buffer.from(match.image).toString('base64')) || [];
    console.log("IDs: " + bestMatchesIds?.map(id => id.id.toString()).join(", "));
    
    let aiResponse2: number | undefined;
    if ((bestMatchesIds?.length || 0) > 0 && bestMatchesImages.length === (bestMatchesIds?.length || 0)) {
      const matchImageParts = bestMatchesImages.map(imgBase64 => ({ inlineData: { mimeType: mimeType, data: imgBase64 } }));
      const contents2 = [{ inlineData: { mimeType, data: image } }, ...matchImageParts, { text: `Return the ID of the image (in the image list of 1 or more items) whose visible main item PRECISELY matches a visible main item of the input image (including TYPE, SHAPE, BRAND, COLOUR, etc. if visible), IF ANY (DON'T be afraid to reject any or all images in the list). Focus on the main item(s) presented to you in the images; ignore other background elements as well as differences in photo quality, environment, people, angle, lighting, etc., since those are likely different pictures. For example, if the input image contains a visible brown wallet as a central item, and one of the images in the list has seemingly the EXACT same visible brown wallet as a main item, the latter image's ID is returned. You need a HIGH level of confidence that a visible main item in the input image is the visible main item in any of the listed images to be able to select it. Note that it might not be clear to you which item is a main one in the input image; keep an open mind (consider all reasonable options). It's also possible for an image in the list to be seemingly identical to the input image, although rare. If you don't recognize a visible main item in the input image in any images of the list, return an empty string (""). Any contradicting/different characteristic of an item is enough to reject it (unless some characteristics of an item could simply be hidden, such as not visible from this angle). Here is the list of IDs corresponding to each image in the list (same order): ${bestMatchesIds?.map(id => id.id.toString()).join(", ")}.` }];
      const result2 = await model.generateContent(contents2);
      aiResponse2 = parseInt(await result2.response.text().toString());
    }
    
    if (aiResponse2) {
      try {
        const db = new Database(WRITABLE_PATH);
        const record = db.prepare('SELECT image FROM FoundItem WHERE id = ?').get(aiResponse2) as { image: Buffer };
        if (record) {
          deletedRecord = { image: record.image };
          db.prepare('DELETE FROM FoundItem WHERE id = ?').run(aiResponse2);
        }
        db.close();
      } catch (dbError) {
        console.error("Database Delete Failed:", dbError);
      }
    }
  }

  const imageResponse = deletedRecord?.image ? Buffer.from(deletedRecord.image).toString('base64') : undefined;
  return NextResponse.json({text: `Item ${isAdding ? "Stored" : (deletedRecord ? "Found" : "not Found")}`, image: imageResponse});
}