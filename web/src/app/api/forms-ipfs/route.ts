import { NextApiRequest, NextApiResponse } from 'next';
import { NextRequest, NextResponse } from 'next/server';
import { pinataClient } from '../../../utils/pinataClient';

// export const config = {
//   api: {
//     bodyParser: false,
//   },
// };

export async function POST(request: NextRequest){
    try{
      // const mockedData = {
      //     title: 'mocktitle',
      //     description: 'mockdescription',
      //     authors: 'mockauthors',
      //     ipType: 'mockiptype',
      //     uploadFile:''
      // };
  
      const data = await request.formData();

      const title = data.get('title') as unknown as string;
      const description = data.get('description') as unknown as string;
      const authors = data.getAll('authors');
      const ipType = data.get('ipType') as string;
      const uploadFile = data.get('uploadFile') as File | null;
  
      //const file: File | null = data.get("file") as unknown as File;

      // const uploadMockedData = await pinataClient.upload.json(mockedData);
      // const mockedUrl = await pinataClient.gateways.convert(uploadMockedData.IpfsHash);
      // console.log(mockedUrl);

      const userObject = {
        title,
        description,
        authors,
        ipType,
        uploadFile: uploadFile ? uploadFile.name : null,
      };

      const uploadData = await pinataClient.upload.json(userObject);

      //aqui eu chamo a função de MINTAR
      return NextResponse.json({ uploadData }, { status: 200 });
    } catch (e) {
      console.log(e);
      return NextResponse.json(
        { error: "Internal Server Error" },
        { status: 500 }
      );
    } 
  }