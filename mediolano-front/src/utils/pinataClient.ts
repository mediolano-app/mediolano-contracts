import { PinataSDK } from "pinata-web3";

export const pinataClient = new PinataSDK({
	pinataJwt: `${process.env.PINATA_JWT}`,
	pinataGateway: 
	// 'https://violet-rainy-shrimp-423.mypinata.cloud'
	`${process.env.PINATA_GATEWAY}`	
	,	
});
