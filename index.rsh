'reach 0.1';

const commonInteract = {
  reportPayment: Fun([UInt, UInt],Null),
};

// functions related to seller
const aliceInteract = {
  ...commonInteract,
  productReady: Fun([UInt, UInt], Null),
};

// functions related to buyer
const bobInteract = {
  ...commonInteract,
  confirmPurchase: Fun([UInt], UInt),
};

export const main = Reach.App(() => {
  const A = Participant('Alice', aliceInteract);
  const B = Participant('Bob', bobInteract);
  init();
  // The first one to publish deploys the contract
  A.publish();
  commit();
  // The second one to publish always attaches
  B.publish();
  commit();
  // write your program here
  exit();
});
