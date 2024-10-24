import { PinataSDK } from "pinata";

export const pinataClient = new PinataSDK({
	pinataJwt: `${process.env.PINATA_JWT}`,
	pinataGateway: `${process.env.HOST}`,
});
