import * as admin from "firebase-admin";

admin.initializeApp();

export { createChildAccount } from "./childAuth/createChildAccount";
export { loginChild } from "./childAuth/loginChild";
export { resetChildPassword } from "./childAuth/resetChildPassword";
export { deleteChildAccount } from "./childAuth/deleteChildAccount";
