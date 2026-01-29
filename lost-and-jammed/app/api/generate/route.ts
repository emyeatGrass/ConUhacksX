import { GoogleGenerativeAI } from "@google/generative-ai";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { findBestMatches } from "@/lib/sqlite-helper";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
export async function POST(req: Request) {
  const { image, mimeType, isAdding } = await req.json();
  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash", generationConfig: {temperature: 0, topP: 1, topK: 1} });

  const contents = [{ inlineData: { mimeType, data: image } }, { text: "Return a string containing a list of words separated by spaces that visually describe the main object(s) in the image I sent you (and its attributes, such as name, synonyms of name, colour, shape, size, brand, and more). Focus only on the main item(s), not the environmental background, people, image quality, angle nor lighting." }];

  const result = await model.generateContent(contents);
  const aiResponse = await result.response.text();

  let deletedRecord: any = null;
  if (isAdding) {
    try {
      await prisma.foundItem.create({data: {descriptions: aiResponse, image: Buffer.from(image, 'base64')}});
    } catch (dbError) {
      console.error("Database Save Failed:", dbError);
    }
  } else {
    const bestMatches = findBestMatches(aiResponse);
    const bestMatchesIds = bestMatches?.map(match => ({id: match.id }));
    const bestMatchesImages = bestMatches?.map(match => Buffer.from(match.image).toString('base64')) || [];
    
    let aiResponse2: number | null | undefined;
    if ((bestMatchesIds?.length || 0) > 1 && bestMatchesImages.length === (bestMatchesIds?.length || 0)) {
      const matchImageParts = bestMatchesImages.map(imgBase64 => ({ inlineData: { mimeType: mimeType, data: imgBase64 } }));
      const contents2 = [{ inlineData: { mimeType, data: image } }, ...matchImageParts, { text: `Return the ID of the image (in the image list) whose item(s) best matches that of the input image. For example, if the input image contains a wallet as a central item, and one of the images in the list has seemingly the same wallet as a main item, the latter image's ID is returned. It's also possible for an image in the list to be seemingly identical to the input image, although rare. The IDs of all images (in the image list)) are provided to you, in the same order. Focus on the main item(s) presented to you in the images; ignore other background elements. If you don't recognize the item(s) in the input image in any image of the list (it needs to be the same item(s), although things like the photo quality, environment, people, angle and lighting could differ obviously since those are different pictures, so be careful), return an empty string (""). Be careful about the details (brand, colour, shape, size, and more...); any contradicting/different characteristic of an item is enough to reject it. Although some characteristics of an object could simply be hidden (not visible from this angle), so in that case it might not be a good reason to disqualify it. Here is the list of IDs: ${bestMatchesIds?.map(id => id.id.toString()).join(", ")}.` }];
      const result2 = await model.generateContent(contents2);
      aiResponse2 = parseInt(await result2.response.text().toString());
    } else {
      aiResponse2 = bestMatchesIds?.[0]?.id;
    }
    
    if (aiResponse2) {
      try {
        deletedRecord = await (aiResponse2 < 26 ? prisma.foundItem.findFirst({where: { id: aiResponse2 }, select: { image: true }}) : prisma.foundItem.delete({where: { id: aiResponse2 }, select: { image: true }}));
      } catch (dbError) {
        console.error("Database Delete Failed:", dbError);
      }
    }
  }

  const imageResponse = deletedRecord?.image ? Buffer.from(deletedRecord.image).toString('base64') : undefined;
  return NextResponse.json({text: `Item ${isAdding ? "Stored" : (deletedRecord ? "Found" : "not Found")}`, image: imageResponse});
}