"use client";

import React, { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
	Card,
	CardContent,
	CardFooter,
	CardHeader,
	CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
	DropdownMenu,
	DropdownMenuContent,
	DropdownMenuItem,
	DropdownMenuLabel,
	DropdownMenuSeparator,
	DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
	Eye,
	DollarSign,
	Send,
	MoreHorizontal,
	Search,
	Grid,
	List,
	FileText,
	Zap,
} from "lucide-react";
import Image from "next/image";
import { abi } from "../../src/abis/abi";
import { type Abi } from "starknet";
import { useReadContract } from "@starknet-react/core";
import { pinataClient } from "@/utils/pinataClient";
import { IP } from "../app/register/page";

interface NFTCardProps {
	key: number;
	tokenId: BigInt;
	status: string;
}

const NFTCard: React.FC<NFTCardProps> = ({ tokenId, status }) => {
	const contract =
		"0x07e39e39ddee958c8a9221d82f639aa9112d6789259ccf09f2a7eb8e021c051c";
	const [metadata, setMetadata] = useState<IP | null>(null);
	const [isLoading, setIsLoading] = useState(true);
	const [error, setError] = useState<string | null>(null);

	// Get tokenURI from contract
	const {
		data: tokenURI,
		isLoading: isContractLoading,
		error: contractError,
	} = useReadContract({
		abi: abi as Abi,
		functionName: "tokenURI",
		address: contract as `0x${string}`,
		args: [Number(tokenId)],
		watch: false,
	});

	// Fetch metadata when tokenURI is available
	useEffect(() => {
		const fetchMetadata = async () => {
			if (!tokenURI || typeof tokenURI !== "string") {
				return;
			}

			try {
				setIsLoading(true);
        console.log(tokenURI)
				const response = await pinataClient.gateways.get(tokenURI);

				let parsedData: any;
				try {
					parsedData =
						typeof response.data === "string"
							? JSON.parse(response.data)
							: response.data;
				} catch (parseError) {
					throw new Error("Failed to parse metadata");
				}

				// Validate metadata structure
				if (!isValidMetadata(parsedData)) {
					throw new Error("Invalid metadata format");
				}

				setMetadata(parsedData);
				setError(null);
			} catch (err) {
				setError(
					err instanceof Error ? err.message : "Failed to fetch metadata",
				);
				setMetadata(null);
			} finally {
				setIsLoading(false);
			}
		};

		fetchMetadata();
	}, [tokenURI]);

	const isValidMetadata = (data: any): data is IP => {
		return (
			data &&
			typeof data === "object" &&
			"title" in data &&
			"description" in data &&
			"ipType" in data
		);
	};

	if (isLoading || isContractLoading) {
		return <div>Loading...</div>; // Consider using a proper loading component
	}

	if (error || contractError) {
		return <div>Error: {error || "Failed to fetch token data"}</div>; // Consider using a proper error component
	}

	if (!metadata) {
		return <div>No metadata available</div>;
	}

	return (
		<Card className="overflow-hidden">
			<CardHeader className="p-0">
				<Image
					src={metadata.image || "/background.jpg"} // Add fallback image
					alt={metadata.title}
					width={400}
					height={400}
					className="w-full h-48 object-cover"
				/>
			</CardHeader>
			<CardContent className="p-4">
				<CardTitle className="line-clamp-1 mb-2">{metadata.title}</CardTitle>
				<div className="flex justify-between items-center mb-2">
					<Badge variant="secondary">{metadata.ipType}</Badge>
					<span className="font-semibold">{metadata.price || "N/A"} ETH</span>
				</div>
				<Badge
					variant={
						status === "Listed"
							? "default"
							: status === "Licensed"
								? "secondary"
								: "outline"
					}
				>
					{status}
				</Badge>
			</CardContent>
			<CardFooter className="p-4 pt-0 flex flex-wrap gap-2">
				<Button variant="outline" size="sm">
					<Eye className="h-4 w-4 mr-2" />
					View Details
				</Button>
				<Button variant="outline" size="sm">
					<FileText className="h-4 w-4 mr-2" />
					License IP
				</Button>
				<Button variant="outline" size="sm">
					<DollarSign className="h-4 w-4 mr-2" />
					Monetize
				</Button>
				<DropdownMenu>
					<DropdownMenuTrigger asChild>
						<Button variant="outline" size="sm">
							<MoreHorizontal className="h-4 w-4" />
						</Button>
					</DropdownMenuTrigger>
					<DropdownMenuContent>
						<DropdownMenuLabel>More Actions</DropdownMenuLabel>
						<DropdownMenuSeparator />
						<DropdownMenuItem>
							<Send className="h-4 w-4 mr-2" />
							Transfer
						</DropdownMenuItem>
						<DropdownMenuItem>
							<Zap className="h-4 w-4 mr-2" />
							Promote
						</DropdownMenuItem>
					</DropdownMenuContent>
				</DropdownMenu>
			</CardFooter>
		</Card>
	);
};

export default NFTCard;