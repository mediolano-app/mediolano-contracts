"use client"

import { useState, useEffect } from 'react'
import { FilePlus, Lock, FileText, Coins, Shield, Globe, BarChart, Book, Music, Film, FileCode, Palette, File, ScrollText, Clock, ArrowRightLeft, ShieldCheck, Banknote, Globe2 } from 'lucide-react'
import Link from 'next/link'
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { useRouter } from 'next/navigation'
import { useAccount, useNetwork, useContract, useSendTransaction } from '@starknet-react/core'
import { type Abi } from "starknet"
import { abi } from '@/abis/abi'

export type IPType = "" | "patent" | "trademark" | "copyright" | "trade_secret";

export interface IP{
  title: string,
  description: string,
  authors: string[] | string,
  ipType: IPType,
  uploadFile?: File,
}


export default function RegisterIP() {

  const { address } = useAccount();
  const { chain } = useNetwork();
  const { contract } = useContract({ 
    abi: abi as Abi, 
    address: "0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c", 
  }); 
   

  const gateway = "https://violet-rainy-shrimp-423.mypinata.cloud/ipfs/";
  
  const router = useRouter();  
  const [status, setStatus] = useState("Mint NFT");
  const [ipfsHash, setIpfsHash] = useState("");

  const baseIpfsUrl = "https://ipfs.io/ipfs/";

  const [loading, setLoading] = useState(false);
  const [ipData, setIpData] = useState<IP>({
    title: '',
    description: '',
    authors: [],
    ipType: '',
    });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [file, setFile] = useState<File | null>(null);


  const templates = [
      { name: 'Art', icon: Palette, href: '/registerArt', description: 'Tokenize your Artwork' },
      { name: 'Documents', icon: File, href: '/registerDocument', description: 'Safeguard Documents On-Chain' },  
      { name: 'Films', icon: Film, href: '/registerFilm', description: 'Protect your cinematic creations' }, 
      { name: 'Music', icon: Music, href: '/registerMusic', description: 'Copyright Compositions' },
      { name: 'Patents', icon: ScrollText, href: '/registerPatent', description: 'Secure Inventions and Innovations' },
      { name: 'Publications', icon: Book, href: '/registerPublication', description: 'Protect your Written Works' },
      { name: 'RWA', icon: Globe2, href: '/registerRWA', description: 'Tokenize Real World Assets' },
      { name: 'Software', icon: FileCode, href: '/registerSoftware', description: 'Safeguard your Code' },
      { name: 'Custom', icon: Coins, href: '/registerIP', description: 'Edit Your Template' },
    ];

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const {name, value} = e.target;
    setIpData((prev) => ({...prev, [name]: value}));
  };

  const handleAuthorChange = (index: number, value: string) => {
    const newAuthors = [...ipData.authors]
    newAuthors[index] = value
    setIpData(prev => ({ ...prev, authors: newAuthors }))
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setFile(e.target.files[0]);
    }
  };

  const { send, error: mintError} = useSendTransaction({ 
    calls: 
      contract && address 
        ? [contract.populate("mint_item", [address, ipfsHash])] 
        : undefined, 
  }); 

  const handleMintItem = async () => {
    try {
      send();
      console.log("passei pela send")
    }
    catch(error){
      console.error("Mint error:", mintError); 
    }    
  };

  const handleSubmit = async (event: React.FormEvent) => {
    console.log(ipData);
    event.preventDefault();
    
    setIsSubmitting (true);
    setError(null);

    const submitData = new FormData();
    
    submitData.append('title', ipData.title);
    submitData.append('description', ipData.description);
    if (Array.isArray(ipData.authors)) {
        ipData.authors.forEach((author, index) => {
          submitData.append(`authors[${index}]`, author)
        })
      } else {
        submitData.append('authors', ipData.authors);
      }
      
    submitData.append('ipType', ipData.ipType);
    
    if (file) {
      submitData.set('uploadFile', file);
    }

    for (let pair of submitData.entries()) {
      console.log(`${pair[0]}: ${pair[1]}`);
    } //just for checking

    try {
      const response = await fetch('/api/forms-ipfs', {
        method: 'POST',
        body: submitData,
      });
      console.log("POST done, waiting for response");
      if (!response.ok) {
        throw new Error('Failed to submit IP')
      }
      console.log('IP submitted successfully');

      
      const data = await response.json();
      const ipfs = data.uploadData.IpfsHash as string;
      console.log(ipfs);
      setIpfsHash(ipfs);
      
    } catch (err) {
        setError('Failed submitting or minting IP. Please try again.');
    } finally {
        setIsSubmitting(false);
    }
  };

  useEffect(()=> {
    handleMintItem();
    console.log("entrei no mint");
  }, [ipfsHash]);







  return (

  <div className="container mx-auto px-4 py-8 mt-10 mb-20">
    <h1 className="text-4xl font-bold text-center mb-8">Intellectual Property Registration</h1>


    <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
    
    <div className="text-card-foreground">
    <Card>
    <CardHeader>
      <CardTitle>Create new IP</CardTitle>
      <CardDescription>Register your intellectual property on Starknet blockchain.</CardDescription>
    </CardHeader>
    <CardContent>
 
  <form onSubmit={handleSubmit} className="space-y-6">
    <div>
      <label htmlFor="title" className="block mb-1 font-medium">Title</label>
      <input 
        type="text" 
        id="title" 
        name="title" 
        value={ipData.title}
        onChange={handleChange}
        className="w-full rounded block bordered border" 
        required 
      />
      </div>
    <div>
      <label htmlFor="description" className="block mb-1 font-medium">Description</label>
      <textarea 
        id="description" 
        name="description" 
        value={ipData.description}
        onChange={handleChange}
        className="w-full rounded input input-bordered border" 
        rows={4}
        required
      ></textarea>
    </div>
    <div>
      <label htmlFor="authors" className="block mb-1 font-medium">Author</label>
      <input 
        type="text" 
        id="authors" 
        name="authors"
        value={ipData.authors}
        onChange={handleChange} 
        className="w-full rounded input input-bordered border" 
        required 
      />
      </div>
    <div>
      <label htmlFor="type" className="block mb-1 font-medium">IP Type</label>
      <select 
        id="type" 
        name="type" 
        value={ipData.ipType}
        onChange={ (e:any) => {
          setIpData((prev) => ({ ...prev, "ipType": e.target.value }));
          console.log(e);
        }}
        className="w-full input-bordered rounded border"
      >
        <option value="patent">Patent</option>
        <option value="trademark">Trademark</option>
        <option value="copyright">Copyright</option>
        <option value="trade_secret">Trade Secret</option>
      </select>
    </div>
    
    <button type="submit" className="px-6 py-4 flex items-center justify-center w-full rounded input input-bordered">
      <FilePlus className="h-5 w-5 mr-2" /> Register IP
    </button>
  </form>
  </CardContent>
    <CardFooter className="flex justify-between">
    </CardFooter>
  </Card>
  </div>



<div className="bg-card text-card-foreground rounded-lg shadow-lg">

  <Card>
  <div className="text-card-foreground rounded-lg p-6">


  
    <div className="py-2">
      <h2 className="text-2xl font-semibold mb-2">Blockchain IP Registration Features</h2>
      <p className="text-muted-foreground mb-4">Secure, transparent, and efficient</p>
      </div>
    
      <ul className="space-y-6">
        <li className="flex items-start">
          <Lock className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Immutable Protection</h3>
            <p className="text-sm text-muted-foreground">Your IP is securely stored on the blockchain, providing tamper-proof evidence of ownership and creation date.</p>
          </div>
        </li>
        <li className="flex items-start">
          <FileText className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Smart Licensing</h3>
            <p className="text-sm text-muted-foreground">Utilize smart contracts for automated licensing agreements, ensuring proper attribution and compensation.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Coins className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Tokenized Monetization</h3>
            <p className="text-sm text-muted-foreground">Transform your IP into digital assets, enabling fractional ownership and new revenue streams.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Shield className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Enhanced Security</h3>
            <p className="text-sm text-muted-foreground">Benefit from blockchain's cryptographic security, protecting your IP from unauthorized access and tampering.</p>
          </div>
        </li>
        <li className="flex items-start">
          <Globe className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Global Accessibility</h3>
            <p className="text-sm text-muted-foreground">Access and manage your IP rights from anywhere in the world, facilitating international collaborations and licensing.</p>
          </div>
        </li>
        <li className="flex items-start">
          <BarChart className="w-6 h-6 mr-3 flex-shrink-0" />
          <div>
            <h3 className="font-semibold mb-1">Analytics and Insights</h3>
            <p className="text-sm text-muted-foreground">Gain valuable insights into your IP portfolio's performance and market trends through blockchain-powered analytics.</p>
          </div>
        </li>
      </ul>
    </div>
    </Card>

    </div>
  </div>

</div>

  )
}