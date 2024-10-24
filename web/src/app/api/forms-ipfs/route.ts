import { NextApiRequest, NextApiResponse } from 'next';
import { NextRequest, NextResponse } from 'next/server';
import { pinataClient } from '../../../utils/pinataClient';

export const config = {
  api: {
    bodyParser: false,
  },
};

export async function POST(request: NextRequest){
  try{
    
    const data = await request.formData(); 
    const file: File | null = data.get("file") as unknown as File;
    const uploadData = await pinataClient.upload.file(file);
    const url = await pinataClient.gateways.convert(uploadData.IpfsHash);

    console.log(url);
    return NextResponse.json(url, { status: 200 });      
  } catch (e) {
    console.log(e);
    return NextResponse.json(
      { error: "Internal Server Error" },
      { status: 500 }
    );
  }
}
